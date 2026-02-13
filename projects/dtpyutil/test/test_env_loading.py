"""
Tests for divtools environment variable loading functionality.

Verifies that load_divtools_env_files() correctly loads environment variables
from multiple locations with proper override behavior.
"""

import os
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

# Import the function to test
from dtpyutil.env import load_divtools_env_files, _get_divtools_root, _get_docker_dir


class TestGetDivtoolsRoot:
    """Test divtools root directory detection"""
    
    def test_get_divtools_root_from_env_var(self):
        """Test that DIVTOOLS env var is checked first"""
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch.dict(os.environ, {'DIVTOOLS': tmpdir}):
                result = _get_divtools_root()
                assert result == Path(tmpdir)
    
    def test_get_divtools_root_none_if_not_found(self):
        """Test that None is returned if divtools root not found"""
        # Clear all env vars and mock Path.is_dir to return False
        with patch.dict(os.environ, {}, clear=True):
            with patch('pathlib.Path.is_dir', return_value=False):
                result = _get_divtools_root()
                assert result is None


class TestLoadDivtoolsEnvFiles:
    """Test loading environment variables from multiple files"""
    
    def test_load_env_files_with_proper_override(self):
        """Test that host values override site and common values"""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = Path(tmpdir)
            
            # Create simulated docker structure
            docker_dir = tmpdir / 'docker'
            (docker_dir / 'sites' / 's00-shared').mkdir(parents=True)
            (docker_dir / 'sites' / 'example.com').mkdir(parents=True)
            (docker_dir / 'sites' / 'example.com' / 'host1').mkdir(parents=True)
            
            # Shared configuration (s00-shared)
            (docker_dir / 'sites' / 's00-shared' / '.env.s00-shared').write_text(
                'COMMON_VAR=from_common\n'
                'SHARED_VAR=shared_common\n'
            )
            
            # Site configuration
            (docker_dir / 'sites' / 'example.com' / '.env.example.com').write_text(
                'SITE_NAME=example.com\n'
                'SHARED_VAR=shared_site\n'
                'SITE_VAR=from_site\n'
            )
            
            # Host configuration
            (docker_dir / 'sites' / 'example.com' / 'host1' / '.env.host1').write_text(
                'HOSTNAME=host1\n'
                'SHARED_VAR=shared_host\n'
                'HOST_VAR=from_host\n'
            )
            
            # Test loading
            with patch('dtpyutil.env._get_docker_dir', return_value=docker_dir):
                with patch.dict(os.environ, {'SITE_NAME': 'example.com', 'HOSTNAME': 'host1'}):
                    result, failed = load_divtools_env_files()
            
            # Verify correct loading and override behavior
            assert result['COMMON_VAR'] == 'from_common'
            assert result['SITE_VAR'] == 'from_site'
            assert result['HOST_VAR'] == 'from_host'
            assert result['SHARED_VAR'] == 'shared_host'  # Host overrides site and common
            assert result['SITE_NAME'] == 'example.com'
            assert result['HOSTNAME'] == 'host1'
    
    def test_load_env_files_without_host_file(self):
        """Test loading when host file doesn't exist"""
        with tempfile.TemporaryDirectory() as tmpdir:
            docker_dir = Path(tmpdir) / 'docker'
            
            # Create partial structure (no host file)
            (docker_dir / 'sites' / 's00-shared').mkdir(parents=True)
            (docker_dir / 'sites' / 'example.com').mkdir(parents=True)
            (docker_dir / 'sites' / 'example.com' / 'host1').mkdir(parents=True)
            
            # Only create shared and site files
            (docker_dir / 'sites' / 's00-shared' / '.env.s00-shared').write_text('COMMON=yes\n')
            (docker_dir / 'sites' / 'example.com' / '.env.example.com').write_text(
                'SITE_NAME=example.com\nSITE=yes\n'
            )
            
            with patch('dtpyutil.env._get_docker_dir', return_value=docker_dir):
                with patch.dict(os.environ, {'SITE_NAME': 'example.com', 'HOSTNAME': 'host1'}):
                    result, failed = load_divtools_env_files()
            
            # Should have loaded shared and site, failed on host
            assert result['COMMON'] == 'yes'
            assert result['SITE'] == 'yes'
            assert 'host' in failed  # Host file was not found
    
    def test_load_env_files_without_site_name(self):
        """Test behavior when SITE_NAME is not available"""
        with tempfile.TemporaryDirectory() as tmpdir:
            docker_dir = Path(tmpdir) / 'docker'
            (docker_dir / 'sites' / 's00-shared').mkdir(parents=True)
            (docker_dir / 'sites' / 's00-shared' / '.env.s00-shared').write_text('COMMON=yes\n')
            
            with patch('dtpyutil.env._get_docker_dir', return_value=docker_dir):
                with patch.dict(os.environ, {}, clear=True):
                    result, failed = load_divtools_env_files()
            
            # Should only load shared, can't load site/host without SITE_NAME
            assert result.get('COMMON') == 'yes'
            assert 'site_specific' in failed


