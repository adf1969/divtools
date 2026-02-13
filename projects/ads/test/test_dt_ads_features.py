#!/usr/bin/env python3
"""
Tests for ADS Native feature implementations
Last Updated: 01/15/2026 5:00:00 PM CST

Tests for the 11 newly implemented features:
- create_config_file_links()
- install_bash_aliases()
- generate_install_doc()
- update_install_doc()
- provision_domain()
- configure_dns()
- start_services()
- stop_services()
- restart_services()
- view_logs()
- health_checks()
"""

import pytest
import sys
import os
import tempfile
import shutil
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock, mock_open, call
import subprocess

# Add dtpyutil to path
DIVTOOLS = Path(__file__).parent.parent.parent.parent
DTPYUTIL_SRC = DIVTOOLS / 'projects' / 'dtpyutil' / 'src'
if DTPYUTIL_SRC not in [Path(p) for p in sys.path]:
    sys.path.insert(0, str(DTPYUTIL_SRC))

# Import the module under test
sys.path.insert(0, str(DIVTOOLS / 'scripts' / 'ads'))
from dt_ads_native import ADSNativeApp


class TestCreateConfigFileLinks:
    """Tests for create_config_file_links() feature"""
    
    def test_missing_docker_hostdir(self, tmp_path, monkeypatch):
        """Test behavior when DOCKER_HOSTDIR is not set"""
        monkeypatch.delenv('DOCKER_HOSTDIR', raising=False)
        
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        
        # Mock msgbox to capture the error message
        with patch.object(app, 'msgbox') as mock_msgbox:
            app.create_config_links()
            
            # Verify error message shown
            mock_msgbox.assert_called_once()
            args = mock_msgbox.call_args
            assert "DOCKER_HOSTDIR" in args[1]['text']
            assert "Environment Variable Not Set" in args[1]['title']
    
    def test_creates_directory_in_test_mode(self, tmp_path, monkeypatch):
        """Test directory creation in test mode"""
        monkeypatch.setenv('DOCKER_HOSTDIR', str(tmp_path))
        
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        
        with patch.object(app, 'msgbox'):
            app.create_config_links()
            
            # Directory should not be created in test mode
            ads_cfg = tmp_path / 'ads.cfg'
            assert not ads_cfg.exists()
    
    def test_creates_symlinks_successfully(self, tmp_path, monkeypatch):
        """Test successful symlink creation"""
        monkeypatch.setenv('DOCKER_HOSTDIR', str(tmp_path))
        
        # Create mock target files
        etc_samba = tmp_path / 'etc_samba'
        etc_samba.mkdir()
        smb_conf = etc_samba / 'smb.conf'
        smb_conf.write_text('# Test config')
        
        app = ADSNativeApp(test_mode=False, debug_mode=True)
        
        # Mock file existence checks
        with patch('pathlib.Path.exists') as mock_exists:
            mock_exists.return_value = True
            
            with patch('subprocess.run') as mock_run:
                mock_run.return_value = Mock(returncode=0)
                
                with patch.object(app, 'msgbox') as mock_msgbox:
                    app.create_config_links()
                    
                    # Verify success message
                    mock_msgbox.assert_called_once()
                    args = mock_msgbox.call_args
                    assert "Config Links Created" in args[1]['title']


class TestInstallBashAliases:
    """Tests for install_bash_aliases() feature"""
    
    def test_missing_source_file(self, tmp_path, monkeypatch):
        """Test behavior when source aliases file is missing"""
        monkeypatch.setenv('DIVTOOLS', str(tmp_path))
        
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        app.divtools = tmp_path
        
        with patch.object(app, 'msgbox') as mock_msgbox:
            app.install_bash_aliases()
            
            # Verify error message
            mock_msgbox.assert_called_once()
            args = mock_msgbox.call_args
            assert "samba-aliases-native.sh not found" in args[1]['text']
    
    def test_creates_softlink_option_1(self, tmp_path, monkeypatch):
        """Test softlink creation with option 1 (user .bash_aliases)"""
        monkeypatch.setenv('DIVTOOLS', str(tmp_path))
        
        # Create source file
        projects_dir = tmp_path / 'projects' / 'ads' / 'native'
        projects_dir.mkdir(parents=True)
        source_file = projects_dir / 'samba-aliases-native.sh'
        source_file.write_text('# Test aliases')
        
        dotfiles = tmp_path / 'dotfiles'
        dotfiles.mkdir()
        
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        app.divtools = tmp_path
        
        with patch.object(app, 'menu', return_value='1'):
            with patch.object(app, 'yesno', return_value=True):
                with patch.object(app, 'msgbox') as mock_msgbox:
                    app.install_bash_aliases()
                    
                    # Verify completion message
                    calls = mock_msgbox.call_args_list
                    final_call = calls[-1]
                    assert "Installation Complete" in final_call[1]['title']


