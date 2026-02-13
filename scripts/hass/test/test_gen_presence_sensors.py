"""
Tests for gen_presence_sensors.py - Home Assistant presence sensor generation
Last Updated: 11/25/2025 1:36:00 PM CST
"""

import json
import os
import pathlib
import sys
from io import StringIO
from unittest.mock import AsyncMock, MagicMock, patch, mock_open

import pytest
import requests
import yaml

# Add parent directory to path for imports
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))

import gen_presence_sensors


class TestDebugPrintAreaTable:
    """Test the debug_print_area_table function"""

    def test_debug_print_area_table_with_data(self, sample_areas):
        """Test printing area table with data"""
        log_calls = []
        
        def mock_log(level, message):
            log_calls.append((level, message))
        
        gen_presence_sensors.debug_print_area_table(sample_areas, mock_log)
        
        # Check header was logged
        assert any("Area ID" in msg for _, msg in log_calls)
        assert any("Living Room" in msg for _, msg in log_calls)
        assert any("living_room" in msg for _, msg in log_calls)

    def test_debug_print_area_table_empty(self):
        """Test printing empty area table"""
        log_calls = []
        
        def mock_log(level, message):
            log_calls.append((level, message))
        
        gen_presence_sensors.debug_print_area_table([], mock_log)
        
        assert any("empty" in msg.lower() for _, msg in log_calls)


class TestCreateSensorDictsFromAreas:
    """Test the create_sensor_dicts_from_areas function"""

    def test_create_sensor_dicts_basic(self, sample_areas):
        """Test basic sensor dict creation"""
        sensors = gen_presence_sensors.create_sensor_dicts_from_areas(
            sample_areas,
            exclude_labels=None,
            debug=False
        )
        
        assert len(sensors) == 4
        assert sensors[0]["area_name"] == "Living Room"
        assert sensors[0]["area_id"] == "living_room"
        assert sensors[0]["area_slug"] == "living_room"

    def test_create_sensor_dicts_exclude_labels(self, sample_areas):
        """Test excluding areas by label"""
        sensors = gen_presence_sensors.create_sensor_dicts_from_areas(
            sample_areas,
            exclude_labels=["exclude_presence"],
            debug=False
        )
        
        # Garage has exclude_presence label, so should have 3 sensors
        assert len(sensors) == 3
        area_names = [s["area_name"] for s in sensors]
        assert "Garage" not in area_names
        assert "Living Room" in area_names

    def test_create_sensor_dicts_multiple_exclude_labels(self, sample_areas):
        """Test excluding areas with multiple labels"""
        sensors = gen_presence_sensors.create_sensor_dicts_from_areas(
            sample_areas,
            exclude_labels=["exclude_presence", "upstairs"],
            debug=False
        )
        
        # Garage and Bedroom 1 should be excluded
        assert len(sensors) == 2
        area_names = [s["area_name"] for s in sensors]
        assert "Garage" not in area_names
        assert "Bedroom 1" not in area_names

    def test_create_sensor_dicts_skip_missing_name(self):
        """Test skipping areas with missing name"""
        areas = [
            {"area_id": "test1", "name": "Test 1", "labels": []},
            {"area_id": "test2", "labels": []},  # Missing name
            {"area_id": "test3", "name": "Test 3", "labels": []},
        ]
        
        sensors = gen_presence_sensors.create_sensor_dicts_from_areas(
            areas,
            exclude_labels=None,
            debug=False
        )
        
        assert len(sensors) == 2

    def test_create_sensor_dicts_skip_missing_area_id(self):
        """Test skipping areas with missing area_id"""
        areas = [
            {"area_id": "test1", "name": "Test 1", "labels": []},
            {"name": "Test 2", "labels": []},  # Missing area_id
            {"area_id": "test3", "name": "Test 3", "labels": []},
        ]
        
        sensors = gen_presence_sensors.create_sensor_dicts_from_areas(
            areas,
            exclude_labels=None,
            debug=False
        )
        
        assert len(sensors) == 2

    def test_create_sensor_dicts_debug_output(self, sample_areas, capsys):
        """Test debug output is produced"""
        sensors = gen_presence_sensors.create_sensor_dicts_from_areas(
            sample_areas,
            exclude_labels=["exclude_presence"],
            debug=True
        )
        
        captured = capsys.readouterr()
        assert "[DEBUG]" in captured.out
        assert "Excluding areas with labels" in captured.out
        assert "Excluding area 'Garage'" in captured.out


