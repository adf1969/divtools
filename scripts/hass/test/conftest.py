"""
Pytest configuration and fixtures for Home Assistant script tests
Last Updated: 11/25/2025 1:36:00 PM CST
"""

import os
import pathlib
import tempfile
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


@pytest.fixture
def temp_env_file(tmp_path):
    """Create a temporary .env.hass file"""
    env_file = tmp_path / ".env.hass"
    env_file.write_text(
        """# Test environment file
HA_URL=http://test.homeassistant.local:8123
HA_TOKEN=test_token_1234567890abcdef
# Comment line
export EXTRA_VAR="extra_value"
"""
    )
    return env_file


@pytest.fixture
def mock_env(monkeypatch):
    """Clear and mock environment variables"""
    # Clear relevant env vars
    for key in ["HA_URL", "HA_TOKEN", "EXTRA_VAR"]:
        monkeypatch.delenv(key, raising=False)
    return monkeypatch


@pytest.fixture
def sample_areas():
    """Sample area data from Home Assistant"""
    return [
        {
            "area_id": "living_room",
            "name": "Living Room",
            "labels": ["main_floor", "occupied"],
        },
        {
            "area_id": "bedroom_1",
            "name": "Bedroom 1",
            "labels": ["upstairs"],
        },
        {
            "area_id": "garage",
            "name": "Garage",
            "labels": ["exclude_presence"],
        },
        {
            "area_id": "shop",
            "name": "Shop",
            "labels": [],
        },
    ]


@pytest.fixture
def sample_labels():
    """Sample label data from Home Assistant"""
    return [
        {
            "label_id": "main_floor",
            "name": "Main Floor",
            "color": "blue",
            "icon": "mdi:home",
            "description": "Main floor areas",
        },
        {
            "label_id": "upstairs",
            "name": "Upstairs",
            "color": "green",
            "icon": "mdi:stairs-up",
            "description": "Upstairs areas",
        },
        {
            "label_id": "exclude_presence",
            "name": "Exclude Presence",
            "color": "red",
            "icon": "mdi:cancel",
            "description": "Exclude from presence sensors",
        },
    ]


@pytest.fixture
def mock_websocket():
    """Mock websocket connection"""
    mock_ws = AsyncMock()
    
    # Setup auth flow
    async def recv_side_effect():
        if not hasattr(recv_side_effect, "call_count"):
            recv_side_effect.call_count = 0
        recv_side_effect.call_count += 1
        
        if recv_side_effect.call_count == 1:
            # First call: auth required
            return '{"type": "auth_required"}'
        elif recv_side_effect.call_count == 2:
            # Second call: auth ok
            return '{"type": "auth_ok"}'
        else:
            # Third call: result
            return '{"id": 1, "type": "result", "success": true, "result": []}'
    
    mock_ws.recv = recv_side_effect
    return mock_ws


@pytest.fixture
def mock_ha_config():
    """Mock Home Assistant configuration"""
    return {
        "ha_url": "http://test.homeassistant.local:8123",
        "token": "test_token_1234567890abcdef",
    }


@pytest.fixture
def temp_template_dir(tmp_path):
    """Create temporary templates directory with test template"""
    template_dir = tmp_path / "templates"
    template_dir.mkdir()
    
    template_file = template_dir / "auto_presence.j2"
    template_file.write_text(
        """# Generated at {{ timestamp }}
template:
{% for area in areas %}
  - binary_sensor:
      - name: "{{ area.area_name }} Occupancy"
        unique_id: "occupancy_{{ area.area_id }}"
        state: "{{ '{{' }} is_state('group.{{ area.area_id }}_presence', 'home') {{ '}}' }}"
{% endfor %}
"""
    )
    return template_dir


@pytest.fixture
def temp_packages_dir(tmp_path):
    """Create temporary packages directory"""
    packages_dir = tmp_path / "packages"
    packages_dir.mkdir()
    return packages_dir
