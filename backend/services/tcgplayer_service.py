"""
TCGPlayer Integration Service
Handles card price lookups and data retrieval from TCGPlayer
"""

import os
import re
import json
import hashlib
import aiohttp
import asyncio
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
from dataclasses import dataclass
from bs4 import BeautifulSoup
import requests
from dotenv import load_dotenv

load_dotenv()


@dataclass
class CardPrice:
    """Card pricing information from TCGPlayer."""
    card_name: str
    set_name: str
    tcg_category: str
    market_price: Optional[float]
    low_price: Optional[float]
    mid_price: Optional[float]
    high_price: Optional[float]
    tcgplayer_url: str
    image_url: Optional[str]
    last_updated: datetime
    condition: str = "Near Mint"
    

@dataclass
class CardSearchResult:
    """Search result from TCGPlayer."""
    product_id: str
    name: str
    set_name: str
    category: str
    image_url: str
    price_summary: Dict[str, float]
    tcgplayer_url: str


class TCGPlayerService:
    """
    Service for interacting with TCGPlayer to fetch card prices and information.
    Uses web scraping and public APIs where available.
    """
    
    BASE_URL = "https://www.tcgplayer.com"
    SEARCH_URL = f"{BASE_URL}/search/product/all"
    API_URL = "https://mpapi.tcgplayer.com/v2"
    
    # Category mappings
    CATEGORY_IDS = {
        'pokemon': 3,
        'magic_the_gathering': 1,
        'yugioh': 2,
        'sports': 72,
        'one_piece': 84,
        'disney_lorcana': 87,
        'flesh_and_blood': 73,
    }
    
    def __init__(self):
        self.session = None
        self._cache: Dict[str, Any] = {}
        self._cache_ttl = timedelta(hours=1)
        
        # Headers to mimic browser requests
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
            'Accept': 'application/json, text/html,application/xhtml+xml',
            'Accept-Language': 'en-US,en;q=0.9',
            'Referer': 'https://www.tcgplayer.com/',
        }
        
    async def _get_session(self) -> aiohttp.ClientSession:
        """Get or create aiohttp session."""
        if self.session is None or self.session.closed:
            self.session = aiohttp.ClientSession(headers=self.headers)
        return self.session
        
    def _cache_key(self, *args) -> str:
        """Generate cache key from arguments."""
        key_string = "|".join(str(arg) for arg in args)
        return hashlib.md5(key_string.encode()).hexdigest()
        
    def _get_cached(self, key: str) -> Optional[Any]:
        """Get cached value if not expired."""
        if key in self._cache:
            data, timestamp = self._cache[key]
            if datetime.now() - timestamp < self._cache_ttl:
                return data
            del self._cache[key]
        return None
        
    def _set_cached(self, key: str, data: Any):
        """Cache data with timestamp."""
        self._cache[key] = (data, datetime.now())
        
    async def search_cards(
        self, 
        query: str, 
        category: Optional[str] = None,
        limit: int = 10
    ) -> List[CardSearchResult]:
        """
        Search for cards on TCGPlayer.
        
        Args:
            query: Search query string
            category: Optional TCG category filter
            limit: Maximum results to return
            
        Returns:
            List of CardSearchResult objects
        """
        cache_key = self._cache_key('search', query, category, limit)
        cached = self._get_cached(cache_key)
        if cached:
            return cached
            
        session = await self._get_session()
        
        # Build search URL
        params = {
            'q': query,
            'view': 'grid',
        }
        
        if category and category in self.CATEGORY_IDS:
            params['CategoryId'] = self.CATEGORY_IDS[category]
            
        try:
            async with session.get(self.SEARCH_URL, params=params) as response:
                if response.status != 200:
                    return []
                    
                html = await response.text()
                results = self._parse_search_results(html, limit)
                self._set_cached(cache_key, results)
                return results
                
        except Exception as e:
            print(f"Search error: {e}")
            return []
            
    def _parse_search_results(self, html: str, limit: int) -> List[CardSearchResult]:
        """Parse search results from HTML."""
        soup = BeautifulSoup(html, 'html.parser')
        results = []
        
        # Find product cards in the search results
        product_cards = soup.find_all('div', class_=re.compile(r'search-result'))[:limit]
        
        for card in product_cards:
            try:
                # Extract product info
                link = card.find('a', href=True)
                if not link:
                    continue
                    
                product_url = link.get('href', '')
                if not product_url.startswith('http'):
                    product_url = self.BASE_URL + product_url
                    
                # Extract product ID from URL
                product_id_match = re.search(r'/product/(\d+)/', product_url)
                product_id = product_id_match.group(1) if product_id_match else ''
                
                # Get name and set
                name_elem = card.find(class_=re.compile(r'product-name|title'))
                name = name_elem.get_text(strip=True) if name_elem else 'Unknown'
                
                set_elem = card.find(class_=re.compile(r'set-name|subtitle'))
                set_name = set_elem.get_text(strip=True) if set_elem else 'Unknown Set'
                
                # Get image
                img = card.find('img')
                image_url = img.get('src', '') if img else ''
                
                # Get price
                price_elem = card.find(class_=re.compile(r'price|market'))
                price_text = price_elem.get_text(strip=True) if price_elem else '$0.00'
                price_match = re.search(r'\$?([\d,.]+)', price_text)
                market_price = float(price_match.group(1).replace(',', '')) if price_match else 0.0
                
                results.append(CardSearchResult(
                    product_id=product_id,
                    name=name,
                    set_name=set_name,
                    category='Unknown',
                    image_url=image_url,
                    price_summary={'market': market_price},
                    tcgplayer_url=product_url
                ))
                
            except Exception as e:
                print(f"Error parsing product card: {e}")
                continue
                
        return results
        
    async def get_card_prices(self, product_id: str) -> Optional[CardPrice]:
        """
        Get detailed pricing for a specific card.
        
        Args:
            product_id: TCGPlayer product ID
            
        Returns:
            CardPrice object with detailed pricing
        """
        cache_key = self._cache_key('prices', product_id)
        cached = self._get_cached(cache_key)
        if cached:
            return cached
            
        session = await self._get_session()
        
        # Try the public API endpoint
        api_url = f"{self.API_URL}/product/{product_id}/pricepoints"
        
        try:
            async with session.get(api_url) as response:
                if response.status == 200:
                    data = await response.json()
                    price = self._parse_api_prices(data, product_id)
                    if price:
                        self._set_cached(cache_key, price)
                        return price
                        
        except Exception as e:
            print(f"API price fetch error: {e}")
            
        # Fallback to scraping the product page
        product_url = f"{self.BASE_URL}/product/{product_id}"
        
        try:
            async with session.get(product_url) as response:
                if response.status != 200:
                    return None
                    
                html = await response.text()
                price = self._parse_product_page(html, product_id, product_url)
                if price:
                    self._set_cached(cache_key, price)
                return price
                
        except Exception as e:
            print(f"Product page fetch error: {e}")
            return None
            
    def _parse_api_prices(self, data: Dict, product_id: str) -> Optional[CardPrice]:
        """Parse prices from API response."""
        try:
            prices = data.get('results', [{}])[0]
            
            return CardPrice(
                card_name=prices.get('productName', 'Unknown'),
                set_name=prices.get('setName', 'Unknown'),
                tcg_category=prices.get('categoryName', 'Unknown'),
                market_price=prices.get('marketPrice'),
                low_price=prices.get('lowPrice'),
                mid_price=prices.get('midPrice'),
                high_price=prices.get('highPrice'),
                tcgplayer_url=f"{self.BASE_URL}/product/{product_id}",
                image_url=prices.get('imageUrl'),
                last_updated=datetime.now()
            )
        except Exception:
            return None
            
    def _parse_product_page(self, html: str, product_id: str, url: str) -> Optional[CardPrice]:
        """Parse prices from product page HTML."""
        soup = BeautifulSoup(html, 'html.parser')
        
        try:
            # Extract card name
            name_elem = soup.find('h1', class_=re.compile(r'product-details__name'))
            name = name_elem.get_text(strip=True) if name_elem else 'Unknown'
            
            # Extract set name
            set_elem = soup.find(class_=re.compile(r'product-details__set'))
            set_name = set_elem.get_text(strip=True) if set_elem else 'Unknown'
            
            # Extract prices
            def extract_price(class_pattern: str) -> Optional[float]:
                elem = soup.find(class_=re.compile(class_pattern))
                if elem:
                    text = elem.get_text(strip=True)
                    match = re.search(r'\$?([\d,.]+)', text)
                    if match:
                        return float(match.group(1).replace(',', ''))
                return None
                
            market_price = extract_price(r'market-price|marketPrice')
            low_price = extract_price(r'low-price|lowPrice')
            mid_price = extract_price(r'mid-price|midPrice')
            high_price = extract_price(r'high-price|highPrice')
            
            # Extract image
            img = soup.find('img', class_=re.compile(r'product-details__image'))
            image_url = img.get('src', '') if img else ''
            
            # Determine category from breadcrumbs or URL
            category = 'Unknown'
            breadcrumb = soup.find(class_=re.compile(r'breadcrumb'))
            if breadcrumb:
                crumb_text = breadcrumb.get_text().lower()
                for cat_name in self.CATEGORY_IDS.keys():
                    if cat_name.replace('_', ' ') in crumb_text:
                        category = cat_name
                        break
                        
            return CardPrice(
                card_name=name,
                set_name=set_name,
                tcg_category=category,
                market_price=market_price,
                low_price=low_price,
                mid_price=mid_price,
                high_price=high_price,
                tcgplayer_url=url,
                image_url=image_url,
                last_updated=datetime.now()
            )
            
        except Exception as e:
            print(f"Error parsing product page: {e}")
            return None
            
    async def get_price_by_name(
        self, 
        card_name: str, 
        category: Optional[str] = None
    ) -> Optional[CardPrice]:
        """
        Search for a card by name and get its price.
        
        Args:
            card_name: Name of the card to search
            category: Optional TCG category
            
        Returns:
            CardPrice for the best matching card
        """
        results = await self.search_cards(card_name, category, limit=1)
        
        if not results:
            return None
            
        return await self.get_card_prices(results[0].product_id)
        
    async def close(self):
        """Close the aiohttp session."""
        if self.session and not self.session.closed:
            await self.session.close()
            

