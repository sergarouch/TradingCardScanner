"""
TCG Card Scanner API Server
Flask REST API for card recognition and price lookup
"""

import os
import io
import base64
import uuid
import asyncio
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Import our modules
from models.card_recognition_model import get_pipeline
from services.tcgplayer_service import get_tcgplayer_service_sync
from services.card_database import get_card_database, compute_perceptual_hash, CardEntry

# Initialize Flask app
app = Flask(__name__)
CORS(app, origins=['*'])

# Configuration
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max upload
app.config['UPLOAD_FOLDER'] = 'data/uploads'

# Ensure upload directory exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)


def decode_base64_image(base64_string: str) -> Image.Image:
    """Decode base64 encoded image to PIL Image."""
    # Remove data URL prefix if present
    if ',' in base64_string:
        base64_string = base64_string.split(',')[1]
    
    image_data = base64.b64decode(base64_string)
    return Image.open(io.BytesIO(image_data))


def image_to_base64(image: Image.Image, format: str = 'JPEG') -> str:
    """Convert PIL Image to base64 string."""
    buffer = io.BytesIO()
    image.save(buffer, format=format)
    return base64.b64encode(buffer.getvalue()).decode('utf-8')


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })


@app.route('/api/recognize', methods=['POST'])
def recognize_card():
    """
    Recognize a trading card from an image.
    
    Accepts:
        - JSON with base64 encoded image
        - Multipart form with image file
        
    Returns:
        Card classification and features
    """
    try:
        image = None
        
        # Handle JSON request with base64 image
        if request.is_json:
            data = request.get_json()
            if 'image' not in data:
                return jsonify({'error': 'No image provided'}), 400
            image = decode_base64_image(data['image'])
            
        # Handle multipart form upload
        elif 'image' in request.files:
            file = request.files['image']
            if file.filename == '':
                return jsonify({'error': 'No file selected'}), 400
            image = Image.open(file.stream)
            
        else:
            return jsonify({'error': 'No image provided'}), 400
            
        # Get pipeline and process image
        pipeline = get_pipeline()
        result = pipeline.classify_card(image)
        
        # Compute perceptual hash
        p_hash = compute_perceptual_hash(image)
        
        # Search for similar cards in database
        db = get_card_database()
        similar_cards = []
        
        if result['features'] is not None:
            matches = db.find_similar(result['features'], top_k=3, threshold=0.6)
            similar_cards = [
                {
                    'card_id': card.card_id,
                    'name': card.name,
                    'set_name': card.set_name,
                    'category': card.category,
                    'tcgplayer_id': card.tcgplayer_product_id,
                    'similarity': score
                }
                for card, score in matches
            ]
            
        # Also search by perceptual hash
        if p_hash:
            hash_matches = db.find_by_hash(p_hash, threshold=8)
            for card in hash_matches[:3]:
                if not any(c['card_id'] == card.card_id for c in similar_cards):
                    similar_cards.append({
                        'card_id': card.card_id,
                        'name': card.name,
                        'set_name': card.set_name,
                        'category': card.category,
                        'tcgplayer_id': card.tcgplayer_product_id,
                        'similarity': 0.9  # Hash match
                    })
        
        return jsonify({
            'success': True,
            'classification': {
                'category': result['primary_category'],
                'confidence': result['confidence'],
                'predictions': result['predictions']
            },
            'perceptual_hash': p_hash,
            'similar_cards': similar_cards,
            'has_feature_vector': result['features'] is not None
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/identify', methods=['POST'])
def identify_and_price():
    """
    Full pipeline: recognize card and fetch price from TCGPlayer.
    
    Accepts:
        - JSON with base64 encoded image
        - Optional: card_name hint for better search
        
    Returns:
        Card identification with pricing information
    """
    try:
        data = request.get_json()
        
        if 'image' not in data:
            return jsonify({'error': 'No image provided'}), 400
            
        image = decode_base64_image(data['image'])
        card_name_hint = data.get('card_name_hint', None)
        
        # Classify the card
        pipeline = get_pipeline()
        result = pipeline.classify_card(image)
        category = result['primary_category']
        
        # Get TCGPlayer service
        tcg_service = get_tcgplayer_service_sync()
        
        # Search database for matches
        db = get_card_database()
        matches = db.find_similar(result['features'], top_k=1, threshold=0.7)
        
        pricing_info = None
        card_info = None
        
        # If we have a database match, get its price
        if matches:
            card, score = matches[0]
            card_info = {
                'name': card.name,
                'set_name': card.set_name,
                'category': card.category,
                'match_confidence': score
            }
            
            if card.tcgplayer_product_id:
                price = tcg_service.get_card_prices(card.tcgplayer_product_id)
                if price:
                    pricing_info = {
                        'market_price': price.market_price,
                        'low_price': price.low_price,
                        'mid_price': price.mid_price,
                        'high_price': price.high_price,
                        'condition': price.condition,
                        'tcgplayer_url': price.tcgplayer_url
                    }
                    
        # If no match but we have a name hint, search TCGPlayer
        elif card_name_hint:
            price = tcg_service.get_price_by_name(card_name_hint, category)
            if price:
                card_info = {
                    'name': price.card_name,
                    'set_name': price.set_name,
                    'category': price.tcg_category,
                    'match_confidence': 0.5  # Lower confidence for hint-based search
                }
                pricing_info = {
                    'market_price': price.market_price,
                    'low_price': price.low_price,
                    'mid_price': price.mid_price,
                    'high_price': price.high_price,
                    'condition': price.condition,
                    'tcgplayer_url': price.tcgplayer_url
                }
                
        return jsonify({
            'success': True,
            'classification': {
                'category': category,
                'confidence': result['confidence']
            },
            'card_info': card_info,
            'pricing': pricing_info
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/search', methods=['GET'])
def search_cards():
    """
    Search for cards on TCGPlayer.
    
    Query params:
        - q: Search query (required)
        - category: TCG category filter (optional)
        - limit: Max results (default 10)
        
    Returns:
        List of matching cards with prices
    """
    query = request.args.get('q', '')
    category = request.args.get('category', None)
    limit = min(int(request.args.get('limit', 10)), 50)
    
    if not query:
        return jsonify({'error': 'Query parameter "q" is required'}), 400
        
    try:
        tcg_service = get_tcgplayer_service_sync()
        results = tcg_service.search_cards(query, category, limit)
        
        return jsonify({
            'success': True,
            'query': query,
            'category': category,
            'results': [
                {
                    'product_id': r.product_id,
                    'name': r.name,
                    'set_name': r.set_name,
                    'category': r.category,
                    'image_url': r.image_url,
                    'market_price': r.price_summary.get('market'),
                    'tcgplayer_url': r.tcgplayer_url
                }
                for r in results
            ]
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/price/<product_id>', methods=['GET'])
def get_card_price(product_id: str):
    """
    Get detailed pricing for a specific TCGPlayer product.
    
    Returns:
        Detailed pricing information
    """
    try:
        tcg_service = get_tcgplayer_service_sync()
        price = tcg_service.get_card_prices(product_id)
        
        if not price:
            return jsonify({
                'success': False,
                'error': 'Card not found'
            }), 404
            
        return jsonify({
            'success': True,
            'product_id': product_id,
            'card_name': price.card_name,
            'set_name': price.set_name,
            'category': price.tcg_category,
            'pricing': {
                'market_price': price.market_price,
                'low_price': price.low_price,
                'mid_price': price.mid_price,
                'high_price': price.high_price,
                'condition': price.condition
            },
            'image_url': price.image_url,
            'tcgplayer_url': price.tcgplayer_url,
            'last_updated': price.last_updated.isoformat()
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/database/add', methods=['POST'])
def add_card_to_database():
    """
    Add a card to the local database for future recognition.
    
    Accepts:
        - JSON with card info and optional base64 image
        
    Returns:
        Success status
    """
    try:
        data = request.get_json()
        
        required_fields = ['name', 'category']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
                
        # Generate card ID
        card_id = data.get('card_id', str(uuid.uuid4()))
        
        # Extract features if image provided
        feature_vector = None
        p_hash = None
        
        if 'image' in data:
            image = decode_base64_image(data['image'])
            pipeline = get_pipeline()
            feature_vector = pipeline.extract_features(image)
            p_hash = compute_perceptual_hash(image)
            
        # Create entry
        now = datetime.now().isoformat()
        entry = CardEntry(
            card_id=card_id,
            name=data['name'],
            set_name=data.get('set_name', ''),
            category=data['category'],
            tcgplayer_product_id=data.get('tcgplayer_product_id'),
            image_path=None,
            image_url=data.get('image_url'),
            feature_vector=feature_vector,
            perceptual_hash=p_hash,
            created_at=now,
            updated_at=now
        )
        
        # Add to database
        db = get_card_database()
        success = db.add_card(entry)
        
        return jsonify({
            'success': success,
            'card_id': card_id
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/database/stats', methods=['GET'])
def get_database_stats():
    """Get database statistics."""
    try:
        db = get_card_database()
        
        return jsonify({
            'success': True,
            'total_cards': db.get_card_count(),
            'index_size': db.index.ntotal if db.index else 0
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


if __name__ == '__main__':
    # Development server
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'true').lower() == 'true'
    
    print(f"Starting TCG Card Scanner API on port {port}")
    print(f"Debug mode: {debug}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)

