"""
Tests for hass_util.py - Home Assistant utility functions
Last Updated: 11/25/2025 1:36:00 PM CST
"""

import json
import os
import pathlib
import sys
from io import StringIO
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import websockets

# Add parent directory to path for imports
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))

import hass_util


class TestSlugify:
    """Test the slugify function"""

    def test_slugify_basic(self):
        """Test basic slugification"""
        assert hass_util.slugify("Living Room") == "living_room"

    def test_slugify_special_chars(self):
        """Test slugification with special characters"""
        assert hass_util.slugify("Bed-room #1") == "bed_room_1"

    def test_slugify_multiple_spaces(self):
        """Test slugification with multiple spaces"""
        assert hass_util.slugify("Master  Bedroom   Suite") == "master_bedroom_suite"

    def test_slugify_leading_trailing(self):
        """Test slugification strips leading/trailing underscores"""
        assert hass_util.slugify("  Living Room  ") == "living_room"

    def test_slugify_numbers(self):
        """Test slugification preserves numbers"""
        assert hass_util.slugify("Bedroom 2") == "bedroom_2"

    def test_slugify_already_slug(self):
        """Test slugification of already slugified string"""
        assert hass_util.slugify("living_room") == "living_room"


class TestLoadEnvFile:
    """Test the load_env_file function"""

    def test_load_env_file_success(self, temp_env_file, mock_env):
        """Test loading environment file successfully"""
        hass_util.load_env_file(temp_env_file)
        
        assert os.environ.get("HA_URL") == "http://test.homeassistant.local:8123"
        assert os.environ.get("HA_TOKEN") == "test_token_1234567890abcdef"
        assert os.environ.get("EXTRA_VAR") == "extra_value"

    def test_load_env_file_nonexistent(self, tmp_path, mock_env):
        """Test loading non-existent file does nothing"""
        fake_file = tmp_path / "nonexistent.env"
        hass_util.load_env_file(fake_file)
        # Should not raise error

    def test_load_env_file_existing_not_overwritten(self, temp_env_file, monkeypatch):
        """Test existing environment variables are not overwritten"""
        monkeypatch.setenv("HA_URL", "http://existing.url:8123")
        
        hass_util.load_env_file(temp_env_file)
        
        # Should keep existing value
        assert os.environ.get("HA_URL") == "http://existing.url:8123"

    def test_load_env_file_comments_ignored(self, tmp_path, mock_env):
        """Test that comment lines are ignored"""
        env_file = tmp_path / ".env"
        env_file.write_text("# This is a comment\nTEST_VAR=value\n")
        
        hass_util.load_env_file(env_file)
        
        assert os.environ.get("TEST_VAR") == "value"

    def test_load_env_file_empty_lines_ignored(self, tmp_path, mock_env):
        """Test that empty lines are ignored"""
        env_file = tmp_path / ".env"
        env_file.write_text("\n\nTEST_VAR=value\n\n")
        
        hass_util.load_env_file(env_file)
        
        assert os.environ.get("TEST_VAR") == "value"


class TestGetHAConfig:
    """Test the get_ha_config function"""

    def test_get_ha_config_from_args(self, mock_env):
        """Test getting config from function arguments"""
        ha_url, token = hass_util.get_ha_config(
            ha_url="http://custom.url:8123",
            token="custom_token"
        )
        
        assert ha_url == "http://custom.url:8123"
        assert token == "custom_token"

    def test_get_ha_config_from_env(self, temp_env_file, mock_env, monkeypatch):
        """Test getting config from environment variables"""
        # Mock DEFAULT_ENV_FILE to point to our temp file
        with patch.object(hass_util, 'DEFAULT_ENV_FILE', temp_env_file):
            ha_url, token = hass_util.get_ha_config()
        
            assert ha_url == "http://test.homeassistant.local:8123"
            assert token == "test_token_1234567890abcdef"

    def test_get_ha_config_default_url(self, mock_env, monkeypatch):
        """Test default URL is used when not provided"""
        monkeypatch.setenv("HA_TOKEN", "test_token")
        
        ha_url, token = hass_util.get_ha_config()
        
        assert ha_url == "http://10.1.1.215:8123"
        assert token == "test_token"

    def test_get_ha_config_no_token_exits(self, mock_env, monkeypatch):
        """Test that missing token causes exit"""
        with patch.object(hass_util, 'DEFAULT_ENV_FILE', pathlib.Path('/nonexistent')):
            with pytest.raises(SystemExit) as exc_info:
                hass_util.get_ha_config()
            
            assert exc_info.value.code == 1

    def test_get_ha_config_args_override_env(self, temp_env_file, monkeypatch):
        """Test that arguments override environment variables"""
        monkeypatch.setenv("HA_URL", "http://env.url:8123")
        monkeypatch.setenv("HA_TOKEN", "env_token")
        
        ha_url, token = hass_util.get_ha_config(
            ha_url="http://arg.url:8123",
            token="arg_token"
        )
        
        assert ha_url == "http://arg.url:8123"
        assert token == "arg_token"


