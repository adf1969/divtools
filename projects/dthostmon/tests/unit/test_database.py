"""
Unit tests for database models
Last Updated: 11/14/2025 12:00:00 PM CDT
"""

import pytest
from datetime import datetime
from dthostmon.models.database import Host, MonitoringRun, LogEntry, Baseline, DetectedChange


def test_create_host(db_manager):
    """Test creating a host in database"""
    with db_manager.get_session() as session:
        host = Host(
            name='test-host',
            hostname='192.168.1.100',
            port=22,
            user='testuser',
            enabled=True,
            tags=['test'],
            logs_to_monitor=['/var/log/syslog']
        )
        session.add(host)
        session.commit()
        
        # Query back
        retrieved = session.query(Host).filter(Host.name == 'test-host').first()
        assert retrieved is not None
        assert retrieved.hostname == '192.168.1.100'
        assert retrieved.enabled is True


def test_create_monitoring_run(db_manager):
    """Test creating a monitoring run"""
    with db_manager.get_session() as session:
        # Create host first
        host = Host(name='test-host', hostname='192.168.1.100', port=22, user='testuser')
        session.add(host)
        session.flush()
        
        # Create monitoring run
        run = MonitoringRun(
            host_id=host.id,
            status='success',
            execution_time=5.5,
            health_score=95,
            anomalies_detected=0,
            changes_detected=2
        )
        session.add(run)
        session.commit()
        
        # Query back
        retrieved = session.query(MonitoringRun).first()
        assert retrieved is not None
        assert retrieved.status == 'success'
        assert retrieved.health_score == 95


def test_host_monitoring_run_relationship(db_manager):
    """Test relationship between Host and MonitoringRun"""
    with db_manager.get_session() as session:
        # Create host with monitoring runs
        host = Host(name='test-host', hostname='192.168.1.100', port=22, user='testuser')
        session.add(host)
        session.flush()
        
        run1 = MonitoringRun(host_id=host.id, status='success', execution_time=5.0)
        run2 = MonitoringRun(host_id=host.id, status='success', execution_time=6.0)
        session.add_all([run1, run2])
        session.commit()
        
        # Query host and check runs
        retrieved_host = session.query(Host).filter(Host.name == 'test-host').first()
        assert len(retrieved_host.monitoring_runs) == 2


def test_create_baseline(db_manager):
    """Test creating a baseline snapshot"""
    with db_manager.get_session() as session:
        host = Host(name='test-host', hostname='192.168.1.100', port=22, user='testuser')
        session.add(host)
        session.flush()
        
        baseline = Baseline(
            host_id=host.id,
            log_file_path='/var/log/syslog',
            content_hash='abc123',
            line_count=100,
            is_active=True
        )
        session.add(baseline)
        session.commit()
        
        # Query back
        retrieved = session.query(Baseline).first()
        assert retrieved is not None
        assert retrieved.content_hash == 'abc123'
        assert retrieved.is_active is True


def test_create_detected_change(db_manager):
    """Test creating a detected change"""
    with db_manager.get_session() as session:
        host = Host(name='test-host', hostname='192.168.1.100', port=22, user='testuser')
        session.add(host)
        session.flush()
        
        run = MonitoringRun(host_id=host.id, status='success', execution_time=5.0)
        session.add(run)
        session.flush()
        
        change = DetectedChange(
            monitoring_run_id=run.id,
            change_type='config_change',
            severity='WARN',
            description='Configuration file modified',
            log_file_path='/etc/config.conf'
        )
        session.add(change)
        session.commit()
        
        # Query back
        retrieved = session.query(DetectedChange).first()
        assert retrieved is not None
        assert retrieved.change_type == 'config_change'
        assert retrieved.severity == 'WARN'


def test_database_health_check(db_manager):
    """Test database health check"""
    assert db_manager.health_check() is True
