"""
Unit tests for report generators
Last Updated: 11/16/2025 12:00:00 PM CDT

Tests for HostReportGenerator and SiteReportGenerator.
"""

import pytest
from datetime import datetime, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from unittest.mock import Mock, patch

from dthostmon.models.database import Base, Host, MonitoringRun, LogEntry, SystemMetric, DetectedChange
from dthostmon.reports.host_report import HostReportGenerator
from dthostmon.reports.site_report import SiteReportGenerator


@pytest.fixture
def db_session():
    """Create an in-memory SQLite database for testing"""
    engine = create_engine('sqlite:///:memory:')
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


@pytest.fixture
def sample_host(db_session):
    """Create a sample host for testing"""
    host = Host(
        name='test-host-01',
        hostname='192.168.1.100',
        port=22,
        user='monitoring',
        enabled=True,
        site='s01-test',
        tags=['production', 'database'],
        logs_to_monitor=['/var/log/syslog', '/var/log/auth.log']
    )
    db_session.add(host)
    db_session.commit()
    return host


@pytest.fixture
def sample_monitoring_run(db_session, sample_host):
    """Create a sample monitoring run"""
    run = MonitoringRun(
        host_id=sample_host.id,
        run_date=datetime.utcnow(),
        status='success',
        execution_time=45.2,
        health_score=85,
        anomalies_detected=2,
        changes_detected=5,
        ai_summary='System is generally healthy with minor issues.',
        ai_recommendations='Review authentication logs for failed login attempts.',
        alert_sent=False,
        alert_level='INFO'
    )
    db_session.add(run)
    db_session.commit()
    return run


@pytest.fixture
def sample_log_entries(db_session, sample_monitoring_run):
    """Create sample log entries"""
    entries = [
        LogEntry(
            monitoring_run_id=sample_monitoring_run.id,
            log_file_path='/var/log/syslog',
            content='2025-11-16 12:00:00 kernel: [12345.67] test message',
            content_hash='abc123',
            line_count=100,
            file_size=5120,
            retrieved_at=datetime.utcnow()
        ),
        LogEntry(
            monitoring_run_id=sample_monitoring_run.id,
            log_file_path='/root/.bash_history',
            content='2025-11-16 12:00:00 apt update\n2025-11-16 12:01:00 systemctl restart nginx',
            content_hash='def456',
            line_count=50,
            file_size=2048,
            retrieved_at=datetime.utcnow()
        ),
        LogEntry(
            monitoring_run_id=sample_monitoring_run.id,
            log_file_path='/var/log/apt/history.log',
            content='Start-Date: 2025-11-16  12:00:00\nCommandline: apt install nginx\n',
            content_hash='ghi789',
            line_count=20,
            file_size=1024,
            retrieved_at=datetime.utcnow()
        )
    ]
    db_session.add_all(entries)
    db_session.commit()
    return entries


@pytest.fixture
def sample_system_metrics(db_session, sample_host):
    """Create sample system metrics"""
    metrics = SystemMetric(
        host_id=sample_host.id,
        collected_at=datetime.utcnow(),
        cpu_percent=45.2,
        cpu_load_1min=1.5,
        cpu_load_5min=1.2,
        cpu_load_15min=1.0,
        memory_percent=62.5,
        memory_used_mb=5000,
        memory_total_mb=8000,
        disk_percent=75.8,
        disk_used_gb=150.5,
        disk_total_gb=200.0
    )
    db_session.add(metrics)
    db_session.commit()
    return metrics


@pytest.fixture
def sample_detected_changes(db_session, sample_monitoring_run):
    """Create sample detected changes"""
    changes = [
        DetectedChange(
            monitoring_run_id=sample_monitoring_run.id,
            change_type='failed_login',
            severity='CRITICAL',
            description='Multiple failed login attempts from unknown IP',
            log_file_path='/var/log/auth.log',
            detected_at=datetime.utcnow(),
            ai_analysis='Potential brute force attack detected'
        ),
        DetectedChange(
            monitoring_run_id=sample_monitoring_run.id,
            change_type='package_install',
            severity='INFO',
            description='Package nginx installed',
            log_file_path='/var/log/apt/history.log',
            detected_at=datetime.utcnow(),
            ai_analysis='Standard package installation'
        ),
        DetectedChange(
            monitoring_run_id=sample_monitoring_run.id,
            change_type='config_change',
            severity='WARN',
            description='SSH configuration file modified',
            log_file_path='/etc/ssh/sshd_config',
            detected_at=datetime.utcnow(),
            ai_analysis='Configuration change requires verification'
        )
    ]
    db_session.add_all(changes)
    db_session.commit()
    return changes