# Synchronous wrapper for non-async contexts
class TCGPlayerServiceSync:
    """Synchronous wrapper for TCGPlayerService."""
    
    def __init__(self):
        self._async_service = TCGPlayerService()
        
    def _run_async(self, coro):
        """Run async coroutine in sync context."""
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        return loop.run_until_complete(coro)
        
    def search_cards(self, query: str, category: Optional[str] = None, limit: int = 10):
        return self._run_async(self._async_service.search_cards(query, category, limit))
        
    def get_card_prices(self, product_id: str):
        return self._run_async(self._async_service.get_card_prices(product_id))
        
    def get_price_by_name(self, card_name: str, category: Optional[str] = None):
        return self._run_async(self._async_service.get_price_by_name(card_name, category))
        
    def close(self):
        self._run_async(self._async_service.close())


# Singleton instances
_async_service: Optional[TCGPlayerService] = None
_sync_service: Optional[TCGPlayerServiceSync] = None

def get_tcgplayer_service() -> TCGPlayerService:
    """Get async TCGPlayer service singleton."""
    global _async_service
    if _async_service is None:
        _async_service = TCGPlayerService()
    return _async_service

def get_tcgplayer_service_sync() -> TCGPlayerServiceSync:
    """Get sync TCGPlayer service singleton."""
    global _sync_service
    if _sync_service is None:
        _sync_service = TCGPlayerServiceSync()
    return _sync_service