class TestGenerateInstallDoc:
    """Tests for generate_install_doc() feature"""
    
    def test_domain_validation(self, tmp_path, monkeypatch):
        """Test domain format validation"""
        monkeypatch.setenv('DIVTOOLS', str(tmp_path))
        
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        app.divtools = tmp_path
        app.env_vars = {}
        
        with patch.object(app, 'inputbox', return_value='invalid-domain'):
            with patch.object(app, 'msgbox') as mock_msgbox:
                app.generate_install_doc()
                
                # Verify validation error
                mock_msgbox.assert_called_once()
                args = mock_msgbox.call_args
                assert "Invalid Domain" in args[1]['title']
    
    def test_creates_document_successfully(self, tmp_path, monkeypatch):
        """Test successful document generation"""
        monkeypatch.setenv('DIVTOOLS', str(tmp_path))
        
        doc_dir = tmp_path / 'projects' / 'ads' / 'native'
        doc_dir.mkdir(parents=True)
        
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        app.divtools = tmp_path
        app.env_vars = {'ADS_REALM': 'FHMTN1.LAN'}
        
        with patch.object(app, 'msgbox') as mock_msgbox:
            app.generate_install_doc()
            
            # Verify document was created
            doc_path = doc_dir / 'INSTALL-STEPS-FHMTN1.LAN.md'
            assert doc_path.exists()
            
            # Verify success message
            mock_msgbox.assert_called_once()
            args = mock_msgbox.call_args
            assert "Success - REALM: FHMTN1.LAN" in args[1]['title']


class TestUpdateInstallDoc:
    """Tests for update_install_doc() feature"""
    
    def test_missing_realm_in_env(self, tmp_path, monkeypatch):
        """Test behavior when ADS_REALM is not set"""
        monkeypatch.setenv('DIVTOOLS', str(tmp_path))
        
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        app.divtools = tmp_path
        app.env_vars = {}
        
        with patch.object(app, 'msgbox') as mock_msgbox:
            app.update_install_doc()
            
            # Verify error message
            mock_msgbox.assert_called_once()
            args = mock_msgbox.call_args
            assert "Missing Configuration" in args[1]['title']
    
    def test_document_not_found(self, tmp_path, monkeypatch):
        """Test behavior when installation doc doesn't exist"""
        monkeypatch.setenv('DIVTOOLS', str(tmp_path))
        
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        app.divtools = tmp_path
        app.env_vars = {'ADS_REALM': 'TEST.LAN'}
        
        with patch.object(app, 'msgbox') as mock_msgbox:
            app.update_install_doc()
            
            # Verify error message
            mock_msgbox.assert_called_once()
            args = mock_msgbox.call_args
            assert "Document Not Found" in args[1]['title']
    
    def test_checks_installation_status(self, tmp_path, monkeypatch):
        """Test installation status checking"""
        monkeypatch.setenv('DIVTOOLS', str(tmp_path))
        
        # Create document
        doc_dir = tmp_path / 'projects' / 'ads' / 'native'
        doc_dir.mkdir(parents=True)
        doc_path = doc_dir / 'INSTALL-STEPS-TEST.LAN.md'
        doc_path.write_text('# Test doc')
        
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        app.divtools = tmp_path
        app.env_vars = {'ADS_REALM': 'TEST.LAN'}
        
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = Mock(returncode=1, stdout='', stderr='')
            
            with patch.object(app, 'msgbox') as mock_msgbox:
                app.update_install_doc()
                
                # Verify status message displayed
                mock_msgbox.assert_called_once()
                args = mock_msgbox.call_args
                # Title now contains only domain, "Installation Status" moved to text content
                assert "TEST.LAN" in args[1]['title']
                assert "Installation Status:" in args[1]['text']
                assert "Progress:" in args[1]['text']