class TestFetchAreasViaWebsocket:
    """Test the fetch_areas_via_websocket function"""

    @pytest.mark.asyncio
    async def test_fetch_areas_success(self, sample_areas):
        """Test successful area fetching"""
        mock_ws = AsyncMock()
        
        # Setup recv sequence
        mock_ws.recv.side_effect = [
            '{"type": "auth_required"}',
            '{"type": "auth_ok"}',
            json.dumps({
                "id": 1,
                "type": "result",
                "success": True,
                "result": sample_areas
            })
        ]
        
        with patch('websockets.connect', return_value=mock_ws):
            areas = await hass_util.fetch_areas_via_websocket(
                "http://test:8123",
                "test_token",
                debug=False
            )
        
        assert len(areas) == 4
        assert areas[0]["name"] == "Living Room"
        assert areas[0]["area_id"] == "living_room"

    @pytest.mark.asyncio
    async def test_fetch_areas_auth_failure(self):
        """Test authentication failure"""
        mock_ws = AsyncMock()
        mock_ws.recv.side_effect = [
            '{"type": "auth_required"}',
            '{"type": "auth_invalid", "message": "Invalid token"}',
        ]
        
        with patch('websockets.connect', return_value=mock_ws):
            with pytest.raises(RuntimeError, match="Authentication failed"):
                await hass_util.fetch_areas_via_websocket(
                    "http://test:8123",
                    "bad_token",
                    debug=False
                )

    @pytest.mark.asyncio
    async def test_fetch_areas_api_failure(self):
        """Test API request failure"""
        mock_ws = AsyncMock()
        mock_ws.recv.side_effect = [
            '{"type": "auth_required"}',
            '{"type": "auth_ok"}',
            json.dumps({
                "id": 1,
                "type": "result",
                "success": False,
                "error": {"message": "Failed to retrieve areas"}
            })
        ]
        
        with patch('websockets.connect', return_value=mock_ws):
            with pytest.raises(RuntimeError, match="Failed to list areas"):
                await hass_util.fetch_areas_via_websocket(
                    "http://test:8123",
                    "test_token",
                    debug=False
                )

    @pytest.mark.asyncio
    async def test_fetch_areas_debug_output(self, sample_areas, capsys):
        """Test debug output is produced"""
        mock_ws = AsyncMock()
        mock_ws.recv.side_effect = [
            '{"type": "auth_required"}',
            '{"type": "auth_ok"}',
            json.dumps({
                "id": 1,
                "type": "result",
                "success": True,
                "result": sample_areas
            })
        ]
        
        with patch('websockets.connect', return_value=mock_ws):
            areas = await hass_util.fetch_areas_via_websocket(
                "http://test:8123",
                "test_token",
                debug=True
            )
        
        captured = capsys.readouterr()
        assert "[DEBUG]" in captured.out
        assert "Connecting to WebSocket" in captured.out


class TestFetchLabelsViaWebsocket:
    """Test the fetch_labels_via_websocket function"""

    @pytest.mark.asyncio
    async def test_fetch_labels_success(self, sample_labels):
        """Test successful label fetching"""
        mock_ws = AsyncMock()
        mock_ws.recv.side_effect = [
            '{"type": "auth_required"}',
            '{"type": "auth_ok"}',
            json.dumps({
                "id": 1,
                "type": "result",
                "success": True,
                "result": sample_labels
            })
        ]
        
        with patch('websockets.connect', return_value=mock_ws):
            labels = await hass_util.fetch_labels_via_websocket(
                "http://test:8123",
                "test_token",
                debug=False
            )
        
        assert len(labels) == 3
        assert labels[0]["name"] == "Main Floor"
        assert labels[0]["label_id"] == "main_floor"