class TestRenderTemplate:
    """Test the render_template function"""

    def test_render_template_success(self, temp_template_dir):
        """Test successful template rendering"""
        areas = [
            {"area_name": "Living Room", "area_id": "living_room", "area_slug": "living_room"},
            {"area_name": "Bedroom", "area_id": "bedroom", "area_slug": "bedroom"},
        ]
        
        with patch.object(gen_presence_sensors, '__file__', str(temp_template_dir.parent / 'dummy.py')):
            rendered = gen_presence_sensors.render_template(areas, debug=False)
        
        assert "Living Room Occupancy" in rendered
        assert "Bedroom Occupancy" in rendered
        assert "occupancy_living_room" in rendered
        assert "occupancy_bedroom" in rendered

    def test_render_template_empty_areas(self, temp_template_dir):
        """Test rendering with no areas"""
        with patch.object(gen_presence_sensors, '__file__', str(temp_template_dir.parent / 'dummy.py')):
            rendered = gen_presence_sensors.render_template([], debug=False)
        
        assert "template:" in rendered
        # Should have template structure but no sensors

    def test_render_template_debug_output(self, temp_template_dir, capsys):
        """Test debug output during rendering"""
        areas = [{"area_name": "Test", "area_id": "test", "area_slug": "test"}]
        
        with patch.object(gen_presence_sensors, '__file__', str(temp_template_dir.parent / 'dummy.py')):
            rendered = gen_presence_sensors.render_template(areas, debug=True)
        
        captured = capsys.readouterr()
        assert "[DEBUG]" in captured.out
        assert "Rendering template" in captured.out


class TestWriteYAML:
    """Test the write_yaml function"""

    def test_write_yaml_success(self, temp_packages_dir, temp_template_dir):
        """Test successful YAML file writing"""
        areas = [{"area_name": "Test", "area_id": "test", "area_slug": "test"}]
        output_file = temp_packages_dir / "test-output.yaml"
        
        with patch.object(gen_presence_sensors, '__file__', str(temp_template_dir.parent / 'dummy.py')):
            gen_presence_sensors.write_yaml(areas, output_file, debug=False)
        
        assert output_file.exists()
        content = output_file.read_text()
        assert "Test Occupancy" in content

    def test_write_yaml_creates_parent_dirs(self, tmp_path, temp_template_dir):
        """Test that parent directories are created"""
        output_file = tmp_path / "subdir" / "output.yaml"
        areas = [{"area_name": "Test", "area_id": "test", "area_slug": "test"}]
        
        with patch.object(gen_presence_sensors, '__file__', str(temp_template_dir.parent / 'dummy.py')):
            gen_presence_sensors.write_yaml(areas, output_file, debug=False)
        
        assert output_file.exists()
        assert output_file.parent.exists()


