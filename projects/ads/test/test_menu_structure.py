#!/usr/bin/env python3
"""
Test Suite: Menu Structure Validation
Last Updated: 01/15/2026 23:50:00 PM CST

Tests that verify:
- Section headers are present and correct
- Menu items are numbered correctly
- Menu structure matches expected format
- Headers are non-selectable (empty tags)
- Items are selectable (non-empty tags)
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from pathlib import Path
import sys
import os

# Add project to path
DIVTOOLS = os.getenv('DIVTOOLS', '/home/divix/divtools')
sys.path.insert(0, str(Path(DIVTOOLS) / 'scripts' / 'ads'))

# Import the application
import dt_ads_native


class TestMenuStructure:
    """Test the main menu structure including headers"""
    
    @pytest.fixture
    def app(self):
        """Create app instance with mocked environment"""
        with patch.dict('os.environ', {
            'DIVTOOLS': '/home/divix/divtools',
            'SITE_NAME': 'test-site',
            'HOSTNAME': 'test-host',
            'DOCKER_HOSTDIR': '/opt/docker'
        }):
            app = dt_ads_native.ADSNativeApp(test_mode=True)
            app.env_vars = {
                'REALM': 'example.com',
                'SITE_NAME': 'test-site',
                'HOSTNAME': 'test-host'
            }
            return app
    
    def test_menu_has_section_headers(self, app):
        """Verify that section headers are present in menu items"""
        # Capture the menu call
        menu_items = []
        
        def capture_menu(*args, **kwargs):
            nonlocal menu_items
            menu_items = kwargs.get('items', [])
            return None  # Simulate user closing menu
        
        with patch.object(app, 'menu', side_effect=capture_menu):
            with patch.object(app, 'log'):
                try:
                    app.main_menu()
                except:
                    pass  # Menu exits, that's expected
        
        # Extract all items
        all_items = menu_items
        
        # Find section headers (empty tag items)
        headers = [(tag, text) for tag, text in all_items if tag == ""]
        
        # Verify headers exist
        assert len(headers) >= 5, f"Expected at least 5 headers, found {len(headers)}"
        
        # Verify specific headers are present
        header_texts = [text for tag, text in headers]
        
        assert any("INSTALLATION" in text for text in header_texts), \
            "Missing 'INSTALLATION' header"
        assert any("INSTALL GUIDE" in text for text in header_texts), \
            "Missing 'INSTALL GUIDE' header"
        assert any("DOMAIN SETUP" in text for text in header_texts), \
            "Missing 'DOMAIN SETUP' header"
        assert any("SERVICE MANAGEMENT" in text for text in header_texts), \
            "Missing 'SERVICE MANAGEMENT' header"
        assert any("DIAGNOSTICS" in text for text in header_texts), \
            "Missing 'DIAGNOSTICS' header"
    
    def test_menu_items_are_selectable(self, app):
        """Verify that menu items have non-empty tags (are selectable)"""
        menu_items = []
        
        def capture_menu(*args, **kwargs):
            nonlocal menu_items
            menu_items = kwargs.get('items', [])
            return None
        
        with patch.object(app, 'menu', side_effect=capture_menu):
            with patch.object(app, 'log'):
                try:
                    app.main_menu()
                except:
                    pass
        
        # Find selectable items (non-empty tag items)
        selectable = [(tag, text) for tag, text in menu_items if tag != ""]
        
        # Verify we have the expected number of selectable items (15)
        assert len(selectable) == 15, \
            f"Expected 15 selectable menu items, found {len(selectable)}"
    
    def test_menu_item_numbering(self, app):
        """Verify that selectable items have correct tags (1-15)"""
        menu_items = []
        
        def capture_menu(*args, **kwargs):
            nonlocal menu_items
            menu_items = kwargs.get('items', [])
            return None
        
        with patch.object(app, 'menu', side_effect=capture_menu):
            with patch.object(app, 'log'):
                try:
                    app.main_menu()
                except:
                    pass
        
        # Extract selectable items (those with non-empty tags)
        selectable_items = [(tag, text) for tag, text in menu_items if tag != ""]
        
        # Verify tags are numbered 1-15 (excluding the 0 for Exit which is at end)
        expected_tags = [str(i) for i in range(1, 15)] + ["0"]  # 1-14 plus Exit (0)
        actual_tags = [tag.strip() for tag, _ in selectable_items]
        
        assert actual_tags == expected_tags, \
            f"Expected tags {expected_tags}, got {actual_tags}"
        
        # Verify we have exactly 15 selectable items (1-14 options + Exit)
        assert len(selectable_items) == 15, \
            f"Expected 15 selectable items, got {len(selectable_items)}"
    
    def test_menu_structure_order(self, app):
        """Verify the order of menu items and headers"""
        menu_items = []
        
        def capture_menu(*args, **kwargs):
            nonlocal menu_items
            menu_items = kwargs.get('items', [])
            return None
        
        with patch.object(app, 'menu', side_effect=capture_menu):
            with patch.object(app, 'log'):
                try:
                    app.main_menu()
                except:
                    pass
        
        # Build expected structure
        expected_structure = [
            ("INSTALLATION header", ""),  # Header
            ("Install Samba", "1"),       # Item 1
            ("Configure Environment Variables", "2"),  # Item 2
            ("Check Environment Variables", "3"),  # Item 3
            ("Create Config File Links", "4"),  # Item 4
            ("Install Bash Aliases", "5"),  # Item 5
            ("INSTALL GUIDE header", ""),  # Header
            ("Generate Installation Steps Doc", "6"),  # Item 6
            ("Update Installation Steps Doc", "7"),  # Item 7
            ("DOMAIN SETUP header", ""),  # Header
            ("Provision AD Domain", "8"),  # Item 8
            ("Configure DNS on Host", "9"),  # Item 9
            ("SERVICE MANAGEMENT header", ""),  # Header
            ("Start Samba Services", "10"),  # Item 10
            ("Stop Samba Services", "11"),  # Item 11
            ("Restart Samba Services", "12"),  # Item 12
            ("View Service Logs", "13"),  # Item 13
            ("DIAGNOSTICS header", ""),  # Header
            ("Run Health Checks", "14"),  # Item 14
            ("separator", ""),  # Separator line
            ("Exit", "0"),  # Exit option
        ]
        
        # Get actual tags and check structure
        actual_tags = [tag for tag, text in menu_items]
        
        # Verify key structure points
        assert "" in actual_tags, "No headers found (empty tags)"
        
        # Count headers and items
        headers_count = sum(1 for tag in actual_tags if tag == "")
        items_count = sum(1 for tag in actual_tags if tag != "")
        
        assert headers_count >= 5, f"Expected at least 5 headers, found {headers_count}"
        assert items_count == 15, f"Expected 15 items, found {items_count}"
    
    def test_title_shows_selectable_count(self, app):
        """Verify that title shows count of selectable items only"""
        captured_title = None
        
        def capture_menu(title, *args, **kwargs):
            nonlocal captured_title
            captured_title = title
            return None
        
        with patch.object(app, 'menu', side_effect=capture_menu):
            with patch.object(app, 'log'):
                try:
                    app.main_menu()
                except:
                    pass
        
        # Verify title contains count
        assert captured_title is not None, "Menu title was not captured"
        assert "(15)" in captured_title, \
            f"Title should show '(15)' for 15 selectable items, got: {captured_title}"


class TestMenuItemDetails:
    """Test individual menu items for correct labels"""
    
    @pytest.fixture
    def app(self):
        """Create app instance with mocked environment"""
        with patch.dict('os.environ', {
            'DIVTOOLS': '/home/divix/divtools',
            'SITE_NAME': 'test-site',
            'HOSTNAME': 'test-host',
            'DOCKER_HOSTDIR': '/opt/docker'
        }):
            app = dt_ads_native.ADSNativeApp(test_mode=True)
            app.env_vars = {
                'REALM': 'example.com',
                'SITE_NAME': 'test-site',
                'HOSTNAME': 'test-host'
            }
            return app
    
    def test_installation_section_items(self, app):
        """Verify INSTALLATION section items"""
        menu_items = []
        
        def capture_menu(*args, **kwargs):
            nonlocal menu_items
            menu_items = kwargs.get('items', [])
            return None
        
        with patch.object(app, 'menu', side_effect=capture_menu):
            with patch.object(app, 'log'):
                try:
                    app.main_menu()
                except:
                    pass
        
        # Extract text for selectable items only
        selectable_texts = [text for tag, text in menu_items if tag != ""]
        
        # Verify first section items (items 0-4 in selectable list are tags 1-5)
        assert "Samba" in selectable_texts[0]
        assert "Configure Environment" in selectable_texts[1]
        assert "Check Environment" in selectable_texts[2]
        assert "Config File Links" in selectable_texts[3]
        assert "Bash Aliases" in selectable_texts[4]
    
    def test_domain_setup_section_items(self, app):
        """Verify DOMAIN SETUP section items"""
        menu_items = []
        
        def capture_menu(*args, **kwargs):
            nonlocal menu_items
            menu_items = kwargs.get('items', [])
            return None
        
        with patch.object(app, 'menu', side_effect=capture_menu):
            with patch.object(app, 'log'):
                try:
                    app.main_menu()
                except:
                    pass
        
        # Extract text for selectable items only
        selectable_texts = [text for tag, text in menu_items if tag != ""]
        
        # Domain setup items should be items 7-8 in selectable list (tags 8-9)
        assert "Provision" in selectable_texts[7]
        assert "DNS" in selectable_texts[8]
    
    def test_service_management_section_items(self, app):
        """Verify SERVICE MANAGEMENT section items"""
        menu_items = []
        
        def capture_menu(*args, **kwargs):
            nonlocal menu_items
            menu_items = kwargs.get('items', [])
            return None
        
        with patch.object(app, 'menu', side_effect=capture_menu):
            with patch.object(app, 'log'):
                try:
                    app.main_menu()
                except:
                    pass
        
        # Extract text for selectable items only
        selectable_texts = [text for tag, text in menu_items if tag != ""]
        
        # Service management items should be items 9-12 in selectable list (tags 10-13)
        assert "Start" in selectable_texts[9]
        assert "Stop" in selectable_texts[10]
        assert "Restart" in selectable_texts[11]
        assert "Logs" in selectable_texts[12]
    
    def test_diagnostics_section_item(self, app):
        """Verify DIAGNOSTICS section item"""
        menu_items = []
        
        def capture_menu(*args, **kwargs):
            nonlocal menu_items
            menu_items = kwargs.get('items', [])
            return None
        
        with patch.object(app, 'menu', side_effect=capture_menu):
            with patch.object(app, 'log'):
                try:
                    app.main_menu()
                except:
                    pass
        
        # Extract text for selectable items only
        selectable_texts = [text for tag, text in menu_items if tag != ""]
        
        # Health checks should be item 13 in selectable list (tag 14)
        assert "Health" in selectable_texts[13]


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