class TestPrintAreasTables:
    """Test the print_areas_table function"""

    def test_print_areas_table_with_labels(self, sample_areas, capsys):
        """Test printing areas table with labels"""
        hass_util.print_areas_table(sample_areas, show_labels=True)
        
        captured = capsys.readouterr()
        assert "Living Room" in captured.out
        assert "living_room" in captured.out
        assert "main_floor" in captured.out

    def test_print_areas_table_without_labels(self, sample_areas, capsys):
        """Test printing areas table without labels"""
        hass_util.print_areas_table(sample_areas, show_labels=False)
        
        captured = capsys.readouterr()
        assert "Living Room" in captured.out
        assert "living_room" in captured.out
        # Labels column should not be in header
        lines = captured.out.split('\n')
        assert "Labels" not in lines[0]

    def test_print_areas_table_empty(self, capsys):
        """Test printing empty areas table"""
        hass_util.print_areas_table([], show_labels=True)
        
        captured = capsys.readouterr()
        assert "No areas found" in captured.out


class TestPrintLabelsTable:
    """Test the print_labels_table function"""

    def test_print_labels_table(self, sample_labels, capsys):
        """Test printing labels table"""
        hass_util.print_labels_table(sample_labels)
        
        captured = capsys.readouterr()
        assert "Main Floor" in captured.out
        assert "main_floor" in captured.out
        assert "blue" in captured.out

    def test_print_labels_table_empty(self, capsys):
        """Test printing empty labels table"""
        hass_util.print_labels_table([])
        
        captured = capsys.readouterr()
        assert "No labels found" in captured.out


class TestParseArgs:
    """Test the parse_args function"""

    def test_parse_args_defaults(self):
        """Test default argument values"""
        with patch('sys.argv', ['hass_util.py']):
            args = hass_util.parse_args()
            
            assert args.ha_url is None
            assert args.token is None
            assert args.list_areas is False
            assert args.list_labels is False
            assert args.debug is False

    def test_parse_args_lsa(self):
        """Test --lsa flag"""
        with patch('sys.argv', ['hass_util.py', '--lsa']):
            args = hass_util.parse_args()
            assert args.list_areas is True

    def test_parse_args_ls_areas(self):
        """Test --ls-areas flag"""
        with patch('sys.argv', ['hass_util.py', '--ls-areas']):
            args = hass_util.parse_args()
            assert args.list_areas is True

    def test_parse_args_lsl(self):
        """Test --lsl flag"""
        with patch('sys.argv', ['hass_util.py', '--lsl']):
            args = hass_util.parse_args()
            assert args.list_labels is True

    def test_parse_args_custom_url_token(self):
        """Test custom URL and token"""
        with patch('sys.argv', [
            'hass_util.py',
            '--ha-url', 'http://custom:8123',
            '--token', 'custom_token'
        ]):
            args = hass_util.parse_args()
            assert args.ha_url == 'http://custom:8123'
            assert args.token == 'custom_token'


class TestMain:
    """Test the main function"""

    def test_main_no_flags_shows_both(self, mock_env, monkeypatch, capsys):
        """Test main with no flags shows both areas and labels"""
        monkeypatch.setenv("HA_TOKEN", "test_token")
        
        mock_areas = [{"area_id": "test", "name": "Test", "labels": []}]
        mock_labels = [{"label_id": "test", "name": "Test", "color": "blue", "icon": "", "description": ""}]
        
        with patch('sys.argv', ['hass_util.py']):
            with patch('hass_util.fetch_areas_via_websocket', new=AsyncMock(return_value=mock_areas)):
                with patch('hass_util.fetch_labels_via_websocket', new=AsyncMock(return_value=mock_labels)):
                    hass_util.main()
        
        captured = capsys.readouterr()
        assert "Areas:" in captured.out
        assert "Labels:" in captured.out

    def test_main_only_areas(self, mock_env, monkeypatch, capsys):
        """Test main with --lsa shows only areas"""
        monkeypatch.setenv("HA_TOKEN", "test_token")
        
        mock_areas = [{"area_id": "test", "name": "Test", "labels": []}]
        
        with patch('sys.argv', ['hass_util.py', '--lsa']):
            with patch('hass_util.fetch_areas_via_websocket', new=AsyncMock(return_value=mock_areas)):
                hass_util.main()
        
        captured = capsys.readouterr()
        assert "Areas:" in captured.out

    def test_main_exception_handling(self, mock_env, monkeypatch):
        """Test main handles exceptions"""
        monkeypatch.setenv("HA_TOKEN", "test_token")
        
        with patch('sys.argv', ['hass_util.py', '--lsa']):
            with patch('hass_util.fetch_areas_via_websocket', side_effect=Exception("Test error")):
                with pytest.raises(SystemExit) as exc_info:
                    hass_util.main()
                assert exc_info.value.code == 1