class TestProvisionDomain:
    """Tests for provision_domain() feature"""
    
    def test_samba_not_installed(self, tmp_path, monkeypatch):
        """Test behavior when samba is not installed"""
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        
        with patch('subprocess.run', side_effect=subprocess.CalledProcessError(1, 'which')):
            with patch.object(app, 'msgbox') as mock_msgbox:
                app.provision_domain()
                
                # Verify error message
                mock_msgbox.assert_called_once()
                args = mock_msgbox.call_args
                assert "Samba Not Installed" in args[1]['title']
    
    def test_missing_required_env_vars(self, tmp_path, monkeypatch):
        """Test behavior when required env vars are missing"""
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        app.env_vars = {'ADS_DOMAIN': 'test.lan'}  # Missing REALM and PASSWORD
        
        with patch('subprocess.run', return_value=Mock(returncode=0)):
            with patch.object(app, 'load_ads_env_vars'):  # Mock to prevent loading system vars
                with patch.object(app, 'msgbox') as mock_msgbox:
                    app.provision_domain()
                    
                    # Verify error message
                    mock_msgbox.assert_called_once()
                    args = mock_msgbox.call_args
                    assert "Missing Configuration" in args[1]['title']
    
    def test_provision_in_test_mode(self, tmp_path, monkeypatch):
        """Test provisioning in test mode"""
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        app.env_vars = {
            'ADS_DOMAIN': 'test.lan',
            'ADS_REALM': 'TEST.LAN',
            'ADS_ADMIN_PASSWORD': 'ComplexPass123!',
            'ADS_WORKGROUP': 'TEST',
            'ADS_HOST_IP': '10.1.1.100'
        }
        
        with patch('subprocess.run', return_value=Mock(returncode=0)):
            with patch.object(app, 'yesno', return_value=True):
                with patch.object(app, 'msgbox') as mock_msgbox:
                    app.provision_domain()
                    
                    # Verify test mode message
                    calls = mock_msgbox.call_args_list
                    assert any("Test Mode" in call[1]['title'] for call in calls)


class TestConfigureDNS:
    """Tests for configure_dns() feature"""
    
    def test_dns_configuration_in_test_mode(self, tmp_path, monkeypatch):
        """Test DNS configuration in test mode"""
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        app.env_vars = {
            'ADS_DNS_FORWARDER': '8.8.8.8',
            'ADS_DOMAIN': 'test.lan'
        }
        
        with patch('builtins.open', mock_open(read_data='nameserver 8.8.8.8\n')):
            with patch('subprocess.run', return_value=Mock(returncode=1)):
                with patch.object(app, 'yesno', return_value=True):
                    with patch.object(app, 'msgbox') as mock_msgbox:
                        app.configure_dns()
                        
                        # Verify test mode message
                        mock_msgbox.assert_called_once()
                        assert "Test Mode" in mock_msgbox.call_args[1]['title']
    
    def test_user_cancels_dns_config(self, tmp_path, monkeypatch):
        """Test user cancelling DNS configuration"""
        app = ADSNativeApp(test_mode=False, debug_mode=True)
        app.env_vars = {'ADS_DNS_FORWARDER': '8.8.8.8', 'ADS_DOMAIN': 'test.lan'}
        
        with patch('builtins.open', mock_open(read_data='nameserver 8.8.8.8\n')):
            with patch('subprocess.run', return_value=Mock(returncode=1)):
                with patch.object(app, 'yesno', return_value=False):
                    # Should return early without error
                    app.configure_dns()


