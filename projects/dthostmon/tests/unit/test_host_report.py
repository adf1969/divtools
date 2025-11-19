"""
Unit tests for host_report.py - Host Report Generator
Last Updated: 11/15/2025 3:55:00 PM CST

Tests all sections of host report generation including critical issues,
system health, system changes, log analysis, docker logs, non-critical items,
and AI analysis sections.
"""

import pytest
from datetime import datetime
from unittest.mock import Mock, patch, MagicMock
from src.dthostmon.core.host_report import HostReportGenerator


class TestHostReportGenerator:
    """Test suite for HostReportGenerator class"""
    
    @pytest.fixture
    def mock_config(self):
        """Create mock Config object with threshold configuration"""
        config = Mock()
        config.get_resource_thresholds.return_value = {
            'health': (0, 30),
            'info': (31, 60),
            'warning': (61, 89),
            'critical': (90, 100)
        }
        return config
    
    @pytest.fixture
    def sample_host_data(self):
        """Sample host monitoring data for testing"""
        return {
            'hostname': 'prod-web-01',
            'site': 's01-chicago',
            'tags': ['production', 'webserver', 'nginx'],
            'timestamp': datetime(2025, 11, 15, 15, 30, 0),
            'metrics': {
                'cpu_percent': 45.2,
                'memory_percent': 67.8,
                'disk_percent': 92.5
            },
            'anomalies': [
                {
                    'severity': 'CRITICAL',
                    'category': 'DISK_SPACE',
                    'description': 'Disk usage exceeded 90% threshold',
                    'details': 'Root partition at 92.5% capacity',
                    'recommendation': 'Clean up old logs or expand storage'
                },
                {
                    'severity': 'WARN',
                    'category': 'MEMORY',
                    'description': 'Memory usage elevated',
                    'details': 'Memory at 67.8%, above 60% threshold'
                }
            ],
            'system_changes': {
                'bash_history': [
                    {'timestamp': '2025-11-15 14:20:00', 'command': 'sudo systemctl restart nginx'},
                    {'timestamp': '2025-11-15 14:22:00', 'command': 'tail -f /var/log/nginx/error.log'}
                ],
                'apt_history': [
                    {
                        'timestamp': '2025-11-14 10:00:00',
                        'action': 'Install',
                        'packages': ['nginx-extras', 'certbot']
                    }
                ],
                'filesystem_changes': [
                    {
                        'path': '/etc/nginx/nginx.conf',
                        'change_type': 'modified',
                        'timestamp': '2025-11-15 14:15:00'
                    }
                ]
            },
            'log_analysis': {
                'syslog': [
                    {
                        'timestamp': '2025-11-15 15:10:00',
                        'severity': 'ERROR',
                        'message': 'nginx: worker process died unexpectedly'
                    },
                    {
                        'timestamp': '2025-11-15 15:11:00',
                        'severity': 'INFO',
                        'message': 'nginx: worker process restarted'
                    }
                ],
                'auth.log': [
                    {
                        'timestamp': '2025-11-15 12:30:00',
                        'severity': 'WARN',
                        'message': 'Failed password for invalid user admin from 10.1.1.50'
                    }
                ]
            },
            'docker_logs': {
                'web-app': [
                    {
                        'timestamp': '2025-11-15 15:20:00',
                        'level': 'ERROR',
                        'message': 'Connection to database timed out'
                    }
                ]
            },
            'ai_analysis': {
                'summary': 'Critical disk space issue detected. Recent nginx configuration changes may have caused worker process crash.',
                'recommendations': [
                    'Immediately address disk space on root partition',
                    'Review nginx configuration changes from 14:15',
                    'Investigate database connection timeouts in web-app container'
                ],
                'health_score': 62
            }
        }
    
    @pytest.fixture
    def minimal_host_data(self):
        """Minimal host data with no issues"""
        return {
            'hostname': 'test-host',
            'timestamp': datetime(2025, 11, 15, 16, 0, 0),
            'metrics': {
                'cpu_percent': 15.0,
                'memory_percent': 25.0,
                'disk_percent': 35.0
            },
            'anomalies': [],
            'system_changes': {},
            'log_analysis': {},
            'docker_logs': {}
        }
    
    def test_initialization(self, mock_config):
        """Test HostReportGenerator initialization"""
        generator = HostReportGenerator(mock_config)
        
        assert generator.config == mock_config
        assert generator.thresholds == {
            'health': (0, 30),
            'info': (31, 60),
            'warning': (61, 89),
            'critical': (90, 100)
        }
    
    def test_generate_report_with_full_data(self, mock_config, sample_host_data):
        """Test generating complete report with all sections"""
        generator = HostReportGenerator(mock_config)
        report = generator.generate_report(sample_host_data)
        
        # Check report structure
        assert isinstance(report, str)
        assert len(report) > 0
        
        # Check header section
        assert "# Host Monitoring Report: prod-web-01" in report
        assert "**Site:** s01-chicago" in report
        assert "**Tags:** production, webserver, nginx" in report
        assert "2025-11-15 15:30:00" in report
        
        # Check all major sections present
        assert "## 🚨 Critical Issues" in report
        assert "## 📊 System Health" in report
        assert "## 🔄 System Changes" in report
        assert "## 📝 Log Analysis" in report
        assert "## 🐳 Docker Container Logs" in report
        assert "## ℹ️ Non-Critical Items" in report
        assert "## 🤖 AI Analysis" in report
    
    def test_generate_report_with_minimal_data(self, mock_config, minimal_host_data):
        """Test generating report with minimal/no issues"""
        generator = HostReportGenerator(mock_config)
        report = generator.generate_report(minimal_host_data)
        
        # Should still have basic structure
        assert "# Host Monitoring Report: test-host" in report
        assert "## 📊 System Health" in report
        
        # Should have healthy indicators
        assert "✅" in report or "ℹ️" in report
        
        # Should indicate no critical issues
        assert "No critical issues detected" in report or "🚨 Critical Issues" not in report
    
    def test_critical_issues_section(self, mock_config, sample_host_data):
        """Test critical issues section generation"""
        generator = HostReportGenerator(mock_config)
        report = generator.generate_report(sample_host_data)
        
        # Check critical issue details
        assert "**Severity:** CRITICAL" in report
        assert "**Category:** DISK_SPACE" in report
        assert "Disk usage exceeded 90% threshold" in report
        assert "Root partition at 92.5% capacity" in report
        assert "**Recommendation:** Clean up old logs or expand storage" in report
        
        # Check warning issue
        assert "**Severity:** WARN" in report
        assert "**Category:** MEMORY" in report
    
    def test_system_health_section_with_thresholds(self, mock_config, sample_host_data):
        """Test system health section with threshold-based status"""
        generator = HostReportGenerator(mock_config)
        report = generator.generate_report(sample_host_data)
        
        # Check health metrics present
        assert "**CPU Usage:** 45.20%" in report
        assert "**Memory Usage:** 67.80%" in report
        assert "**Disk Usage:** 92.50%" in report
        
        # Check status indicators
        # CPU 45% should be Info (31-60%)
        # Memory 67.8% should be Warning (61-89%)
        # Disk 92.5% should be Critical (90-100%)
        assert "ℹ️" in report or "INFO" in report
        assert "⚠️" in report or "WARNING" in report
        assert "🚨" in report or "CRITICAL" in report
    
    def test_system_changes_section_grouping(self, mock_config, sample_host_data):
        """Test system changes section with proper grouping"""
        generator = HostReportGenerator(mock_config)
        report = generator.generate_report(sample_host_data)
        
        # Check bash history changes
        assert "### Command History" in report or "bash_history" in report
        assert "sudo systemctl restart nginx" in report
        assert "tail -f /var/log/nginx/error.log" in report
        
        # Check apt history
        assert "### Package Changes" in report or "apt_history" in report
        assert "Install" in report
        assert "nginx-extras" in report
        assert "certbot" in report
        
        # Check filesystem changes
        assert "### Filesystem Changes" in report or "filesystem_changes" in report
        assert "/etc/nginx/nginx.conf" in report
        assert "modified" in report
    
    def test_log_analysis_section_with_highlights(self, mock_config, sample_host_data):
        """Test log analysis section with error highlights"""
        generator = HostReportGenerator(mock_config)
        report = generator.generate_report(sample_host_data)
        
        # Check syslog entries
        assert "nginx: worker process died unexpectedly" in report
        assert "nginx: worker process restarted" in report
        
        # Check auth.log entries
        assert "Failed password for invalid user admin" in report
        assert "10.1.1.50" in report
        
        # Check severity indicators present
        assert "ERROR" in report or "🔴" in report
        assert "WARN" in report or "⚠️" in report
    
    def test_docker_logs_section(self, mock_config, sample_host_data):
        """Test Docker container logs section"""
        generator = HostReportGenerator(mock_config)
        report = generator.generate_report(sample_host_data)
        
        # Check container name
        assert "web-app" in report
        
        # Check log entry
        assert "Connection to database timed out" in report
        assert "ERROR" in report
    
    def test_ai_analysis_section(self, mock_config, sample_host_data):
        """Test AI analysis section generation"""
        generator = HostReportGenerator(mock_config)
        report = generator.generate_report(sample_host_data)
        
        # Check AI summary
        assert "Critical disk space issue detected" in report
        assert "Recent nginx configuration changes" in report
        
        # Check recommendations
        assert "Immediately address disk space" in report
        assert "Review nginx configuration changes" in report
        assert "Investigate database connection timeouts" in report
        
        # Check health score
        assert "62" in report or "Health Score" in report
    
    def test_ai_analysis_missing(self, mock_config, minimal_host_data):
        """Test report generation when AI analysis is missing"""
        generator = HostReportGenerator(mock_config)
        report = generator.generate_report(minimal_host_data)
        
        # Should not crash, but AI section should be minimal or omitted
        assert isinstance(report, str)
        # AI section should either be missing or indicate no analysis
        assert "🤖 AI Analysis" not in report or "No AI analysis available" in report
    
    def test_get_resource_status_health(self, mock_config):
        """Test resource status determination - health range"""
        generator = HostReportGenerator(mock_config)
        
        status = generator._get_resource_status(25.0)
        assert status == 'health'
        
        status = generator._get_resource_status(30.0)
        assert status == 'health'
    
    def test_get_resource_status_info(self, mock_config):
        """Test resource status determination - info range"""
        generator = HostReportGenerator(mock_config)
        
        status = generator._get_resource_status(31.0)
        assert status == 'info'
        
        status = generator._get_resource_status(45.0)
        assert status == 'info'
        
        status = generator._get_resource_status(60.0)
        assert status == 'info'
    
    def test_get_resource_status_warning(self, mock_config):
        """Test resource status determination - warning range"""
        generator = HostReportGenerator(mock_config)
        
        status = generator._get_resource_status(61.0)
        assert status == 'warning'
        
        status = generator._get_resource_status(75.0)
        assert status == 'warning'
        
        status = generator._get_resource_status(89.0)
        assert status == 'warning'
    
    def test_get_resource_status_critical(self, mock_config):
        """Test resource status determination - critical range"""
        generator = HostReportGenerator(mock_config)
        
        status = generator._get_resource_status(90.0)
        assert status == 'critical'
        
        status = generator._get_resource_status(95.0)
        assert status == 'critical'
        
        status = generator._get_resource_status(100.0)
        assert status == 'critical'
    
    def test_get_status_emoji_mapping(self, mock_config):
        """Test emoji mapping for status levels"""
        generator = HostReportGenerator(mock_config)
        
        assert generator._get_status_emoji('health') == '✅'
        assert generator._get_status_emoji('info') == 'ℹ️'
        assert generator._get_status_emoji('warning') == '⚠️'
        assert generator._get_status_emoji('critical') == '🚨'
        
        # Test unknown status
        assert generator._get_status_emoji('unknown') == '❓'
    
    def test_extract_log_highlights_with_errors(self, mock_config):
        """Test log highlight extraction prioritizes errors"""
        generator = HostReportGenerator(mock_config)
        
        log_entries = [
            {'severity': 'INFO', 'message': 'Service started'},
            {'severity': 'ERROR', 'message': 'Database connection failed'},
            {'severity': 'WARN', 'message': 'High memory usage'},
            {'severity': 'ERROR', 'message': 'Disk write error'},
            {'severity': 'INFO', 'message': 'Request processed'}
        ]
        
        highlights = generator._extract_log_highlights(log_entries, max_items=3)
        
        # Should prioritize errors
        assert len(highlights) <= 3
        assert any('Database connection failed' in str(h) for h in highlights)
        assert any('Disk write error' in str(h) for h in highlights)
    
    def test_extract_log_highlights_empty_list(self, mock_config):
        """Test log highlight extraction with empty list"""
        generator = HostReportGenerator(mock_config)
        
        highlights = generator._extract_log_highlights([])
        assert highlights == []
    
    def test_non_critical_section_with_warnings(self, mock_config, sample_host_data):
        """Test non-critical items section includes warnings"""
        generator = HostReportGenerator(mock_config)
        report = generator.generate_report(sample_host_data)
        
        # Warning anomaly should appear in non-critical section
        assert "Memory usage elevated" in report
        assert "Memory at 67.8%, above 60% threshold" in report
    
    def test_empty_sections_handling(self, mock_config):
        """Test report handles empty sections gracefully"""
        generator = HostReportGenerator(mock_config)
        
        data = {
            'hostname': 'empty-host',
            'timestamp': datetime(2025, 11, 15, 16, 0, 0),
            'metrics': {},
            'anomalies': [],
            'system_changes': {},
            'log_analysis': {},
            'docker_logs': {}
        }
        
        report = generator.generate_report(data)
        
        # Should not crash
        assert isinstance(report, str)
        assert "empty-host" in report
        
        # Should indicate no issues
        assert "No critical issues" in report or len([s for s in report.split('\n') if s.strip()]) > 5
    
    def test_missing_site_and_tags(self, mock_config):
        """Test report generation when site and tags are missing"""
        generator = HostReportGenerator(mock_config)
        
        data = {
            'hostname': 'standalone-host',
            'timestamp': datetime(2025, 11, 15, 16, 0, 0),
            'metrics': {
                'cpu_percent': 20.0,
                'memory_percent': 30.0,
                'disk_percent': 40.0
            }
        }
        
        report = generator.generate_report(data)
        
        # Should handle missing fields gracefully
        assert "standalone-host" in report
        assert "**Site:**" in report or "Site: N/A" in report or "**Site:** None" in report
        assert "**Tags:**" in report or "Tags: None" in report or "No tags" in report
    
    def test_thresholds_from_config_with_site(self, mock_config):
        """Test threshold retrieval with site parameter"""
        mock_config.get_resource_thresholds.return_value = {
            'health': (0, 25),
            'info': (26, 55),
            'warning': (56, 84),
            'critical': (85, 100)
        }
        
        generator = HostReportGenerator(mock_config, site='s01-chicago')
        
        # Should use site-specific thresholds
        assert generator.thresholds['health'] == (0, 25)
        assert generator.thresholds['critical'] == (85, 100)
        
        # Verify config was called with site parameter
        mock_config.get_resource_thresholds.assert_called_with(site='s01-chicago')
    
    def test_large_log_volume_truncation(self, mock_config):
        """Test report handles large log volumes with truncation"""
        generator = HostReportGenerator(mock_config)
        
        # Create data with many log entries
        large_log_data = {
            'hostname': 'busy-host',
            'timestamp': datetime(2025, 11, 15, 16, 0, 0),
            'metrics': {'cpu_percent': 50.0, 'memory_percent': 60.0, 'disk_percent': 70.0},
            'log_analysis': {
                'syslog': [
                    {'timestamp': f'2025-11-15 15:{i:02d}:00', 'severity': 'INFO', 'message': f'Log entry {i}'}
                    for i in range(100)
                ]
            }
        }
        
        report = generator.generate_report(large_log_data)
        
        # Report should be generated without crashing
        assert isinstance(report, str)
        assert "busy-host" in report
        
        # Should have some log entries but not all 100
        # (Implementation should limit to reasonable number)
        log_section_count = report.count('Log entry')
        assert 0 < log_section_count < 100
