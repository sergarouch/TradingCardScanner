"""
Neural Network Model for Trading Card Recognition
Uses a fine-tuned ResNet50 with custom classification head
"""

import torch
import torch.nn as nn
import torchvision.models as models
import torchvision.transforms as transforms
from PIL import Image
import numpy as np
from typing import Tuple, List, Dict, Optional
import os


class CardFeatureExtractor(nn.Module):
    """
    Feature extractor based on ResNet50 for trading card recognition.
    Extracts 2048-dimensional feature vectors for similarity matching.
    """
    
    def __init__(self, pretrained: bool = True):
        super(CardFeatureExtractor, self).__init__()
        
        # Load pretrained ResNet50
        resnet = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V2 if pretrained else None)
        
        # Remove the final classification layer
        self.features = nn.Sequential(*list(resnet.children())[:-1])
        
        # Feature dimension
        self.feature_dim = 2048
        
        # Adaptive pooling for variable input sizes
        self.adaptive_pool = nn.AdaptiveAvgPool2d((1, 1))
        
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.features(x)
        x = self.adaptive_pool(x)
        x = x.view(x.size(0), -1)
        return x


class CardClassifier(nn.Module):
    """
    Full classifier model with feature extractor and classification head.
    Can classify cards into different TCG categories.
    """
    
    TCG_CATEGORIES = [
        'pokemon', 'magic_the_gathering', 'yugioh', 
        'sports', 'one_piece', 'disney_lorcana', 
        'flesh_and_blood', 'other'
    ]
    
    def __init__(self, num_classes: int = 8, pretrained: bool = True):
        super(CardClassifier, self).__init__()
        
        self.feature_extractor = CardFeatureExtractor(pretrained=pretrained)
        
        # Classification head with dropout for regularization
        self.classifier = nn.Sequential(
            nn.Dropout(0.5),
            nn.Linear(2048, 512),
            nn.ReLU(inplace=True),
            nn.BatchNorm1d(512),
            nn.Dropout(0.3),
            nn.Linear(512, 128),
            nn.ReLU(inplace=True),
            nn.BatchNorm1d(128),
            nn.Linear(128, num_classes)
        )
        
    def forward(self, x: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        features = self.feature_extractor(x)
        logits = self.classifier(features)
        return logits, features
    
    def predict_category(self, x: torch.Tensor) -> Tuple[str, float]:
        self.eval()
        with torch.no_grad():
            logits, _ = self.forward(x)
            probs = torch.softmax(logits, dim=1)
            confidence, predicted = torch.max(probs, 1)
            category = self.TCG_CATEGORIES[predicted.item()]
        return category, confidence.item()


class CardRecognitionPipeline:
    """
    Complete pipeline for card recognition including preprocessing,
    feature extraction, and similarity matching.
    """
    
    def __init__(self, model_path: Optional[str] = None, device: str = 'auto'):
        # Set device
        if device == 'auto':
            self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        else:
            self.device = torch.device(device)
            
        # Initialize models
        self.feature_extractor = CardFeatureExtractor(pretrained=True).to(self.device)
        self.classifier = CardClassifier(pretrained=True).to(self.device)
        
        # Load custom weights if provided
        if model_path and os.path.exists(model_path):
            self._load_weights(model_path)
            
        # Set to evaluation mode
        self.feature_extractor.eval()
        self.classifier.eval()
        
        # Image preprocessing pipeline
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            )
        ])
        
        # Card-specific augmentations for better recognition
        self.card_transform = transforms.Compose([
            transforms.Resize((256, 256)),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            )
        ])
        
    def _load_weights(self, model_path: str):
        """Load custom trained weights."""
        checkpoint = torch.load(model_path, map_location=self.device)
        if 'feature_extractor' in checkpoint:
            self.feature_extractor.load_state_dict(checkpoint['feature_extractor'])
        if 'classifier' in checkpoint:
            self.classifier.load_state_dict(checkpoint['classifier'])
            
    def preprocess_image(self, image: Image.Image) -> torch.Tensor:
        """Preprocess image for model input."""
        if image.mode != 'RGB':
            image = image.convert('RGB')
        tensor = self.card_transform(image)
        return tensor.unsqueeze(0).to(self.device)
    
    def extract_features(self, image: Image.Image) -> np.ndarray:
        """Extract feature vector from image."""
        tensor = self.preprocess_image(image)
        with torch.no_grad():
            features = self.feature_extractor(tensor)
        return features.cpu().numpy().flatten()
    
    def classify_card(self, image: Image.Image) -> Dict:
        """Classify card type and extract features."""
        tensor = self.preprocess_image(image)
        
        with torch.no_grad():
            logits, features = self.classifier(tensor)
            probs = torch.softmax(logits, dim=1)
            
        # Get top 3 predictions
        top_probs, top_indices = torch.topk(probs, 3)
        
        predictions = []
        for prob, idx in zip(top_probs[0], top_indices[0]):
            predictions.append({
                'category': CardClassifier.TCG_CATEGORIES[idx.item()],
                'confidence': prob.item()
            })
            
        return {
            'predictions': predictions,
            'features': features.cpu().numpy().flatten(),
            'primary_category': predictions[0]['category'],
            'confidence': predictions[0]['confidence']
        }
    
    def compute_similarity(self, features1: np.ndarray, features2: np.ndarray) -> float:
        """Compute cosine similarity between two feature vectors."""
        dot_product = np.dot(features1, features2)
        norm1 = np.linalg.norm(features1)
        norm2 = np.linalg.norm(features2)
        return dot_product / (norm1 * norm2 + 1e-8)


# Singleton instance for API usage
_pipeline_instance: Optional[CardRecognitionPipeline] = None

def get_pipeline() -> CardRecognitionPipeline:
    """Get or create the card recognition pipeline singleton."""
    global _pipeline_instance
    if _pipeline_instance is None:
        _pipeline_instance = CardRecognitionPipeline()
    return _pipeline_instance