class TestServiceManagement:
    """Tests for start/stop/restart service features"""
    
    def test_start_services_success(self, tmp_path, monkeypatch):
        """Test starting services successfully"""
        app = ADSNativeApp(test_mode=False, debug_mode=True)
        
        with patch('subprocess.run', return_value=Mock(returncode=0)) as mock_run:
            with patch.object(app, 'msgbox') as mock_msgbox:
                app.start_services()
                
                # Verify systemctl commands called
                assert mock_run.call_count == 2  # start + enable
                
                # Verify success message
                mock_msgbox.assert_called_once()
                assert "Services Started" in mock_msgbox.call_args[1]['title']
    
    def test_start_services_test_mode(self, tmp_path, monkeypatch):
        """Test starting services in test mode"""
        app = ADSNativeApp(test_mode=True, debug_mode=True)
        
        with patch.object(app, 'msgbox') as mock_msgbox:
            app.start_services()
            
            # Verify test mode message
            mock_msgbox.assert_called_once()
            assert "Test Mode" in mock_msgbox.call_args[1]['title']
    
    def test_stop_services_success(self, tmp_path, monkeypatch):
        """Test stopping services successfully"""
        app = ADSNativeApp(test_mode=False, debug_mode=True)
        
        with patch('subprocess.run', return_value=Mock(returncode=0)):
            with patch.object(app, 'msgbox') as mock_msgbox:
                app.stop_services()
                
                # Verify success message
                mock_msgbox.assert_called_once()
                assert "Services Stopped" in mock_msgbox.call_args[1]['title']
    
    def test_restart_services_failure(self, tmp_path, monkeypatch):
        """Test restart services with failure"""
        app = ADSNativeApp(test_mode=False, debug_mode=True)
        
        with patch('subprocess.run', side_effect=subprocess.CalledProcessError(1, 'systemctl')):
            with patch.object(app, 'msgbox') as mock_msgbox:
                app.restart_services()
                
                # Verify error message
                mock_msgbox.assert_called_once()
                assert "Restart Failed" in mock_msgbox.call_args[1]['title']


class TestViewLogs:
    """Tests for view_logs() feature"""
    
    def test_view_logs_success(self, tmp_path, monkeypatch):
        """Test viewing logs successfully"""
        app = ADSNativeApp(test_mode=False, debug_mode=True)
        
        mock_logs = "Jan 15 12:00:00 host samba[123]: Test log entry\n"
        
        with patch('subprocess.run', return_value=Mock(returncode=0, stdout=mock_logs)):
            with patch.object(app, 'msgbox') as mock_msgbox:
                app.view_logs()
                
                # Verify logs displayed
                mock_msgbox.assert_called_once()
                args = mock_msgbox.call_args
                assert "Service Logs" in args[1]['title']
                assert "Test log entry" in args[1]['text']
    
    def test_view_logs_empty(self, tmp_path, monkeypatch):
        """Test viewing logs when no logs exist"""
        app = ADSNativeApp(test_mode=False, debug_mode=True)
        
        with patch('subprocess.run', return_value=Mock(returncode=0, stdout='')):
            with patch.object(app, 'msgbox') as mock_msgbox:
                app.view_logs()
                
                # Verify "no logs" message
                mock_msgbox.assert_called_once()
                assert "No logs found" in mock_msgbox.call_args[1]['text']


class TestHealthChecks:
    """Tests for health_checks() feature"""
    
    def test_health_checks_all_passing(self, tmp_path, monkeypatch):
        """Test health checks when all checks pass"""
        app = ADSNativeApp(test_mode=False, debug_mode=True)
        
        mock_results = [
            Mock(returncode=0),  # service is-active
            Mock(returncode=0, stdout='Domain info\n'),  # domain info
            Mock(returncode=0, stdout='FSMO roles\nLine 2\n'),  # fsmo show
        ]
        
        with patch('subprocess.run', side_effect=mock_results):
            with patch.object(app, 'msgbox') as mock_msgbox:
                app.health_checks()
                
                # Verify health check results displayed
                mock_msgbox.assert_called_once()
                args = mock_msgbox.call_args
                assert "Health Check Results" in args[1]['title']
                assert "✓" in args[1]['text']  # Success marker
    
    def test_health_checks_with_failures(self, tmp_path, monkeypatch):
        """Test health checks with some failures"""
        app = ADSNativeApp(test_mode=False, debug_mode=True)
        
        mock_results = [
            Mock(returncode=1),  # service not running
            Mock(returncode=1, stdout='', stderr='Error'),  # domain info failed
            Mock(returncode=1),  # fsmo failed
        ]
        
        with patch('subprocess.run', side_effect=mock_results):
            with patch.object(app, 'msgbox') as mock_msgbox:
                app.health_checks()
                
                # Verify failure markers shown
                mock_msgbox.assert_called_once()
                args = mock_msgbox.call_args
                assert "✗" in args[1]['text']  # Failure marker


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
