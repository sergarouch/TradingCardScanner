"""
Card Database Service
Stores card images and feature vectors for similarity matching
"""

import os
import json
import pickle
import numpy as np
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime
import sqlite3
from pathlib import Path

try:
    import faiss
    FAISS_AVAILABLE = True
except ImportError:
    FAISS_AVAILABLE = False
    
try:
    import imagehash
    from PIL import Image
    IMAGEHASH_AVAILABLE = True
except ImportError:
    IMAGEHASH_AVAILABLE = False


@dataclass
class CardEntry:
    """Database entry for a card."""
    card_id: str
    name: str
    set_name: str
    category: str
    tcgplayer_product_id: Optional[str]
    image_path: Optional[str]
    image_url: Optional[str]
    feature_vector: Optional[np.ndarray]
    perceptual_hash: Optional[str]
    created_at: str
    updated_at: str
    
    def to_dict(self) -> Dict:
        """Convert to dictionary, handling numpy arrays."""
        d = asdict(self)
        if self.feature_vector is not None:
            d['feature_vector'] = self.feature_vector.tolist()
        return d
        
    @classmethod
    def from_dict(cls, d: Dict) -> 'CardEntry':
        """Create from dictionary."""
        if d.get('feature_vector') is not None:
            d['feature_vector'] = np.array(d['feature_vector'])
        return cls(**d)


