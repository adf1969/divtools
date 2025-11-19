"""
Database models for dthostmon
Last Updated: 11/14/2025 12:00:00 PM CDT

SQLAlchemy models for storing host information, monitoring results, and analysis history.
"""

from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, JSON, ForeignKey, Float
from sqlalchemy.orm import declarative_base, relationship

Base = declarative_base()


class Host(Base):
    """Monitored host configuration and metadata"""
    __tablename__ = 'hosts'
    
    id = Column(Integer, primary_key=True)
    name = Column(String(255), unique=True, nullable=False, index=True)
    hostname = Column(String(255), nullable=False)
    port = Column(Integer, default=22)
    user = Column(String(100), nullable=False)
    enabled = Column(Boolean, default=True)
    site = Column(String(100), nullable=True, index=True)  # Site identifier (e.g., s01-chicago)
    tags = Column(JSON)  # List of tags
    logs_to_monitor = Column(JSON)  # List of log file paths
    report_frequency = Column(String(50), nullable=True)  # Overrides global/site frequency
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_seen = Column(DateTime, nullable=True)
    last_report_sent = Column(DateTime, nullable=True)  # Timestamp of last report sent
    
    # Relationships
    monitoring_runs = relationship("MonitoringRun", back_populates="host", cascade="all, delete-orphan")
    baselines = relationship("Baseline", back_populates="host", cascade="all, delete-orphan")


class MonitoringRun(Base):
    """Individual monitoring execution results"""
    __tablename__ = 'monitoring_runs'
    
    id = Column(Integer, primary_key=True)
    host_id = Column(Integer, ForeignKey('hosts.id'), nullable=False, index=True)
    run_date = Column(DateTime, default=datetime.utcnow, index=True)
    status = Column(String(50))  # success, failed, partial
    execution_time = Column(Float)  # seconds
    error_message = Column(Text, nullable=True)
    
    # Analysis results
    health_score = Column(Integer, nullable=True)  # 0-100
    anomalies_detected = Column(Integer, default=0)
    changes_detected = Column(Integer, default=0)
    ai_summary = Column(Text, nullable=True)
    ai_recommendations = Column(Text, nullable=True)
    
    # Alert tracking
    alert_sent = Column(Boolean, default=False)
    alert_level = Column(String(20))  # INFO, WARN, CRITICAL
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    host = relationship("Host", back_populates="monitoring_runs")
    log_entries = relationship("LogEntry", back_populates="monitoring_run", cascade="all, delete-orphan")
    detected_changes = relationship("DetectedChange", back_populates="monitoring_run", cascade="all, delete-orphan")


class LogEntry(Base):
    """Captured log file contents from monitored hosts"""
    __tablename__ = 'log_entries'
    
    id = Column(Integer, primary_key=True)
    monitoring_run_id = Column(Integer, ForeignKey('monitoring_runs.id'), nullable=False, index=True)
    log_file_path = Column(String(500), nullable=False)
    content = Column(Text)
    content_hash = Column(String(64))  # SHA256 hash for change detection
    line_count = Column(Integer)
    file_size = Column(Integer)  # bytes
    retrieved_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    monitoring_run = relationship("MonitoringRun", back_populates="log_entries")


class Baseline(Base):
    """Baseline snapshots for comparison"""
    __tablename__ = 'baselines'
    
    id = Column(Integer, primary_key=True)
    host_id = Column(Integer, ForeignKey('hosts.id'), nullable=False, index=True)
    log_file_path = Column(String(500), nullable=False)
    content_hash = Column(String(64), nullable=False)
    line_count = Column(Integer)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    is_active = Column(Boolean, default=True)  # Most recent baseline is active
    
    # Relationships
    host = relationship("Host", back_populates="baselines")


class DetectedChange(Base):
    """Changes detected between monitoring runs"""
    __tablename__ = 'detected_changes'
    
    id = Column(Integer, primary_key=True)
    monitoring_run_id = Column(Integer, ForeignKey('monitoring_runs.id'), nullable=False, index=True)
    change_type = Column(String(50))  # new_user, failed_login, config_change, service_change
    severity = Column(String(20))  # INFO, WARN, CRITICAL
    description = Column(Text)
    log_file_path = Column(String(500))
    detected_at = Column(DateTime, default=datetime.utcnow)
    ai_analysis = Column(Text, nullable=True)
    
    # Relationships
    monitoring_run = relationship("MonitoringRun", back_populates="detected_changes")


class SystemMetric(Base):
    """System metrics captured during monitoring"""
    __tablename__ = 'system_metrics'
    
    id = Column(Integer, primary_key=True)
    host_id = Column(Integer, ForeignKey('hosts.id'), nullable=False, index=True)
    collected_at = Column(DateTime, default=datetime.utcnow, index=True)
    
    # CPU metrics
    cpu_percent = Column(Float)
    cpu_load_1min = Column(Float)
    cpu_load_5min = Column(Float)
    cpu_load_15min = Column(Float)
    
    # Memory metrics
    memory_percent = Column(Float)
    memory_used_mb = Column(Integer)
    memory_total_mb = Column(Integer)
    
    # Disk metrics
    disk_percent = Column(Float)
    disk_used_gb = Column(Float)
    disk_total_gb = Column(Float)
    
    # Network metrics (optional for Phase 3)
    network_bytes_sent = Column(Integer, nullable=True)
    network_bytes_recv = Column(Integer, nullable=True)
