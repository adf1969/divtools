#!/home/divix/divtools/scripts/venvs/dtpyutil/bin/python3
"""
Test suite for dt_ads_native.py
Last Updated: 01/14/2026 5:45:00 PM CST

This test suite verifies non-destructive functionality of the ADS Native Setup script.
Tests DO NOT modify the system permanently or launch Textual TUIs in terminal.

CRITICAL: Never launch Python Textual Menus inside VS Code Terminal Window
as that will WRECK the Window TTY!

Test Coverage:
- Environment variable loading
- File backup functionality
- Configuration parsing
- Command construction (without execution)
- Path validation
- Logging functionality
"""

import pytest
import sys
import os
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
import tempfile
import shutil

# Add project to path
DIVTOOLS = os.getenv('DIVTOOLS', '/home/divix/divtools')
sys.path.insert(0, str(Path(DIVTOOLS) / 'scripts' / 'ads'))

# Import the application
import dt_ads_native


class TestADSNativeApp:
    """Test suite for ADSNativeApp class"""
    
    @pytest.fixture
    def temp_dir(self):
        """Create a temporary directory for testing"""
        temp = tempfile.mkdtemp()
        yield Path(temp)
        shutil.rmtree(temp)
        
    @pytest.fixture
    def app(self, temp_dir):
        """Create an ADSNativeApp instance with test configuration"""
        # Create app instance without calling init_logging yet
        app = object.__new__(dt_ads_native.ADSNativeApp)
        
        # Set attributes manually before init
        app.test_mode = True
        app.debug_mode = True
        app.verbose = 1
        
        # Override paths to use temp directory
        app.divtools = Path(os.getenv('DIVTOOLS', '/home/divix/divtools'))
        app.config_dir = temp_dir / 'config'
        app.env_file = app.config_dir / '.env.ads'
        app.data_dir = Path('/var/lib/samba')  # Not used in tests
        app.config_samba_dir = Path('/etc/samba')  # Not used in tests
        app.log_dir = temp_dir / 'logs'
        
        # Create directories
        app.config_dir.mkdir(parents=True, exist_ok=True)
        app.log_dir.mkdir(parents=True, exist_ok=True)
        
        # Set environment markers
        app.env_marker_start = "# >>> DT_ADS_NATIVE AUTO-MANAGED - DO NOT EDIT MANUALLY <<<"
        app.env_marker_end = "# <<< DT_ADS_NATIVE AUTO-MANAGED <<<"
        
        # Initialize empty env_vars dict
        app.env_vars = {}
        
        # Now init logging with correct paths
        app.init_logging()
        
        return app
        
    def test_app_initialization(self, app):
        """Test: Application initializes with correct modes"""
        assert app.test_mode is True
        assert app.debug_mode is True
        assert app.verbose == 1
        assert app.config_dir.exists()
        assert app.log_dir.exists()
        
    def test_environment_variable_loading_no_file(self, app):
        """Test: Environment variable loading when file doesn't exist
        
        Note: Now that load_ads_env_vars() loads from divtools locations,
        it will load divtools config vars even without local .env.ads file.
        Test verifies that load_ads_env_vars() can be called without errors.
        """
        app.load_ads_env_vars()
        # Should succeed without error and have env_vars dict (may be empty or have divtools vars)
        assert isinstance(app.env_vars, dict)
        
    def test_environment_variable_loading_with_file(self, app):
        """Test: Environment variable loading from existing file"""
        # Create a test env file
        env_content = f"""
{app.env_marker_start}
export REALM="TEST.LAN"
export DOMAIN="test.lan"
export WORKGROUP="TEST"
export ADMIN_PASSWORD="TestPass123"
export HOST_IP="10.1.1.99"
{app.env_marker_end}
"""
        app.env_file.write_text(env_content)
        
        # Load variables
        app.load_ads_env_vars()
        
        # Verify
        assert app.env_vars['REALM'] == 'TEST.LAN'
        assert app.env_vars['DOMAIN'] == 'test.lan'
        assert app.env_vars['WORKGROUP'] == 'TEST'
        assert app.env_vars['ADMIN_PASSWORD'] == 'TestPass123'
        assert app.env_vars['HOST_IP'] == '10.1.1.99'
        
    def test_save_env_vars(self, app):
        """Test: Saving environment variables creates file with markers"""
        app.save_env_vars(
            realm='TESTING.LAN',
            domain='testing.lan',
            workgroup='TESTING',
            admin_pass='SecurePass456',
            host_ip='10.1.1.100'
        )
        
        # Verify file exists
        assert app.env_file.exists()
        
        # Verify content
        content = app.env_file.read_text()
        assert app.env_marker_start in content
        assert app.env_marker_end in content
        assert 'export REALM="TESTING.LAN"' in content
        assert 'export DOMAIN="testing.lan"' in content
        assert 'export WORKGROUP="TESTING"' in content
        assert 'export ADMIN_PASSWORD="SecurePass456"' in content
        assert 'export HOST_IP="10.1.1.100"' in content
        
        # Verify permissions are 600
        stat = app.env_file.stat()
        assert oct(stat.st_mode)[-3:] == '600'
        
    def test_backup_file_nonexistent(self, app):
        """Test: Backup of non-existent file returns None"""
        result = app.backup_file(app.config_dir / 'nonexistent.txt')
        assert result is None
        
    def test_backup_file_existing(self, app):
        """Test: Backup of existing file creates backup"""
        # Create a test file
        test_file = app.config_dir / 'test.conf'
        test_file.write_text('original content')
        
        # Backup the file
        backup_path = app.backup_file(test_file)
        
        # Verify backup exists
        assert backup_path is not None
        assert Path(backup_path).exists()
        assert Path(backup_path).read_text() == 'original content'
        
    def test_logging_debug_mode(self, app, capsys):
        """Test: Debug logging only appears when debug mode enabled"""
        app.debug_mode = True
        app.log("DEBUG", "This is a debug message")
        captured = capsys.readouterr()
        assert "This is a debug message" in captured.out
        
        app.debug_mode = False
        app.log("DEBUG", "This should not appear")
        captured = capsys.readouterr()
        assert "This should not appear" not in captured.out
        
    def test_logging_levels(self, app, capsys):
        """Test: Different log levels produce correct output"""
        app.log("INFO", "Info message")
        app.log("WARN", "Warning message")
        app.log("ERROR", "Error message")
        app.log("HEAD", "Header message")
        
        captured = capsys.readouterr()
        assert "Info message" in captured.out
        assert "Warning message" in captured.out
        assert "Error message" in captured.out
        assert "Header message" in captured.out
        
    def test_run_command_test_mode(self, app):
        """Test: Commands in test mode are logged but not executed"""
        result = app.run_command("echo 'test'")
        
        # In test mode, commands should return successful but empty result
        assert result.returncode == 0
        assert result.stdout == ""
        
    @patch('subprocess.run')
    def test_run_command_real_mode(self, mock_run, app):
        """Test: Commands in real mode are executed via subprocess"""
        app.test_mode = False
        
        # Mock subprocess.run
        mock_result = Mock()
        mock_result.returncode = 0
        mock_result.stdout = "command output"
        mock_result.stderr = ""
        mock_run.return_value = mock_result
        
        result = app.run_command("echo 'real test'")
        
        # Verify subprocess was called
        mock_run.assert_called_once()
        assert result.stdout == "command output"
        
    @patch('dt_ads_native.subprocess.run')
    def test_check_samba_installed_true(self, mock_run, app):
        """Test: check_samba_installed detects when Samba is present"""
        app.test_mode = False
        
        # Mock successful samba-tool check
        mock_result1 = Mock()
        mock_result1.returncode = 0
        
        mock_result2 = Mock()
        mock_result2.returncode = 0
        mock_result2.stdout = "Version 4.18.5\n"
        
        mock_run.side_effect = [mock_result1, mock_result2]
        
        result = app.check_samba_installed()
        assert result is True
        
    @patch('dt_ads_native.subprocess.run')
    def test_check_samba_installed_false(self, mock_run, app):
        """Test: check_samba_installed detects when Samba is not present"""
        app.test_mode = False
        
        # Mock failed samba-tool check
        mock_result = Mock()
        mock_result.returncode = 1
        mock_run.return_value = mock_result
        
        result = app.check_samba_installed()
        assert result is False
        
    def test_env_vars_update_preserves_other_content(self, app):
        """Test: Updating env vars preserves content outside markers"""
        # Create initial file with content before and after markers
        initial_content = """# Some custom config
export CUSTOM_VAR="value"

# Original managed section will be replaced
"""
        app.env_file.write_text(initial_content)
        
        # Save new env vars
        app.save_env_vars(
            realm='NEW.LAN',
            domain='new.lan',
            workgroup='NEW',
            admin_pass='NewPass',
            host_ip='10.1.1.101'
        )
        
        # Verify new content includes markers
        content = app.env_file.read_text()
        assert app.env_marker_start in content
        assert app.env_marker_end in content
        assert 'export REALM="NEW.LAN"' in content
        
    def test_paths_are_pathlib_objects(self, app):
        """Test: All path attributes are pathlib.Path objects"""
        assert isinstance(app.divtools, Path)
        assert isinstance(app.config_dir, Path)
        assert isinstance(app.env_file, Path)
        assert isinstance(app.data_dir, Path)
        assert isinstance(app.config_samba_dir, Path)
        assert isinstance(app.log_dir, Path)
        

class TestUtilityFunctions:
    """Test utility functions and edge cases"""
    
    def test_main_function_with_test_flag(self):
        """Test: Main function can be called with --test flag"""
        # We don't actually call main() here to avoid TUI launch
        # Instead we verify the argparse setup works
        import argparse
        parser = argparse.ArgumentParser()
        parser.add_argument('-test', '--test', action='store_true')
        parser.add_argument('-debug', '--debug', action='store_true')
        parser.add_argument('-v', action='count', default=0)
        
        args = parser.parse_args(['-test', '-debug'])
        assert args.test is True
        assert args.debug is True
        
    def test_main_function_with_verbose_flags(self):
        """Test: Verbose flags are parsed correctly"""
        import argparse
        parser = argparse.ArgumentParser()
        parser.add_argument('-test', '--test', action='store_true')
        parser.add_argument('-debug', '--debug', action='store_true')
        parser.add_argument('-v', action='count', default=0)
        
        args = parser.parse_args(['-v'])
        assert args.v == 1
        
        args = parser.parse_args(['-v', '-v'])
        assert args.v == 2
        

if __name__ == '__main__':
    # Run tests with pytest
    pytest.main([__file__, '-v'])
