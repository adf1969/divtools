"""
Report Scheduler for dthostmon
Last Updated: 1/16/2025 12:00:00 PM CST

Handles scheduling and sending of Host and Site reports via email based on
configured frequencies (Global > Site > Host hierarchy).
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from sqlalchemy.orm import Session

from ..models.database import Host, MonitoringRun
from ..models import DatabaseManager
from ..core.host_report import HostReportGenerator
from ..core.site_report import SiteReportGenerator
from ..core.email_alert import EmailAlert
from ..utils.config import Config

logger = logging.getLogger(__name__)


class ReportScheduler:
    """Schedules and sends Host and Site reports based on configured frequencies"""
    
    def __init__(self, config: Config, db_manager: DatabaseManager, email_alert: EmailAlert):
        """
        Initialize report scheduler
        
        Args:
            config: Configuration object
            db_manager: Database manager
            email_alert: Email alert sender
        """
        self.config = config
        self.db_manager = db_manager
        self.email_alert = email_alert
        
        # Get report recipients from config
        email_config = config.get('email', {})
        self.report_recipients = email_config.get('report_recipients', 
                                                   email_config.get('alert_recipients', []))
        
        logger.info("Report scheduler initialized")
    
    def should_send_report(self, host_config: Dict[str, Any], 
                          last_report_sent: Optional[datetime]) -> bool:
        """
        Determine if a report should be sent based on frequency and last sent time.
        
        Args:
            host_config: Host configuration dictionary
            last_report_sent: Timestamp of when report was last sent (None if never sent)
        
        Returns:
            True if report should be sent
        """
        # Get effective frequency using hierarchical override logic
        frequency = self.config.get_host_report_frequency(host_config)
        
        # If never sent, send it now
        if last_report_sent is None:
            logger.debug(f"Host {host_config['name']} - never sent report, sending now")
            return True
        
        # Calculate time since last report
        time_since_last = datetime.utcnow() - last_report_sent
        
        # Check against frequency thresholds
        if frequency == 'hourly':
            threshold = timedelta(hours=1)
        elif frequency == 'daily':
            threshold = timedelta(days=1)
        elif frequency == 'weekly':
            threshold = timedelta(weeks=1)
        elif frequency == 'monthly':
            threshold = timedelta(days=30)
        else:
            logger.warning(f"Unknown frequency '{frequency}' for host {host_config['name']}, defaulting to daily")
            threshold = timedelta(days=1)
        
        should_send = time_since_last >= threshold
        logger.debug(f"Host {host_config['name']} - frequency={frequency}, "
                    f"last_sent={last_report_sent}, time_since={time_since_last}, "
                    f"threshold={threshold}, should_send={should_send}")
        
        return should_send
    
    def send_host_report(self, host_id: int, monitoring_data: Dict[str, Any], 
                        ai_analysis: Optional[Dict[str, Any]] = None) -> bool:
        """
        Generate and send host report via email.
        
        Args:
            host_id: Host ID from database
            monitoring_data: Monitoring data collected for the host
            ai_analysis: Optional AI analysis results
        
        Returns:
            True if report sent successfully
        """
        try:
            with self.db_manager.get_session() as session:
                # Get host from database
                host = session.query(Host).filter(Host.id == host_id).first()
                if not host:
                    logger.error(f"Host ID {host_id} not found in database")
                    return False
                
                # Check if report should be sent
                host_config = {
                    'name': host.name,
                    'site': host.site,
                    'report_frequency': host.report_frequency
                }
                
                if not self.should_send_report(host_config, host.last_report_sent):
                    logger.info(f"Skipping report for {host.name} - not due yet")
                    return False
                
                # Get resource thresholds for the host's site
                thresholds = self.config.get_resource_thresholds(host.site)
                
                # Generate host report
                logger.info(f"Generating host report for {host.name}")
                host_config_full = {
                    'name': host.name,
                    'hostname': host.hostname,
                    'site': host.site,
                    'tags': host.tags or []
                }
                
                generator = HostReportGenerator(host_config_full, thresholds)
                markdown_report = generator.generate_report(monitoring_data, ai_analysis)
                
                # Send report via email
                subject = f"[dthostmon] Host Report: {host.name}"
                
                # Get report recipients (host-specific or default)
                recipients = self.report_recipients
                if not recipients:
                    logger.warning(f"No report recipients configured, skipping email for {host.name}")
                    return False
                
                logger.info(f"Sending host report for {host.name} to {', '.join(recipients)}")
                success = self.email_alert.send_report(
                    recipients=recipients,
                    subject=subject,
                    markdown_content=markdown_report,
                    report_type='host',
                    host_or_site_name=host.name
                )
                
                if success:
                    # Update last_report_sent timestamp
                    host.last_report_sent = datetime.utcnow()
                    session.commit()
                    logger.info(f"Successfully sent host report for {host.name}")
                else:
                    logger.error(f"Failed to send host report for {host.name}")
                
                return success
                
        except Exception as e:
            logger.error(f"Error sending host report for host_id {host_id}: {e}", exc_info=True)
            return False
    
    def send_site_report(self, site_name: str, hours: int = 24) -> bool:
        """
        Generate and send site report via email.
        
        Args:
            site_name: Site identifier (e.g., 's01-chicago')
            hours: Number of hours of data to include in report (default: 24)
        
        Returns:
            True if report sent successfully
        """
        try:
            with self.db_manager.get_session() as session:
                # Get all hosts in the site
                hosts = session.query(Host).filter(
                    Host.site == site_name,
                    Host.enabled == True
                ).all()
                
                if not hosts:
                    logger.warning(f"No enabled hosts found for site {site_name}")
                    return False
                
                # Gather monitoring data for all hosts in the site
                host_data = []
                cutoff_time = datetime.utcnow() - timedelta(hours=hours)
                
                for host in hosts:
                    # Get most recent monitoring run
                    latest_run = session.query(MonitoringRun).filter(
                        MonitoringRun.host_id == host.id,
                        MonitoringRun.run_date >= cutoff_time
                    ).order_by(MonitoringRun.run_date.desc()).first()
                    
                    if latest_run:
                        host_data.append({
                            'host': host,
                            'monitoring_run': latest_run,
                            'hostname': host.hostname,
                            'name': host.name
                        })
                
                if not host_data:
                    logger.warning(f"No monitoring data found for site {site_name} in last {hours} hours")
                    return False
                
                # Get resource thresholds for the site
                thresholds = self.config.get_resource_thresholds(site_name)
                
                # Generate site report
                logger.info(f"Generating site report for {site_name}")
                generator = SiteReportGenerator(site_name, thresholds)
                markdown_report = generator.generate_report(host_data)
                
                # Send report via email
                subject = f"[dthostmon] Site Report: {site_name}"
                
                # Get report recipients
                recipients = self.report_recipients
                if not recipients:
                    logger.warning(f"No report recipients configured, skipping email for site {site_name}")
                    return False
                
                logger.info(f"Sending site report for {site_name} to {', '.join(recipients)}")
                success = self.email_alert.send_report(
                    recipients=recipients,
                    subject=subject,
                    markdown_content=markdown_report,
                    report_type='site',
                    host_or_site_name=site_name
                )
                
                if success:
                    logger.info(f"Successfully sent site report for {site_name}")
                else:
                    logger.error(f"Failed to send site report for {site_name}")
                
                return success
                
        except Exception as e:
            logger.error(f"Error sending site report for site {site_name}: {e}", exc_info=True)
            return False
    
    def send_all_due_reports(self):
        """
        Check all hosts and send reports that are due based on their frequency.
        This should be called periodically (e.g., hourly via cron).
        """
        logger.info("Checking for due reports")
        
        try:
            with self.db_manager.get_session() as session:
                # Get all enabled hosts
                hosts = session.query(Host).filter(Host.enabled == True).all()
                
                for host in hosts:
                    # Build host config
                    host_config = {
                        'name': host.name,
                        'site': host.site,
                        'report_frequency': host.report_frequency
                    }
                    
                    # Check if report is due
                    if self.should_send_report(host_config, host.last_report_sent):
                        # Get latest monitoring data
                        latest_run = session.query(MonitoringRun).filter(
                            MonitoringRun.host_id == host.id
                        ).order_by(MonitoringRun.run_date.desc()).first()
                        
                        if latest_run:
                            monitoring_data = {
                                'run_date': latest_run.run_date,
                                'status': latest_run.status,
                                'health_score': latest_run.health_score,
                                'anomalies_detected': latest_run.anomalies_detected,
                                'changes_detected': latest_run.changes_detected
                            }
                            
                            ai_analysis = None
                            if latest_run.ai_summary:
                                ai_analysis = {
                                    'summary': latest_run.ai_summary,
                                    'recommendations': latest_run.ai_recommendations,
                                    'alert_level': latest_run.alert_level
                                }
                            
                            # Send host report
                            self.send_host_report(host.id, monitoring_data, ai_analysis)
                
                # Get unique sites and send site reports if configured
                sites = set(h.site for h in hosts if h.site)
                for site in sites:
                    # Check if site-level reports are configured
                    site_config = self.config.get(f'sites.{site}', {})
                    if site_config.get('send_site_reports', True):
                        # For simplicity, send site reports daily
                        # TODO: Add site-level report frequency tracking
                        logger.info(f"Sending site report for {site}")
                        self.send_site_report(site, hours=24)
                
                logger.info("Finished checking for due reports")
                
        except Exception as e:
            logger.error(f"Error checking for due reports: {e}", exc_info=True)