class CardDatabase:
    """
    Database for storing and searching trading cards using feature vectors.
    Supports both exact matching via perceptual hashing and 
    similarity search via neural network features.
    """
    
    def __init__(self, db_path: str = "data/cards.db", index_path: str = "data/card_index"):
        self.db_path = Path(db_path)
        self.index_path = Path(index_path)
        
        # Ensure directories exist
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.index_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize SQLite database
        self._init_database()
        
        # Initialize FAISS index for similarity search
        self.index = None
        self.feature_dim = 2048  # ResNet50 feature dimension
        self._init_index()
        
        # Cache for fast lookups
        self._id_to_idx: Dict[str, int] = {}
        self._idx_to_id: Dict[int, str] = {}
        self._load_index_mapping()
        
    def _init_database(self):
        """Initialize SQLite database schema."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS cards (
                card_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                set_name TEXT,
                category TEXT,
                tcgplayer_product_id TEXT,
                image_path TEXT,
                image_url TEXT,
                perceptual_hash TEXT,
                created_at TEXT,
                updated_at TEXT
            )
        ''')
        
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_perceptual_hash 
            ON cards(perceptual_hash)
        ''')
        
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_tcgplayer_id 
            ON cards(tcgplayer_product_id)
        ''')
        
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_category 
            ON cards(category)
        ''')
        
        conn.commit()
        conn.close()
        
    def _init_index(self):
        """Initialize FAISS index for similarity search."""
        if not FAISS_AVAILABLE:
            print("FAISS not available, similarity search disabled")
            return
            
        index_file = self.index_path.with_suffix('.index')
        
        if index_file.exists():
            self.index = faiss.read_index(str(index_file))
        else:
            # Create new index with cosine similarity (via normalization)
            self.index = faiss.IndexFlatIP(self.feature_dim)
            
    def _load_index_mapping(self):
        """Load mapping between card IDs and FAISS indices."""
        mapping_file = self.index_path.with_suffix('.mapping')
        
        if mapping_file.exists():
            with open(mapping_file, 'rb') as f:
                data = pickle.load(f)
                self._id_to_idx = data['id_to_idx']
                self._idx_to_id = data['idx_to_id']
                
    def _save_index_mapping(self):
        """Save ID to index mapping."""
        mapping_file = self.index_path.with_suffix('.mapping')
        
        with open(mapping_file, 'wb') as f:
            pickle.dump({
                'id_to_idx': self._id_to_idx,
                'idx_to_id': self._idx_to_id
            }, f)
            
    def _save_index(self):
        """Save FAISS index to disk."""
        if self.index is not None and FAISS_AVAILABLE:
            index_file = self.index_path.with_suffix('.index')
            faiss.write_index(self.index, str(index_file))
            
    def add_card(self, entry: CardEntry) -> bool:
        """
        Add a card to the database.
        
        Args:
            entry: CardEntry with card information
            
        Returns:
            True if successful
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO cards 
                (card_id, name, set_name, category, tcgplayer_product_id, 
                 image_path, image_url, perceptual_hash, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                entry.card_id,
                entry.name,
                entry.set_name,
                entry.category,
                entry.tcgplayer_product_id,
                entry.image_path,
                entry.image_url,
                entry.perceptual_hash,
                entry.created_at,
                entry.updated_at
            ))
            conn.commit()
            
            # Add to FAISS index if feature vector provided
            if entry.feature_vector is not None and self.index is not None:
                # Normalize for cosine similarity
                vector = entry.feature_vector.reshape(1, -1).astype('float32')
                faiss.normalize_L2(vector)
                
                # Add to index
                idx = self.index.ntotal
                self.index.add(vector)
                
                self._id_to_idx[entry.card_id] = idx
                self._idx_to_id[idx] = entry.card_id
                
                # Save periodically
                if idx % 100 == 0:
                    self._save_index()
                    self._save_index_mapping()
                    
            return True
            
        except Exception as e:
            print(f"Error adding card: {e}")
            return False
            
        finally:
            conn.close()
            
    def get_card(self, card_id: str) -> Optional[CardEntry]:
        """Get card by ID."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM cards WHERE card_id = ?', (card_id,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return CardEntry(
                card_id=row[0],
                name=row[1],
                set_name=row[2],
                category=row[3],
                tcgplayer_product_id=row[4],
                image_path=row[5],
                image_url=row[6],
                feature_vector=None,  # Not stored in SQLite
                perceptual_hash=row[7],
                created_at=row[8],
                updated_at=row[9]
            )
        return None
        
    def find_by_hash(self, perceptual_hash: str, threshold: int = 5) -> List[CardEntry]:
        """
        Find cards by perceptual hash similarity.
        
        Args:
            perceptual_hash: Hash of the query image
            threshold: Maximum Hamming distance for matches
            
        Returns:
            List of matching CardEntry objects
        """
        if not IMAGEHASH_AVAILABLE:
            return []
            
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM cards WHERE perceptual_hash IS NOT NULL')
        rows = cursor.fetchall()
        conn.close()
        
        query_hash = imagehash.hex_to_hash(perceptual_hash)
        matches = []
        
        for row in rows:
            stored_hash = imagehash.hex_to_hash(row[7])
            distance = query_hash - stored_hash
            
            if distance <= threshold:
                matches.append((
                    distance,
                    CardEntry(
                        card_id=row[0],
                        name=row[1],
                        set_name=row[2],
                        category=row[3],
                        tcgplayer_product_id=row[4],
                        image_path=row[5],
                        image_url=row[6],
                        feature_vector=None,
                        perceptual_hash=row[7],
                        created_at=row[8],
                        updated_at=row[9]
                    )
                ))
                
        # Sort by distance (best matches first)
        matches.sort(key=lambda x: x[0])
        return [m[1] for m in matches]
        
    def find_similar(
        self, 
        feature_vector: np.ndarray, 
        top_k: int = 5,
        threshold: float = 0.7
    ) -> List[Tuple[CardEntry, float]]:
        """
        Find similar cards using FAISS similarity search.
        
        Args:
            feature_vector: Query feature vector
            top_k: Number of results to return
            threshold: Minimum similarity score
            
        Returns:
            List of (CardEntry, similarity_score) tuples
        """
        if self.index is None or self.index.ntotal == 0:
            return []
            
        # Normalize query vector
        query = feature_vector.reshape(1, -1).astype('float32')
        faiss.normalize_L2(query)
        
        # Search
        scores, indices = self.index.search(query, top_k)
        
        results = []
        for score, idx in zip(scores[0], indices[0]):
            if idx == -1:
                continue
            if score < threshold:
                continue
                
            card_id = self._idx_to_id.get(idx)
            if card_id:
                card = self.get_card(card_id)
                if card:
                    results.append((card, float(score)))
                    
        return results
        
    def get_card_count(self) -> int:
        """Get total number of cards in database."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM cards')
        count = cursor.fetchone()[0]
        conn.close()
        return count
        
    def get_cards_by_category(self, category: str, limit: int = 100) -> List[CardEntry]:
        """Get cards by category."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute(
            'SELECT * FROM cards WHERE category = ? LIMIT ?', 
            (category, limit)
        )
        rows = cursor.fetchall()
        conn.close()
        
        return [
            CardEntry(
                card_id=row[0],
                name=row[1],
                set_name=row[2],
                category=row[3],
                tcgplayer_product_id=row[4],
                image_path=row[5],
                image_url=row[6],
                feature_vector=None,
                perceptual_hash=row[7],
                created_at=row[8],
                updated_at=row[9]
            )
            for row in rows
        ]
        
    def close(self):
        """Save all data and close connections."""
        self._save_index()
        self._save_index_mapping()


def compute_perceptual_hash(image: 'Image.Image') -> Optional[str]:
    """Compute perceptual hash of an image."""
    if not IMAGEHASH_AVAILABLE:
        return None
        
    # Use average hash for speed, or phash for better accuracy
    avg_hash = imagehash.average_hash(image)
    return str(avg_hash)


# Singleton instance
_db_instance: Optional[CardDatabase] = None

def get_card_database() -> CardDatabase:
    """Get or create card database singleton."""
    global _db_instance
    if _db_instance is None:
        _db_instance = CardDatabase()
    return _db_instance

