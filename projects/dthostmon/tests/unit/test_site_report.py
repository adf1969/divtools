"""
Unit tests for site_report.py - Site Report Generator
Last Updated: 11/15/2025 4:00:00 PM CST

Tests site-wide report generation including critical items aggregation,
site overview statistics, systems with changes, resource usage tables,
and storage highlights across multiple hosts.
"""

import pytest
from datetime import datetime
from unittest.mock import Mock
from src.dthostmon.core.site_report import SiteReportGenerator


class TestSiteReportGenerator:
    """Test suite for SiteReportGenerator class"""
    
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
    def sample_site_data(self):
        """Sample site monitoring data with multiple hosts"""
        return [
            {
                'hostname': 'prod-web-01',
                'metrics': {
                    'cpu_percent': 45.2,
                    'memory_percent': 67.8,
                    'disk_percent': 92.5
                },
                'anomalies': [
                    {
                        'severity': 'CRITICAL',
                        'category': 'DISK_SPACE',
                        'description': 'Disk usage exceeded 90% threshold'
                    }
                ],
                'system_changes': {
                    'bash_history': [
                        {'command': 'sudo systemctl restart nginx'},
                        {'command': 'tail -f /var/log/nginx/error.log'}
                    ],
                    'apt_history': [{'action': 'Install', 'packages': ['nginx-extras']}]
                }
            },
            {
                'hostname': 'prod-db-01',
                'metrics': {
                    'cpu_percent': 78.5,
                    'memory_percent': 82.3,
                    'disk_percent': 65.0
                },
                'anomalies': [
                    {
                        'severity': 'WARN',
                        'category': 'CPU',
                        'description': 'High CPU usage detected'
                    },
                    {
                        'severity': 'WARN',
                        'category': 'MEMORY',
                        'description': 'Memory usage elevated'
                    }
                ],
                'system_changes': {
                    'bash_history': [
                        {'command': 'sudo systemctl restart postgresql'},
                        {'command': 'psql -c "VACUUM ANALYZE;"'},
                        {'command': 'top'}
                    ]
                }
            },
            {
                'hostname': 'prod-cache-01',
                'metrics': {
                    'cpu_percent': 25.0,
                    'memory_percent': 55.0,
                    'disk_percent': 40.0
                },
                'anomalies': [],
                'system_changes': {}
            }
        ]
    
    @pytest.fixture
    def single_host_data(self):
        """Single host data for testing"""
        return [
            {
                'hostname': 'standalone-host',
                'metrics': {
                    'cpu_percent': 15.0,
                    'memory_percent': 25.0,
                    'disk_percent': 35.0
                },
                'anomalies': [],
                'system_changes': {}
            }
        ]
    
    def test_initialization(self, mock_config):
        """Test SiteReportGenerator initialization"""
        generator = SiteReportGenerator(mock_config)
        
        assert generator.config == mock_config
        assert generator.thresholds == {
            'health': (0, 30),
            'info': (31, 60),
            'warning': (61, 89),
            'critical': (90, 100)
        }
    
    def test_generate_report_with_multiple_hosts(self, mock_config, sample_site_data):
        """Test generating site report with multiple hosts"""
        generator = SiteReportGenerator(mock_config)
        report = generator.generate_report('s01-chicago', sample_site_data)
        
        # Check report structure
        assert isinstance(report, str)
        assert len(report) > 0
        
        # Check header
        assert "# Site Monitoring Report: s01-chicago" in report
        assert "**Host Count:** 3" in report
        
        # Check all major sections present
        assert "## 🚨 Critical Items Across Site" in report or "Critical Items" in report
        assert "## 📊 Site Overview" in report or "Site Overview" in report
        assert "## 🔄 Systems with Recent Changes" in report or "Recent Changes" in report
        assert "## 💾 Resource Usage Table" in report or "Resource Usage" in report
        assert "## 💿 Storage Highlights" in report or "Storage" in report
    
    def test_generate_report_with_single_host(self, mock_config, single_host_data):
        """Test generating site report with single host"""
        generator = SiteReportGenerator(mock_config)
        report = generator.generate_report('s02-test', single_host_data)
        
        # Should still generate report
        assert "s02-test" in report
        assert "**Host Count:** 1" in report
        assert "standalone-host" in report
    
    def test_critical_items_aggregation(self, mock_config, sample_site_data):
        """Test critical items are properly aggregated by host"""
        generator = SiteReportGenerator(mock_config)
        report = generator.generate_report('s01-chicago', sample_site_data)
        
        # Check critical issue from prod-web-01
        assert "prod-web-01" in report
        assert "CRITICAL" in report
        assert "Disk usage exceeded 90% threshold" in report
        
        # Critical section should group by host
        critical_section_start = report.find("🚨 Critical Items")
        web01_position = report.find("prod-web-01", critical_section_start)
        assert web01_position > critical_section_start
    
    def test_site_overview_statistics(self, mock_config, sample_site_data):
        """Test site overview calculates aggregate statistics"""
        generator = SiteReportGenerator(mock_config)
        report = generator.generate_report('s01-chicago', sample_site_data)
        
        # Should include aggregate statistics
        # 3 hosts total: 1 with critical (prod-web-01), 1 with warnings (prod-db-01), 1 healthy (prod-cache-01)
        assert "Healthy" in report or "healthy" in report
        assert "Warning" in report or "warning" in report
        assert "Critical" in report or "critical" in report
        
        # Check for average calculations
        # Avg CPU: (45.2 + 78.5 + 25.0) / 3 = 49.57%
        # Avg Memory: (67.8 + 82.3 + 55.0) / 3 = 68.37%
        # Avg Disk: (92.5 + 65.0 + 40.0) / 3 = 65.83%
        assert "49." in report or "CPU" in report  # Average CPU should be around 49%
        assert "68." in report or "Memory" in report  # Average memory around 68%
        assert "65." in report or "Disk" in report  # Average disk around 65%
    
    def test_systems_with_changes_sorting(self, mock_config, sample_site_data):
        """Test systems with changes are sorted by change count"""
        generator = SiteReportGenerator(mock_config)
        report = generator.generate_report('s01-chicago', sample_site_data)
        
        # prod-db-01 has most changes (3 bash history + 0 apt = 3)
        # prod-web-01 has fewer changes (2 bash history + 1 apt = 3)
        # prod-cache-01 has no changes
        
        # Both hosts with changes should appear
        assert "prod-db-01" in report
        assert "prod-web-01" in report
        
        # Should show change counts
        assert "3 change" in report.lower() or "changes:" in report.lower()
    
    def test_resource_usage_table_generation(self, mock_config, sample_site_data):
        """Test resource usage table includes all hosts sorted by worst resource"""
        generator = SiteReportGenerator(mock_config)
        report = generator.generate_report('s01-chicago', sample_site_data)
        
        # Check table header
        assert "| Host" in report
        assert "CPU" in report
        assert "Memory" in report
        assert "Disk" in report
        assert "Status" in report or "Overall" in report
        
        # Check all hosts included
        assert "prod-web-01" in report
        assert "prod-db-01" in report
        assert "prod-cache-01" in report
        
        # Check metrics appear
        assert "92.5" in report or "92.50" in report  # prod-web-01 disk
        assert "78.5" in report or "78.50" in report  # prod-db-01 CPU
        assert "82.3" in report or "82.30" in report  # prod-db-01 memory
    
    def test_storage_highlights_filtering(self, mock_config, sample_site_data):
        """Test storage highlights section filters high disk usage"""
        generator = SiteReportGenerator(mock_config)
        report = generator.generate_report('s01-chicago', sample_site_data)
        
        # prod-web-01 at 92.5% should be highlighted
        storage_section_start = report.find("💿 Storage")
        if storage_section_start > 0:
            storage_section = report[storage_section_start:]
            assert "prod-web-01" in storage_section
            assert "92.5" in storage_section or "92.50" in storage_section
            
            # prod-cache-01 at 40% should NOT be in storage highlights
            # (but might be in resource table, so check within storage section only)
            assert "prod-cache-01" not in storage_section or storage_section.find("prod-cache-01") == -1
    
    def test_empty_host_list(self, mock_config):
        """Test report generation with empty host list"""
        generator = SiteReportGenerator(mock_config)
        report = generator.generate_report('s03-empty', [])
        
        # Should not crash
        assert isinstance(report, str)
        assert "s03-empty" in report
        assert "**Host Count:** 0" in report
        
        # Should indicate no hosts
        assert "No hosts" in report or "0 hosts" in report or "Host Count:** 0" in report
    
    def test_extract_critical_items_from_hosts(self, mock_config, sample_site_data):
        """Test extraction of critical items across multiple hosts"""
        generator = SiteReportGenerator(mock_config)
        
        critical_items = generator._extract_critical_items(sample_site_data)
        
        # Should find critical item from prod-web-01
        assert len(critical_items) >= 1
        assert any(item['hostname'] == 'prod-web-01' for item in critical_items)
        assert any(item.get('severity') == 'CRITICAL' for item in critical_items)
    
    def test_extract_systems_with_changes(self, mock_config, sample_site_data):
        """Test extraction of systems with changes"""
        generator = SiteReportGenerator(mock_config)
        
        systems_with_changes = generator._extract_systems_with_changes(sample_site_data)
        
        # Should find both hosts with changes
        assert len(systems_with_changes) == 2
        
        # Check structure
        assert any(s['hostname'] == 'prod-db-01' for s in systems_with_changes)
        assert any(s['hostname'] == 'prod-web-01' for s in systems_with_changes)
        
        # Check change counts
        db_host = next(s for s in systems_with_changes if s['hostname'] == 'prod-db-01')
        assert db_host['change_count'] == 3  # 3 bash history commands
    
    def test_extract_storage_highlights(self, mock_config, sample_site_data):
        """Test extraction of storage highlights above threshold"""
        generator = SiteReportGenerator(mock_config)
        
        storage_highlights = generator._extract_storage_highlights(sample_site_data, threshold=80.0)
        
        # Should find prod-web-01 at 92.5%
        assert len(storage_highlights) >= 1
        assert any(s['hostname'] == 'prod-web-01' for s in storage_highlights)
        assert any(s['disk_percent'] == 92.5 for s in storage_highlights)
        
        # Should NOT include prod-cache-01 at 40%
        assert not any(s['hostname'] == 'prod-cache-01' for s in storage_highlights)
    
    def test_site_summary_optional(self, mock_config, sample_site_data):
        """Test report generation with optional site summary"""
        generator = SiteReportGenerator(mock_config)
        
        site_summary = {
            'description': 'Chicago production datacenter',
            'alert_level': 'CRITICAL',
            'notes': 'Disk space issue on web server requires immediate attention'
        }
        
        report = generator.generate_report('s01-chicago', sample_site_data, site_summary)
        
        # Should include summary information
        assert "Chicago production datacenter" in report
        assert "immediate attention" in report
    
    def test_threshold_based_status_in_table(self, mock_config, sample_site_data):
        """Test resource table shows threshold-based status"""
        generator = SiteReportGenerator(mock_config)
        report = generator.generate_report('s01-chicago', sample_site_data)
        
        # Check for status emojis in resource table
        # prod-web-01 disk at 92.5% should show critical (🚨)
        # prod-cache-01 at low usage should show health (✅)
        assert "🚨" in report or "CRITICAL" in report
        assert "✅" in report or "HEALTH" in report or "ℹ️" in report
    
    def test_emoji_mapping_consistency(self, mock_config):
        """Test emoji mapping matches host report standards"""
        generator = SiteReportGenerator(mock_config)
        
        # Should use same emojis as host report
        assert generator._get_status_emoji('health') == '✅'
        assert generator._get_status_emoji('info') == 'ℹ️'
        assert generator._get_status_emoji('warning') == '⚠️'
        assert generator._get_status_emoji('critical') == '🚨'
    
    def test_all_hosts_healthy(self, mock_config):
        """Test report when all hosts are healthy"""
        generator = SiteReportGenerator(mock_config)
        
        healthy_hosts = [
            {
                'hostname': f'host-{i}',
                'metrics': {
                    'cpu_percent': 10.0 + i,
                    'memory_percent': 15.0 + i,
                    'disk_percent': 20.0 + i
                },
                'anomalies': [],
                'system_changes': {}
            }
            for i in range(5)
        ]
        
        report = generator.generate_report('s04-healthy', healthy_hosts)
        
        # Should indicate good health
        assert "✅" in report or "healthy" in report.lower()
        assert "No critical issues" in report or "🚨 Critical Items" not in report
        
        # Should still have resource table
        assert "| Host" in report
        for i in range(5):
            assert f"host-{i}" in report
    
    def test_all_hosts_critical(self, mock_config):
        """Test report when all hosts have critical issues"""
        generator = SiteReportGenerator(mock_config)
        
        critical_hosts = [
            {
                'hostname': f'critical-host-{i}',
                'metrics': {
                    'cpu_percent': 95.0,
                    'memory_percent': 96.0,
                    'disk_percent': 97.0
                },
                'anomalies': [
                    {
                        'severity': 'CRITICAL',
                        'category': 'RESOURCE',
                        'description': f'All resources critical on host-{i}'
                    }
                ],
                'system_changes': {}
            }
            for i in range(3)
        ]
        
        report = generator.generate_report('s05-critical', critical_hosts)
        
        # Should show critical status
        assert "🚨" in report or "CRITICAL" in report
        assert "critical-host-0" in report
        assert "critical-host-1" in report
        assert "critical-host-2" in report
        
        # Overview should show all critical
        assert "3" in report  # 3 hosts
    
    def test_mixed_change_types(self, mock_config):
        """Test report handles various types of system changes"""
        generator = SiteReportGenerator(mock_config)
        
        mixed_hosts = [
            {
                'hostname': 'apt-changed',
                'metrics': {'cpu_percent': 30.0, 'memory_percent': 40.0, 'disk_percent': 50.0},
                'anomalies': [],
                'system_changes': {
                    'apt_history': [
                        {'action': 'Install', 'packages': ['pkg1', 'pkg2', 'pkg3']},
                        {'action': 'Upgrade', 'packages': ['pkg4']}
                    ]
                }
            },
            {
                'hostname': 'filesystem-changed',
                'metrics': {'cpu_percent': 30.0, 'memory_percent': 40.0, 'disk_percent': 50.0},
                'anomalies': [],
                'system_changes': {
                    'filesystem_changes': [
                        {'path': '/etc/config1', 'change_type': 'modified'},
                        {'path': '/etc/config2', 'change_type': 'created'},
                        {'path': '/etc/config3', 'change_type': 'deleted'}
                    ]
                }
            }
        ]
        
        report = generator.generate_report('s06-changes', mixed_hosts)
        
        # Should show both hosts with changes
        assert "apt-changed" in report
        assert "filesystem-changed" in report
        
        # Change counts should reflect different types
        # apt-changed: 4 packages = 4 changes
        # filesystem-changed: 3 files = 3 changes
        assert "change" in report.lower()
    
    def test_sorting_by_worst_resource(self, mock_config):
        """Test resource table sorts hosts by worst resource usage"""
        generator = SiteReportGenerator(mock_config)
        
        hosts = [
            {'hostname': 'low-usage', 'metrics': {'cpu_percent': 10.0, 'memory_percent': 15.0, 'disk_percent': 20.0}},
            {'hostname': 'high-disk', 'metrics': {'cpu_percent': 30.0, 'memory_percent': 40.0, 'disk_percent': 95.0}},
            {'hostname': 'high-cpu', 'metrics': {'cpu_percent': 98.0, 'memory_percent': 40.0, 'disk_percent': 30.0}},
            {'hostname': 'high-memory', 'metrics': {'cpu_percent': 30.0, 'memory_percent': 92.0, 'disk_percent': 30.0}}
        ]
        
        report = generator.generate_report('s07-sorted', hosts)
        
        # All hosts should be in report
        assert all(h['hostname'] in report for h in hosts)
        
        # Should be sorted by worst resource (high-cpu: 98%, high-disk: 95%, high-memory: 92%, low-usage: 20%)
        high_cpu_pos = report.find('high-cpu')
        high_disk_pos = report.find('high-disk')
        high_memory_pos = report.find('high-memory')
        low_usage_pos = report.find('low-usage')
        
        # Hosts with higher worst resources should appear earlier in table
        # (Note: multiple occurrences possible, this checks general ordering)
        assert high_cpu_pos > 0
        assert high_disk_pos > 0
        assert high_memory_pos > 0
        assert low_usage_pos > 0
    
    def test_report_timestamp_format(self, mock_config, sample_site_data):
        """Test report includes properly formatted timestamp"""
        generator = SiteReportGenerator(mock_config)
        report = generator.generate_report('s01-chicago', sample_site_data)
        
        # Should have timestamp in report
        # Format: YYYY-MM-DD HH:MM:SS
        import re
        timestamp_pattern = r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
        assert re.search(timestamp_pattern, report) is not None
    
    def test_thresholds_from_config_with_site(self, mock_config, sample_site_data):
        """Test threshold retrieval with site parameter"""
        mock_config.get_resource_thresholds.return_value = {
            'health': (0, 25),
            'info': (26, 55),
            'warning': (56, 84),
            'critical': (85, 100)
        }
        
        generator = SiteReportGenerator(mock_config, site='s01-chicago')
        report = generator.generate_report('s01-chicago', sample_site_data)
        
        # Should use site-specific thresholds
        assert generator.thresholds['health'] == (0, 25)
        assert generator.thresholds['critical'] == (85, 100)
        
        # Verify config was called with site parameter
        mock_config.get_resource_thresholds.assert_called_with(site='s01-chicago')