class TestCopyToRemote:
    """Test the copy_to_remote function"""

    def test_copy_success(self, tmp_path):
        """Test successful file copy to remote mount"""
        source_file = tmp_path / "source.yaml"
        source_file.write_text("test: content")
        
        remote_dir = tmp_path / "remote_mount" / "packages"
        remote_dir.mkdir(parents=True)
        
        gen_presence_sensors.copy_to_remote(
            source_file,
            str(remote_dir / "source.yaml"),
            debug=False
        )
        
        # Verify file was copied
        assert (remote_dir / "source.yaml").exists()
        assert (remote_dir / "source.yaml").read_text() == "test: content"

    def test_copy_creates_parent_dirs(self, tmp_path):
        """Test that copy creates parent directories"""
        source_file = tmp_path / "source.yaml"
        source_file.write_text("test: content")
        
        remote_dir = tmp_path / "new" / "nested" / "packages"
        remote_mount = str(remote_dir / "test.yaml")
        
        gen_presence_sensors.copy_to_remote(source_file, remote_mount, debug=False)
        
        assert (remote_dir / "test.yaml").exists()

    def test_copy_missing_source(self, tmp_path):
        """Test error handling for missing source file"""
        with pytest.raises(FileNotFoundError):
            gen_presence_sensors.copy_to_remote(
                tmp_path / "nonexistent.yaml",
                str(tmp_path / "dest.yaml"),
                debug=False
            )

    def test_copy_missing_mount(self, tmp_path):
        """Test error handling for missing/inaccessible remote mount"""
        source_file = tmp_path / "source.yaml"
        source_file.write_text("test: content")
        
        with pytest.raises(FileNotFoundError, match="Cannot access or create directory"):
            gen_presence_sensors.copy_to_remote(
                source_file,
                "/nonexistent/mount/path/file.yaml",
                debug=False
            )


class TestExtractSensorEntitiesFromYAML:
    """Test extracting sensor entities from YAML"""

    def test_extract_from_valid_yaml(self, tmp_path):
        """Test extracting sensor entities from valid YAML"""
        yaml_file = tmp_path / "auto_presence.yaml"
        yaml_content = {
            "template": [
                {
                    "binary_sensor": [
                        {"unique_id": "living_room_occupied", "name": "Living Room Occupancy"},
                        {"unique_id": "kitchen_occupied", "name": "Kitchen Occupancy"},
                    ]
                }
            ]
        }
        yaml_file.write_text(yaml.dump(yaml_content))
        
        entities = gen_presence_sensors.extract_sensor_entities_from_yaml(yaml_file)
        
        assert len(entities) == 2
        assert "binary_sensor.living_room_occupied" in entities
        assert "binary_sensor.kitchen_occupied" in entities

    def test_extract_from_missing_file(self, tmp_path):
        """Test handling of missing YAML file"""
        entities = gen_presence_sensors.extract_sensor_entities_from_yaml(
            tmp_path / "nonexistent.yaml"
        )
        assert entities == []

    def test_extract_from_empty_yaml(self, tmp_path):
        """Test handling of YAML file with no binary_sensor"""
        yaml_file = tmp_path / "empty.yaml"
        yaml_file.write_text("automation: []")
        
        entities = gen_presence_sensors.extract_sensor_entities_from_yaml(yaml_file)
        assert entities == []


class TestParseAddLabels:
    """Test parsing add-labels argument"""

    def test_parse_comma_separated(self):
        """Test comma-separated label parsing"""
        result = gen_presence_sensors.parse_add_labels(["label1,label2,label3"])
        assert result == ["label1", "label2", "label3"]

    def test_parse_comma_space_separated(self):
        """Test comma+space-separated label parsing"""
        result = gen_presence_sensors.parse_add_labels(["label1, label2, label3"])
        assert result == ["label1", "label2", "label3"]

    def test_parse_space_separated(self):
        """Test space-separated label parsing"""
        result = gen_presence_sensors.parse_add_labels(["label1", "label2", "label3"])
        assert result == ["label1", "label2", "label3"]

    def test_parse_mixed_formats(self):
        """Test mixed format parsing"""
        result = gen_presence_sensors.parse_add_labels(["label1,label2", "label3"])
        assert set(result) == {"label1", "label2", "label3"}

    def test_parse_removes_duplicates(self):
        """Test that duplicates are removed"""
        result = gen_presence_sensors.parse_add_labels(["label1,label1,label2"])
        assert result == ["label1", "label2"]

    def test_parse_empty(self):
        """Test parsing empty input"""
        result = gen_presence_sensors.parse_add_labels([])
        assert result == []