class TestEnvLoadingIntegration:
    """Integration tests for full env loading workflow"""
    
    def test_load_from_simulated_divtools(self):
        """Test loading from a complete simulated divtools structure"""
        with tempfile.TemporaryDirectory() as tmpdir:
            docker_dir = Path(tmpdir) / 'docker'
            
            # Create complete divtools structure
            (docker_dir / 'sites' / 's00-shared').mkdir(parents=True)
            (docker_dir / 'sites' / 'example.com').mkdir(parents=True)
            (docker_dir / 'sites' / 'example.com' / 'host1').mkdir(parents=True)
            
            # Shared configuration
            (docker_dir / 'sites' / 's00-shared' / '.env.s00-shared').write_text(
                'COMMON_VAR=from_common\n'
                'SHARED_VAR=shared_common\n'
            )
            
            # Site configuration
            (docker_dir / 'sites' / 'example.com' / '.env.example.com').write_text(
                'SITE_NAME=example.com\n'
                'SHARED_VAR=shared_site\n'
                'SITE_VAR=from_site\n'
            )
            
            # Host configuration
            (docker_dir / 'sites' / 'example.com' / 'host1' / '.env.host1').write_text(
                'HOSTNAME=host1\n'
                'SHARED_VAR=shared_host\n'
                'HOST_VAR=from_host\n'
            )
            
            # Test loading
            with patch('dtpyutil.env._get_docker_dir', return_value=docker_dir):
                with patch.dict(os.environ, {'SITE_NAME': 'example.com', 'HOSTNAME': 'host1'}):
                    result, failed = load_divtools_env_files()
            
            # Verify correct loading and override behavior
            assert result['COMMON_VAR'] == 'from_common'
            assert result['SITE_VAR'] == 'from_site'
            assert result['HOST_VAR'] == 'from_host'
            assert result['SHARED_VAR'] == 'shared_host'  # Host overrides site and common
            assert result['SITE_NAME'] == 'example.com'
            assert result['HOSTNAME'] == 'host1'


class TestDebugOutput:
    """Test debug output functionality"""
    
    def test_load_divtools_env_files_debug_output(self, capsys):
        """Test that debug output shows all files attempted during load"""
        with tempfile.TemporaryDirectory() as tmpdir:
            docker_dir = Path(tmpdir) / 'docker'
            
            # Create minimal divtools structure
            (docker_dir / 'sites' / 's00-shared').mkdir(parents=True)
            (docker_dir / 'sites' / 'test.com').mkdir(parents=True)
            (docker_dir / 'sites' / 's00-shared' / '.env.s00-shared').write_text('COMMON=yes\n')
            (docker_dir / 'sites' / 'test.com' / '.env.test.com').write_text('SITE=yes\n')
            
            # Load with debug enabled
            with patch('dtpyutil.env._get_docker_dir', return_value=docker_dir):
                with patch.dict(os.environ, {'SITE_NAME': 'test.com', 'HOSTNAME': ''}):
                    result, failed = load_divtools_env_files(debug=True)
            
            captured = capsys.readouterr()
            
            # Check that debug output shows attempted files
            assert 'Attempting to load' in captured.out or 'Loading' in captured.out
            assert '.env.s00-shared' in captured.out
            assert '.env.test.com' in captured.out
            # Check that loaded variables are shown
            assert 'COMMON=yes' in captured.out
            assert 'SITE=yes' in captured.out
            assert 'Total variables loaded:' in captured.out or 'loaded' in captured.out.lower()
    
    def test_debug_output_shows_missing_files(self, capsys):
        """Test that debug output indicates missing optional files"""
        with tempfile.TemporaryDirectory() as tmpdir:
            docker_dir = Path(tmpdir) / 'docker'
            
            # Create minimal structure (missing site file)
            (docker_dir / 'sites' / 's00-shared').mkdir(parents=True)
            (docker_dir / 'sites' / 'test.com').mkdir(parents=True)
            # Only create shared, not site file
            (docker_dir / 'sites' / 's00-shared' / '.env.s00-shared').write_text('COMMON=yes\n')
            
            # Load with debug
            with patch('dtpyutil.env._get_docker_dir', return_value=docker_dir):
                with patch.dict(os.environ, {'SITE_NAME': 'test.com', 'HOSTNAME': ''}):
                    result, failed = load_divtools_env_files(debug=True)
            
            captured = capsys.readouterr()
            
            # Check for missing file indicator
            assert 'not found' in captured.out.lower() or '✗' in captured.out or 'failed' in captured.out.lower()
            # Verify site file was attempted but failed
            assert '.env.test.com' in captured.out
    
    def test_debug_output_with_sensitive_values(self, capsys):
        """Test that debug output masks password and token fields"""
        with tempfile.TemporaryDirectory() as tmpdir:
            docker_dir = Path(tmpdir) / 'docker'
            (docker_dir / 'sites' / 's00-shared').mkdir(parents=True)
            (docker_dir / 'sites' / 'test.com').mkdir(parents=True)
            
            # Create env file with sensitive values
            (docker_dir / 'sites' / 's00-shared' / '.env.s00-shared').write_text(
                'ADMIN_PASSWORD=MySecretPass123\n'
                'DATABASE_SECRET=db-secret-123\n'
                'NORMAL_VAR=normalvalue\n'
            )
            (docker_dir / 'sites' / 'test.com' / '.env.test.com').write_text(
                'SITE_NAME=test.com\n'
            )
            
            # Load with debug
            with patch('dtpyutil.env._get_docker_dir', return_value=docker_dir):
                with patch.dict(os.environ, {'SITE_NAME': 'test.com', 'HOSTNAME': ''}):
                    result, failed = load_divtools_env_files(debug=True)
            
            captured = capsys.readouterr()
            
            # Sensitive values should be masked
            assert 'MySecretPass123' not in captured.out
            assert 'db-secret-123' not in captured.out
            
            # Normal value should be visible
            assert 'NORMAL_VAR=normalvalue' in captured.out
            
            # Asterisks should appear for masked values
            assert '*' in captured.out


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
