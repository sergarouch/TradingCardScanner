# 🎴 TCG Card Scanner

A powerful iOS app that uses neural networks to identify trading cards from photos and displays their current market values from [TCGPlayer](https://www.tcgplayer.com/).

![Platform](https://img.shields.io/badge/Platform-iOS%2017+-blue)
![Python](https://img.shields.io/badge/Python-3.10+-green)
![PyTorch](https://img.shields.io/badge/PyTorch-2.1+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-purple)

## ✨ Features

- 📸 **Real-time Card Scanning** - Use your iPhone camera to scan trading cards
- 🧠 **Neural Network Recognition** - ResNet50-based model for accurate card classification
- 💰 **Live Pricing** - Fetch current market prices from TCGPlayer
- 🏷️ **Multi-TCG Support** - Supports Pokémon, Magic: The Gathering, Yu-Gi-Oh!, Sports cards, One Piece, Disney Lorcana, and more
- 📊 **Scan History** - Track all your scanned cards and their total value
- 🔍 **Search** - Search for any card on TCGPlayer directly from the app
- 🌙 **Beautiful Dark UI** - Modern, gradient-based interface optimized for card scanning

## 🏗️ Architecture

```
tcg-card-scanner/
├── backend/                    # Python backend server
│   ├── app.py                 # Flask REST API
│   ├── models/
│   │   └── card_recognition_model.py  # Neural network model
│   ├── services/
│   │   ├── tcgplayer_service.py      # TCGPlayer integration
│   │   └── card_database.py          # Local card database
│   └── requirements.txt
│
└── ios/                       # iOS app
    └── TCGCardScanner/
        ├── TCGCardScannerApp.swift    # App entry point
        ├── Views/
        │   ├── ContentView.swift      # Main tab view
        │   ├── ScannerView.swift      # Camera scanner
        │   ├── CardResultView.swift   # Card details
        │   ├── HistoryView.swift      # Scan history
        │   ├── SearchView.swift       # Card search
        │   └── SettingsView.swift     # Settings
        └── Services/
            ├── CameraManager.swift    # Camera handling
            └── APIService.swift       # Backend communication
```

## 🚀 Getting Started

### Prerequisites

- **macOS** with Xcode 15+ (for iOS development)
- **Python 3.10+**
- **iPhone** running iOS 17+ (for camera functionality)

### Backend Setup

1. **Navigate to the backend directory:**
   ```bash
   cd tcg-card-scanner/backend
   ```

2. **Create a virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

5. **Run the server:**
   ```bash
   python app.py
   ```

   The server will start on `http://localhost:5000`

### iOS App Setup

1. **Open the Xcode project:**
   ```bash
   cd tcg-card-scanner/ios
   open TCGCardScanner.xcodeproj
   ```

2. **Configure signing:**
   - Select your Development Team in project settings
   - Update the Bundle Identifier if needed

3. **Update server URL:**
   - If running on a physical device, update the server URL in the Settings tab
   - Use your computer's local IP address (e.g., `http://192.168.1.x:5000`)

4. **Build and run:**
   - Select your iPhone as the target device
   - Press `Cmd + R` to build and run

## 🔧 API Endpoints

### Card Recognition

```http
POST /api/recognize
Content-Type: application/json

{
  "image": "data:image/jpeg;base64,..."
}
```

### Card Identification with Pricing

```http
POST /api/identify
Content-Type: application/json

{
  "image": "data:image/jpeg;base64,...",
  "card_name_hint": "optional card name"
}
```

### Search Cards

```http
GET /api/search?q=charizard&category=pokemon&limit=10
```

### Get Card Price

```http
GET /api/price/{product_id}
```

### Health Check

```http
GET /health
```

## 🧠 Neural Network

The card recognition system uses a **ResNet50** architecture fine-tuned for trading card classification:

- **Feature Extraction**: 2048-dimensional feature vectors
- **Classification**: 8 TCG categories (Pokémon, MTG, Yu-Gi-Oh!, etc.)
- **Similarity Search**: FAISS index for efficient nearest-neighbor lookup
- **Perceptual Hashing**: ImageHash for exact match detection

### Supported TCG Categories

| Category | Description |
|----------|-------------|
| `pokemon` | Pokémon Trading Card Game |
| `magic_the_gathering` | Magic: The Gathering |
| `yugioh` | Yu-Gi-Oh! |
| `sports` | Sports cards (Baseball, Basketball, Football) |
| `one_piece` | One Piece Card Game |
| `disney_lorcana` | Disney Lorcana |
| `flesh_and_blood` | Flesh and Blood |
| `other` | Other trading cards |

## 📱 App Screens

### Scanner
- Camera preview with card alignment guide
- Flash toggle for low-light scanning
- Processing animation during recognition

### Card Result
- Card name, set, and category
- Match confidence percentage
- Market price with low/mid/high range
- Direct link to TCGPlayer listing

### History
- All previously scanned cards
- Total collection value
- Quick access to card details

### Search
- Search any card on TCGPlayer
- Category filtering
- Quick search suggestions

### Settings
- Server configuration
- Connection status indicator
- App statistics

## 🔒 Privacy & Permissions

The app requires the following permissions:

- **Camera**: To scan trading cards
- **Network**: To communicate with the backend server

All card images are processed on your backend server and are not stored permanently unless you explicitly add them to the database.

## 🛠️ Development

### Training Custom Models

To improve card recognition for specific TCG types, you can train custom models:

```python
from models.card_recognition_model import CardClassifier
import torch

# Initialize model
model = CardClassifier(num_classes=8, pretrained=True)

# Train with your dataset
# ... training code ...

# Save weights
torch.save({
    'classifier': model.state_dict(),
    'feature_extractor': model.feature_extractor.state_dict()
}, 'data/models/card_classifier.pth')
```

### Adding Cards to Database

```python
from services.card_database import get_card_database, CardEntry
from datetime import datetime

db = get_card_database()

entry = CardEntry(
    card_id="charizard-vmax-001",
    name="Charizard VMAX",
    set_name="Champion's Path",
    category="pokemon",
    tcgplayer_product_id="212345",
    image_url="https://...",
    feature_vector=extracted_features,  # numpy array
    perceptual_hash="abc123...",
    created_at=datetime.now().isoformat(),
    updated_at=datetime.now().isoformat()
)

db.add_card(entry)
```

## 📄 License

This project is for educational purposes. TCGPlayer pricing data is provided by [TCGPlayer.com](https://www.tcgplayer.com/).

## 🙏 Acknowledgments

- [TCGPlayer](https://www.tcgplayer.com/) for card pricing data
- [PyTorch](https://pytorch.org/) for deep learning framework
- [FAISS](https://github.com/facebookresearch/faiss) for similarity search
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) for iOS UI framework

---

**Happy Scanning! 🎴✨**