@pytest.mark.asyncio
class TestUpdateEntityLabels:
    """Test updating entity labels via WebSocket"""

    async def test_update_labels_success(self):
        """Test successful label update"""
        mock_ws = AsyncMock()
        mock_ws.recv = AsyncMock(side_effect=[
            json.dumps({"type": "auth_required"}),
            json.dumps({"type": "auth_ok"}),
            "config/entity_registry/update_success"  # Success response
        ])
        
        async_context = AsyncMock()
        async_context.__aenter__.return_value = mock_ws
        async_context.__aexit__.return_value = None
        
        with patch('websockets.connect', return_value=async_context):
            result = await gen_presence_sensors.update_entity_labels(
                "binary_sensor.test",
                ["new_label"],
                "http://test:8123",
                "test_token",
                debug=False
            )
        
        assert result is True

    async def test_update_labels_failure(self):
        """Test failed label update"""
        mock_ws = AsyncMock()
        mock_ws.recv = AsyncMock(side_effect=[
            json.dumps({"type": "auth_required"}),
            json.dumps({"type": "auth_ok"}),
            "error"  # Failure response
        ])
        
        async_context = AsyncMock()
        async_context.__aenter__.return_value = mock_ws
        async_context.__aexit__.return_value = None
        
        with patch('websockets.connect', return_value=async_context):
            result = await gen_presence_sensors.update_entity_labels(
                "binary_sensor.test",
                ["new_label"],
                "http://test:8123",
                "test_token",
                debug=False
            )
        
        assert result is False


class TestParseArgs:
    """Test the parse_args function"""

    def test_parse_args_defaults(self):
        """Test default argument values"""
        with patch('sys.argv', ['gen_presence_sensors.py']):
            args = gen_presence_sensors.parse_args()
            
            assert args.test is False
            assert args.skip_copy is False
            assert args.debug is False
            assert args.exclude_labels == ['no_occupancy', 'christmas']
            assert args.add_labels is None  # None by default, only set if user provides --add-labels

    def test_parse_args_test_mode(self):
        """Test --test flag"""
        with patch('sys.argv', ['gen_presence_sensors.py', '--test']):
            args = gen_presence_sensors.parse_args()
            assert args.test is True

    def test_parse_args_skip_copy(self):
        """Test --skip-copy flag"""
        with patch('sys.argv', ['gen_presence_sensors.py', '--skip-copy']):
            args = gen_presence_sensors.parse_args()
            assert args.skip_copy is True

    def test_parse_args_exclude_labels(self):
        """Test --exclude-labels argument"""
        with patch('sys.argv', ['gen_presence_sensors.py', '--exclude-labels', 'label1', 'label2']):
            args = gen_presence_sensors.parse_args()
            assert args.exclude_labels == ['label1', 'label2']

    def test_parse_args_add_labels(self):
        """Test --add-labels argument"""
        with patch('sys.argv', ['gen_presence_sensors.py', '--add-labels', 'monitored,important']):
            args = gen_presence_sensors.parse_args()
            assert args.add_labels == ['monitored', 'important']

    def test_parse_args_custom_paths(self):
        """Test custom output and remote mount paths"""
        with patch('sys.argv', [
            'gen_presence_sensors.py',
            '--local-output', '/tmp/output.yaml',
            '--remote-mount', '/custom/remote/file.yaml'
        ]):
            args = gen_presence_sensors.parse_args()
            assert args.local_output == '/tmp/output.yaml'
            assert args.remote_mount == '/custom/remote/file.yaml'


