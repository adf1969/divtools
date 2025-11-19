"""
Main monitoring orchestrator for dthostmon
Last Updated: 11/14/2025 12:00:00 PM CDT

Coordinates monitoring runs across multiple hosts with SSH, AI analysis, and alerting.
"""

import logging
import time
from datetime import datetime
from typing import List, Dict, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

from ..models.database import Host, MonitoringRun, LogEntry, Baseline, DetectedChange
from ..models import DatabaseManager
from ..core.ssh_client import SSHClient, SSHConnectionError, LogRetrievalError
from ..core.ai_analyzer import AIAnalyzer
from ..core.email_alert import EmailAlert
from ..core.pushover_alert import PushoverAlert
from ..core.report_scheduler import ReportScheduler
from ..utils.config import Config

logger = logging.getLogger(__name__)


class MonitoringOrchestrator:
    """Orchestrates monitoring runs for all configured hosts"""
    
    def __init__(self, config: Config, db_manager: DatabaseManager):
        """
        Initialize monitoring orchestrator
        
        Args:
            config: Configuration object
            db_manager: Database manager
        """
        self.config = config
        self.db_manager = db_manager
        
        # Initialize AI analyzer
        ai_config = config.get('ai', {})
        self.ai_analyzer = AIAnalyzer(ai_config)
        
        # Initialize email alerter
        email_config = config.get('email', {})
        self.email_alert = EmailAlert(
            smtp_host=email_config.get('smtp_host'),
            smtp_port=email_config.get('smtp_port'),
            smtp_auth_user=email_config.get('smtp_auth_user'),
            smtp_auth_password=email_config.get('smtp_auth_password'),
            from_address=email_config.get('from_address'),
            reply_to_address=email_config.get('reply_to_address'),
            use_tls=config._to_bool(email_config.get('use_tls', True)),
            smtp_auth_required=config._to_bool(email_config.get('smtp_auth_required', True))
        )
        self.alert_recipients = email_config.get('alert_recipients', [])
        
        # Initialize Pushover alerts
        pushover_config = config.get('pushover', {})
        self.pushover_alert = PushoverAlert(
            api_token=pushover_config.get('api_token', ''),
            user_key=pushover_config.get('user_key', ''),
            enabled=config._to_bool(pushover_config.get('enabled', False))
        )
        
        # Initialize report scheduler
        self.report_scheduler = ReportScheduler(config, db_manager, self.email_alert)
        
        # Configuration
        self.max_concurrent = config.get('global.max_concurrent_hosts', 5)
        self.ssh_key_path = config.get('ssh.key_path')
        self.ssh_timeout = config.get('ssh.timeout', 10)
        
        logger.info("Monitoring orchestrator initialized")
    
    def run_monitoring_cycle(self):
        """Execute monitoring cycle for all enabled hosts"""
        logger.info("=" * 70)
        logger.info("Starting monitoring cycle")
        cycle_start = time.time()
        
        # Sync hosts from config to database
        self._sync_hosts()
        
        # Get enabled hosts from database
        with self.db_manager.get_session() as session:
            hosts = session.query(Host).filter(Host.enabled == True).all()
            host_data = [
                {
                    'id': h.id,
                    'name': h.name,
                    'hostname': h.hostname,
                    'port': h.port,
                    'user': h.user,
                    'logs': h.logs_to_monitor,
                    'tags': h.tags
                }
                for h in hosts
            ]
        
        if not host_data:
            logger.warning("No enabled hosts found in configuration")
            return
        
        logger.info(f"Monitoring {len(host_data)} hosts with max {self.max_concurrent} concurrent connections")
        
        # Process hosts concurrently
        results = []
        with ThreadPoolExecutor(max_workers=self.max_concurrent) as executor:
            future_to_host = {
                executor.submit(self._monitor_single_host, host): host 
                for host in host_data
            }
            
            for future in as_completed(future_to_host):
                host = future_to_host[future]
                try:
                    result = future.result()
                    results.append(result)
                    logger.info(f"✓ Completed monitoring for {host['name']}")
                except Exception as e:
                    logger.error(f"✗ Failed monitoring for {host['name']}: {e}")
                    results.append({'host': host, 'status': 'failed', 'error': str(e)})
        
        cycle_time = time.time() - cycle_start
        successful = sum(1 for r in results if r.get('status') == 'success')
        failed = len(results) - successful
        
        logger.info(f"Monitoring cycle completed in {cycle_time:.2f}s: "
                   f"{successful} successful, {failed} failed")
        logger.info("=" * 70)
    
    def _monitor_single_host(self, host: Dict) -> Dict:
        """
        Monitor a single host
        
        Args:
            host: Host configuration dictionary
        
        Returns:
            Dictionary with monitoring results
        """
        start_time = time.time()
        host_id = host['id']
        host_name = host['name']
        
        logger.info(f"Starting monitoring for {host_name} ({host['hostname']})")
        
        try:
            # Connect via SSH and retrieve logs
            ssh_client = SSHClient(
                hostname=host['hostname'],
                port=host['port'],
                username=host['user'],
                key_path=self.ssh_key_path,
                timeout=self.ssh_timeout
            )
            
            with ssh_client:
                # Retrieve logs
                logs = ssh_client.retrieve_multiple_logs(host['logs'])
                logger.debug(f"Retrieved {len(logs)} log files from {host_name}")
            
            # Get baseline for comparison
            with self.db_manager.get_session() as session:
                baseline = (
                    session.query(Baseline)
                    .filter(Baseline.host_id == host_id, Baseline.is_active == True)
                    .first()
                )
            
            # AI analysis
            logger.debug(f"Running AI analysis for {host_name}")
            analysis = self.ai_analyzer.analyze_logs(
                host_info=host,
                logs=logs,
                baseline={'content_hash': baseline.content_hash} if baseline else None
            )
            
            # Detect changes
            changes = self._detect_changes(logs, host_id)
            
            # Save results to database
            execution_time = time.time() - start_time
            run_id = self._save_monitoring_run(
                host_id=host_id,
                status='success',
                execution_time=execution_time,
                analysis=analysis,
                logs=logs,
                changes=changes
            )
            
            # Update baseline
            self._update_baselines(host_id, logs)
            
            # Update last_seen
            with self.db_manager.get_session() as session:
                host_obj = session.query(Host).filter(Host.id == host_id).first()
                host_obj.last_seen = datetime.utcnow()
            
            # Send alert if warranted
            if analysis.get('severity') in ['WARN', 'CRITICAL']:
                logger.info(f"Sending alert for {host_name} (severity: {analysis['severity']})")
                self._send_alert(host, run_id, analysis, changes)
                
                # Send Pushover alert for critical issues
                try:
                    with self.db_manager.get_session() as session:
                        run = session.query(MonitoringRun).filter(MonitoringRun.id == run_id).first()
                        if run:
                            monitoring_data = {
                                'alert_level': run.alert_level,
                                'health_score': run.health_score,
                                'anomalies_detected': run.anomalies_detected,
                                'changes_detected': run.changes_detected,
                                'ai_summary': run.ai_summary
                            }
                            self.pushover_alert.send_monitoring_alert(monitoring_data, host)
                except Exception as e:
                    logger.error(f"Failed to send Pushover alert: {e}")
            
            # Send report if due based on frequency configuration
            monitoring_data = {
                'run_date': datetime.utcnow(),
                'status': 'success',
                'health_score': analysis['health_score'],
                'anomalies_detected': analysis.get('anomalies_detected', 0),
                'changes_detected': len(changes)
            }
            ai_analysis = {
                'summary': analysis.get('summary'),
                'recommendations': analysis.get('recommendations'),
                'alert_level': analysis.get('severity', 'INFO')
            }
            self.report_scheduler.send_host_report(host_id, monitoring_data, ai_analysis)
            
            logger.info(f"Monitoring successful for {host_name}: "
                       f"Health={analysis['health_score']}/100, "
                       f"Changes={len(changes)}, "
                       f"Time={execution_time:.2f}s")
            
            return {
                'host': host,
                'status': 'success',
                'run_id': run_id,
                'health_score': analysis['health_score'],
                'execution_time': execution_time
            }
            
        except (SSHConnectionError, LogRetrievalError) as e:
            logger.error(f"Connection/retrieval error for {host_name}: {e}")
            execution_time = time.time() - start_time
            run_id = self._save_monitoring_run(
                host_id=host_id,
                status='failed',
                execution_time=execution_time,
                error_message=str(e)
            )
            return {
                'host': host,
                'status': 'failed',
                'error': str(e),
                'run_id': run_id
            }
            
        except Exception as e:
            logger.exception(f"Unexpected error monitoring {host_name}")
            execution_time = time.time() - start_time
            run_id = self._save_monitoring_run(
                host_id=host_id,
                status='failed',
                execution_time=execution_time,
                error_message=f"Unexpected error: {e}"
            )
            return {
                'host': host,
                'status': 'failed',
                'error': f"Unexpected: {e}",
                'run_id': run_id
            }
    
    def _detect_changes(self, logs: List[Dict], host_id: int) -> List[Dict]:
        """
        Detect changes by comparing with previous baselines
        
        Args:
            logs: Current log entries
            host_id: Host ID
        
        Returns:
            List of detected changes
        """
        changes = []
        
        with self.db_manager.get_session() as session:
            for log in logs:
                if not log.get('content'):
                    continue
                
                # Get previous baseline
                baseline = (
                    session.query(Baseline)
                    .filter(
                        Baseline.host_id == host_id,
                        Baseline.log_file_path == log['path'],
                        Baseline.is_active == True
                    )
                    .first()
                )
                
                if baseline:
                    # Compare hashes
                    if log['hash'] != baseline.content_hash:
                        changes.append({
                            'change_type': 'log_modified',
                            'severity': 'INFO',
                            'description': f"Log file {log['path']} has changed "
                                         f"({log['line_count']} lines, {log['file_size']} bytes)",
                            'log_file_path': log['path']
                        })
                else:
                    # New log file
                    changes.append({
                        'change_type': 'new_log',
                        'severity': 'INFO',
                        'description': f"New log file detected: {log['path']}",
                        'log_file_path': log['path']
                    })
        
        return changes
    
    def _save_monitoring_run(self, host_id: int, status: str, execution_time: float,
                            analysis: Optional[Dict] = None, logs: Optional[List[Dict]] = None,
                            changes: Optional[List[Dict]] = None, 
                            error_message: Optional[str] = None) -> int:
        """Save monitoring run to database"""
        with self.db_manager.get_session() as session:
            # Create monitoring run
            run = MonitoringRun(
                host_id=host_id,
                run_date=datetime.utcnow(),
                status=status,
                execution_time=execution_time,
                error_message=error_message,
                health_score=analysis.get('health_score') if analysis else None,
                anomalies_detected=len(analysis.get('anomalies', [])) if analysis else 0,
                changes_detected=len(changes) if changes else 0,
                ai_summary=analysis.get('summary') if analysis else None,
                ai_recommendations=analysis.get('recommendations') if analysis else None,
                alert_level=analysis.get('severity', 'INFO') if analysis else 'INFO'
            )
            session.add(run)
            session.flush()  # Get run.id
            
            # Save log entries
            if logs:
                for log in logs:
                    if log.get('content'):
                        log_entry = LogEntry(
                            monitoring_run_id=run.id,
                            log_file_path=log['path'],
                            content=log['content'],
                            content_hash=log['hash'],
                            line_count=log['line_count'],
                            file_size=log['file_size'],
                            retrieved_at=log['retrieved_at']
                        )
                        session.add(log_entry)
            
            # Save detected changes
            if changes:
                for change in changes:
                    detected_change = DetectedChange(
                        monitoring_run_id=run.id,
                        change_type=change['change_type'],
                        severity=change['severity'],
                        description=change['description'],
                        log_file_path=change.get('log_file_path')
                    )
                    session.add(detected_change)
            
            session.commit()
            return run.id
    
    def _update_baselines(self, host_id: int, logs: List[Dict]):
        """Update baseline snapshots for logs"""
        with self.db_manager.get_session() as session:
            for log in logs:
                if not log.get('content'):
                    continue
                
                # Deactivate old baselines
                session.query(Baseline).filter(
                    Baseline.host_id == host_id,
                    Baseline.log_file_path == log['path']
                ).update({'is_active': False})
                
                # Create new baseline
                baseline = Baseline(
                    host_id=host_id,
                    log_file_path=log['path'],
                    content_hash=log['hash'],
                    line_count=log['line_count'],
                    is_active=True
                )
                session.add(baseline)
    
    def _send_alert(self, host: Dict, run_id: int, analysis: Dict, changes: List[Dict]):
        """Send email alert"""
        try:
            with self.db_manager.get_session() as session:
                run = session.query(MonitoringRun).filter(MonitoringRun.id == run_id).first()
                
                monitoring_data = {
                    'id': run.id,
                    'run_date': run.run_date,
                    'health_score': run.health_score,
                    'anomalies_detected': run.anomalies_detected,
                    'changes_detected': run.changes_detected,
                    'ai_summary': run.ai_summary,
                    'ai_recommendations': run.ai_recommendations,
                    'alert_level': run.alert_level,
                    'execution_time': run.execution_time,
                    'log_entries': []
                }
                
                change_data = [
                    {
                        'change_type': c['change_type'],
                        'severity': c['severity'],
                        'description': c['description'],
                        'log_file_path': c.get('log_file_path')
                    }
                    for c in changes
                ]
                
                self.email_alert.send_monitoring_alert(
                    recipients=self.alert_recipients,
                    monitoring_run=monitoring_data,
                    changes=change_data,
                    host_info=host
                )
                
                # Mark alert as sent
                run.alert_sent = True
                session.commit()
                
        except Exception as e:
            logger.error(f"Failed to send alert: {e}")
    
    def _sync_hosts(self):
        """Sync hosts from configuration to database"""
        config_hosts = self.config.hosts
        
        with self.db_manager.get_session() as session:
            for config_host in config_hosts:
                # Check if host exists
                existing = session.query(Host).filter(Host.name == config_host['name']).first()
                
                if existing:
                    # Update existing host
                    existing.hostname = config_host['hostname']
                    existing.port = config_host.get('port', 22)
                    existing.user = config_host['user']
                    existing.enabled = config_host.get('enabled', True)
                    existing.tags = config_host.get('tags', [])
                    existing.logs_to_monitor = config_host.get('logs', [])
                    existing.updated_at = datetime.utcnow()
                else:
                    # Create new host
                    new_host = Host(
                        name=config_host['name'],
                        hostname=config_host['hostname'],
                        port=config_host.get('port', 22),
                        user=config_host['user'],
                        enabled=config_host.get('enabled', True),
                        tags=config_host.get('tags', []),
                        logs_to_monitor=config_host.get('logs', [])
                    )
                    session.add(new_host)
            
            session.commit()