class TestHostReportGenerator:
    """Tests for HostReportGenerator"""
    
    def test_generator_initialization(self, db_session):
        """Test that generator initializes correctly"""
        generator = HostReportGenerator(db_session)
        assert generator.session == db_session
    
    def test_generate_report_with_data(
        self,
        db_session,
        sample_host,
        sample_monitoring_run,
        sample_log_entries,
        sample_system_metrics,
        sample_detected_changes
    ):
        """Test report generation with complete data"""
        generator = HostReportGenerator(db_session)
        report = generator.generate_report(sample_host.id)
        
        # Verify report structure
        assert '# Host Status Report: test-host-01' in report
        assert 'Site:** s01-test' in report
        assert 'Tags:** production, database' in report
        assert 'Health Score:** 85/100' in report
        
        # Verify sections exist
        assert '## Executive Summary' in report
        assert '## System Health' in report
        assert '## Changes Detected' in report
        assert '## Command History' in report
        assert '## Package Installation Logs' in report
        
        # Verify critical issues highlighted
        assert 'CRITICAL' in report
        assert 'Multiple failed login attempts' in report
        
        # Verify metrics included
        assert '45.2%' in report  # CPU
        assert '62.5%' in report  # Memory
        assert '75.8%' in report  # Disk
    
    def test_generate_report_no_data(self, db_session):
        """Test report generation when host has no data"""
        generator = HostReportGenerator(db_session)
        report = generator.generate_report(999)  # Non-existent host
        
        assert '# Host Status Report: Host ID 999' in report
        assert 'No monitoring data available' in report
    
    def test_critical_issues_section(
        self,
        db_session,
        sample_host,
        sample_monitoring_run,
        sample_detected_changes
    ):
        """Test that critical issues are properly highlighted"""
        generator = HostReportGenerator(db_session)
        report = generator.generate_report(sample_host.id)
        
        # Should have critical issues section with the failed login
        assert '## 🚨 CRITICAL ISSUES' in report
        assert 'failed_login' in report.lower()
        assert 'Multiple failed login attempts' in report
    
    def test_non_critical_section(
        self,
        db_session,
        sample_host,
        sample_monitoring_run,
        sample_detected_changes
    ):
        """Test that non-critical issues appear in separate section"""
        generator = HostReportGenerator(db_session)
        report = generator.generate_report(sample_host.id)
        
        # Should have non-critical section with INFO and WARN items
        assert '## Non-Critical Items' in report
        assert 'package_install' in report.lower() or 'Package nginx installed' in report
        assert 'config_change' in report.lower() or 'SSH configuration' in report


class TestSiteReportGenerator:
    """Tests for SiteReportGenerator"""
    
    def test_generator_initialization(self, db_session):
        """Test that generator initializes correctly"""
        generator = SiteReportGenerator(db_session)
        assert generator.session == db_session
        assert generator.thresholds == SiteReportGenerator.DEFAULT_THRESHOLDS
    
    def test_generator_with_custom_thresholds(self, db_session):
        """Test initialization with custom thresholds"""
        custom_thresholds = {
            'health': '0-25',
            'warning': '56-84',
            'critical': '85-100'
        }
        generator = SiteReportGenerator(db_session, custom_thresholds)
        
        assert generator.thresholds['health'] == (0, 25)
        assert generator.thresholds['warning'] == (56, 84)
        assert generator.thresholds['critical'] == (85, 100)
    
    def test_generate_site_report_with_data(
        self,
        db_session,
        sample_host,
        sample_monitoring_run,
        sample_system_metrics,
        sample_detected_changes
    ):
        """Test site report generation with data"""
        generator = SiteReportGenerator(db_session)
        report = generator.generate_report('s01-test')
        
        # Verify report structure
        assert '# Site Status Report: s01-test' in report
        assert 'Hosts Monitored:** 1' in report
        
        # Verify sections exist
        assert '## Executive Summary' in report
        assert '## Host Resource Usage' in report
        
        # Verify threshold legend
        assert '**Threshold Legend:**' in report
        assert '🟢 Health:' in report
        assert '🔴 Critical:' in report
    
    def test_generate_site_report_no_data(self, db_session):
        """Test site report when no hosts exist for site"""
        generator = SiteReportGenerator(db_session)
        report = generator.generate_report('nonexistent-site')
        
        assert '# Site Status Report: nonexistent-site' in report
        assert 'No hosts found' in report
    
    def test_resource_usage_table(
        self,
        db_session,
        sample_host,
        sample_monitoring_run,
        sample_system_metrics,
        sample_detected_changes
    ):
        """Test that resource usage table is generated correctly"""
        generator = SiteReportGenerator(db_session)
        report = generator.generate_report('s01-test')
        
        # Verify table structure
        assert '| Host | CPU | Memory | Disk | Health Score | Issues |' in report
        assert '| test-host-01' in report
        
        # Verify emoji indicators
        assert '🔵' in report or '🟡' in report  # CPU/Memory should be in info/warning range
        assert '🟡' in report  # Disk at 75.8% should be in warning range
    
    def test_critical_items_section(
        self,
        db_session,
        sample_host,
        sample_monitoring_run,
        sample_detected_changes
    ):
        """Test that critical items are highlighted in site report"""
        generator = SiteReportGenerator(db_session)
        report = generator.generate_report('s01-test')
        
        # Should show critical issues
        assert 'CRITICAL ITEMS' in report or '🚨' in report
        assert 'failed_login' in report.lower() or 'Multiple failed login' in report
    
    def test_status_emoji_levels(self, db_session):
        """Test status emoji and level assignment based on thresholds"""
        generator = SiteReportGenerator(db_session)
        
        # Test with default thresholds
        emoji, level = generator._get_status_emoji_and_level(25.0)
        assert emoji == "🟢"
        assert level == "Health"
        
        emoji, level = generator._get_status_emoji_and_level(45.0)
        assert emoji == "🔵"
        assert level == "Info"
        
        emoji, level = generator._get_status_emoji_and_level(70.0)
        assert emoji == "🟡"
        assert level == "Warning"
        
        emoji, level = generator._get_status_emoji_and_level(95.0)
        assert emoji == "🔴"
        assert level == "Critical"
    
    def test_threshold_parsing(self, db_session):
        """Test threshold configuration parsing"""
        generator = SiteReportGenerator(db_session)
        
        # Test valid threshold strings
        thresholds = generator._parse_thresholds({
            'health': '0-20',
            'critical': '95-100'
        })
        
        assert thresholds['health'] == (0, 20)
        assert thresholds['critical'] == (95, 100)
        
        # Test invalid threshold (should use default)
        thresholds = generator._parse_thresholds({
            'invalid': 'not-a-range'
        })
        
        assert thresholds['health'] == (0, 30)  # Default


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