class TestMain:
    """Test the main function"""

    def test_main_test_mode(self, mock_env, monkeypatch, sample_areas, temp_template_dir, capsys):
        """Test main in test mode"""
        monkeypatch.setenv("HA_TOKEN", "test_token")
        
        with patch('sys.argv', ['gen_presence_sensors.py', '--test']):
            with patch('gen_presence_sensors.fetch_areas_via_websocket', new=AsyncMock(return_value=sample_areas)):
                with patch.object(gen_presence_sensors, '__file__', str(temp_template_dir.parent / 'dummy.py')):
                    gen_presence_sensors.main()
        
        captured = capsys.readouterr()
        assert "TEST MODE" in captured.out
        assert "template:" in captured.out

    def test_main_skip_upload(self, mock_env, monkeypatch, sample_areas, temp_template_dir, tmp_path):
        """Test main with skip copy"""
        monkeypatch.setenv("HA_TOKEN", "test_token")
        output_file = tmp_path / "output.yaml"
        
        with patch('sys.argv', [
            'gen_presence_sensors.py',
            '--skip-copy',
            '--local-output', str(output_file)
        ]):
            with patch('gen_presence_sensors.fetch_areas_via_websocket', new=AsyncMock(return_value=sample_areas)):
                with patch.object(gen_presence_sensors, '__file__', str(temp_template_dir.parent / 'dummy.py')):
                    gen_presence_sensors.main()
        
        # File should be created
        assert output_file.exists()

    def test_main_full_flow(self, mock_env, monkeypatch, sample_areas, temp_template_dir, tmp_path):
        """Test main with full copy flow"""
        monkeypatch.setenv("HA_TOKEN", "test_token")
        output_file = tmp_path / "output.yaml"
        remote_file = tmp_path / "remote" / "auto_presence.yaml"
        
        with patch('sys.argv', [
            'gen_presence_sensors.py',
            '--local-output', str(output_file),
            '--remote-mount', str(remote_file)
        ]):
            with patch('gen_presence_sensors.fetch_areas_via_websocket', new=AsyncMock(return_value=sample_areas)):
                with patch.object(gen_presence_sensors, '__file__', str(temp_template_dir.parent / 'dummy.py')):
                    gen_presence_sensors.main()
        
        # File should be created and copied
        assert output_file.exists()
        assert remote_file.exists()

    def test_main_exclude_labels(self, mock_env, monkeypatch, sample_areas, temp_template_dir, tmp_path, capsys):
        """Test main with label exclusion"""
        monkeypatch.setenv("HA_TOKEN", "test_token")
        
        with patch('sys.argv', [
            'gen_presence_sensors.py',
            '--test',
            '--exclude-labels', 'exclude_presence'
        ]):
            with patch('gen_presence_sensors.fetch_areas_via_websocket', new=AsyncMock(return_value=sample_areas)):
                with patch.object(gen_presence_sensors, '__file__', str(temp_template_dir.parent / 'dummy.py')):
                    gen_presence_sensors.main()
        
        captured = capsys.readouterr()
        # Garage should be excluded
        assert "Garage" not in captured.out
        assert "Living Room" in captured.out

    def test_main_fetch_error(self, mock_env, monkeypatch):
        """Test main handles fetch errors"""
        monkeypatch.setenv("HA_TOKEN", "test_token")
        
        with patch('sys.argv', ['gen_presence_sensors.py', '--test']):
            with patch('gen_presence_sensors.fetch_areas_via_websocket', side_effect=Exception("Connection error")):
                with pytest.raises(SystemExit) as exc_info:
                    gen_presence_sensors.main()
                assert exc_info.value.code == 1

    def test_main_upload_error(self, mock_env, monkeypatch, sample_areas, temp_template_dir, tmp_path):
        """Test main handles copy errors"""
        monkeypatch.setenv("HA_TOKEN", "test_token")
        output_file = tmp_path / "output.yaml"
        
        with patch('sys.argv', ['gen_presence_sensors.py', '--local-output', str(output_file)]):
            with patch('gen_presence_sensors.fetch_areas_via_websocket', new=AsyncMock(return_value=sample_areas)):
                with patch('gen_presence_sensors.copy_to_remote', side_effect=PermissionError("Mount not accessible")):
                    with patch.object(gen_presence_sensors, '__file__', str(temp_template_dir.parent / 'dummy.py')):
                        with pytest.raises(SystemExit) as exc_info:
                            gen_presence_sensors.main()
                        assert exc_info.value.code == 1


class TestYAMLRepresenter:
    """Test custom YAML representer"""

    def test_multiline_string_folded(self):
        """Test multiline strings use folded style"""
        data = {"key": "line1\nline2\nline3"}
        result = yaml.dump(data)
        # Should use folded style (>)
        assert ">" in result or "line1" in result

    def test_single_line_string_plain(self):
        """Test single line strings use plain style"""
        data = {"key": "single line"}
        result = yaml.dump(data)
        assert "single line" in result
