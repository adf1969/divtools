"""
Email alerting module for dthostmon
Last Updated: 11/14/2025 12:00:00 PM CDT

Sends HTML-formatted email alerts with monitoring results.
"""

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
from email.utils import formatdate
from typing import List, Dict, Optional
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class EmailError(Exception):
    """Raised when email sending fails"""
    pass


class EmailAlert:
    """Email alert sender for monitoring results"""
    
    def __init__(self, smtp_host: str, smtp_port: int, smtp_auth_user: str, 
                 smtp_auth_password: str, from_address: str, use_tls: bool = True,
                 smtp_auth_required: bool = True, reply_to_address: Optional[str] = None):
        """
        Initialize email alert sender
        
        Args:
            smtp_host: SMTP server hostname
            smtp_port: SMTP server port
            smtp_auth_user: SMTP authentication username (only used if smtp_auth_required=True)
            smtp_auth_password: SMTP authentication password (only used if smtp_auth_required=True)
            from_address: Email "From:" header address
            use_tls: Use TLS encryption
            smtp_auth_required: Whether SMTP authentication is required (default: True)
            reply_to_address: Optional "Reply-To:" header address (defaults to from_address if not set)
        """
        self.smtp_host = smtp_host
        self.smtp_port = smtp_port
        self.smtp_auth_user = smtp_auth_user
        self.smtp_auth_password = smtp_auth_password
        self.from_address = from_address
        self.reply_to_address = reply_to_address or from_address
        self.use_tls = use_tls
        self.smtp_auth_required = smtp_auth_required
    
    def send_alert(self, recipients: List[str], subject: str, 
                   html_body: str, text_body: Optional[str] = None) -> bool:
        """
        Send email alert
        
        Args:
            recipients: List of recipient email addresses
            subject: Email subject line
            html_body: HTML email body
            text_body: Plain text fallback (optional)
        
        Returns:
            True if email sent successfully
        
        Raises:
            EmailError: If email sending fails
        """
        try:
            # Create message
            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = self.from_address
            msg['To'] = ', '.join(recipients)
            msg['Reply-To'] = self.reply_to_address
            msg['Date'] = datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S +0000')
            
            # Attach plain text version
            if text_body:
                part1 = MIMEText(text_body, 'plain')
                msg.attach(part1)
            
            # Attach HTML version
            part2 = MIMEText(html_body, 'html')
            msg.attach(part2)
            
            # Connect to SMTP server
            if self.use_tls and self.smtp_port == 587:
                server = smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=30)
                server.starttls()
            elif self.smtp_port == 465:
                server = smtplib.SMTP_SSL(self.smtp_host, self.smtp_port, timeout=30)
            else:
                server = smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=30)
            
            # Authenticate if required
            if self.smtp_auth_required:
                server.login(self.smtp_auth_user, self.smtp_auth_password)
            
            server.sendmail(self.from_address, recipients, msg.as_string())
            server.quit()
            
            logger.info(f"Email sent to {', '.join(recipients)}: {subject}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to send email: {e}")
            raise EmailError(f"Email sending failed: {e}")
    
    def generate_monitoring_report(self, monitoring_run: Dict, changes: List[Dict], 
                                    host_info: Dict) -> str:
        """
        Generate HTML email report for monitoring run
        
        Args:
            monitoring_run: Monitoring run data
            changes: List of detected changes
            host_info: Host information
        
        Returns:
            HTML string for email body
        """
        health_score = monitoring_run.get('health_score', 0)
        health_color = self._get_health_color(health_score)
        alert_level = monitoring_run.get('alert_level', 'INFO')
        alert_emoji = self._get_alert_emoji(alert_level)
        
        html = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 800px; margin: 0 auto; padding: 20px; }}
        .header {{ background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }}
        .score {{ font-size: 48px; font-weight: bold; color: {health_color}; }}
        .section {{ margin: 20px 0; padding: 15px; border-left: 4px solid #3498db; background: #f8f9fa; }}
        .change-item {{ margin: 10px 0; padding: 10px; background: white; border-radius: 3px; }}
        .severity-INFO {{ border-left: 3px solid #3498db; }}
        .severity-WARN {{ border-left: 3px solid #f39c12; }}
        .severity-CRITICAL {{ border-left: 3px solid #e74c3c; }}
        table {{ width: 100%; border-collapse: collapse; margin: 10px 0; }}
        th, td {{ padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }}
        th {{ background-color: #34495e; color: white; }}
        .footer {{ margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>{alert_emoji} dthostmon Alert: {host_info.get('name', 'Unknown Host')}</h1>
            <p>Monitoring Report - {monitoring_run.get('run_date', datetime.utcnow()).strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
        </div>
        
        <div class="section">
            <h2>Health Score</h2>
            <div class="score">{health_score}/100</div>
            <p><strong>Status:</strong> {alert_level}</p>
            <p><strong>Host:</strong> {host_info.get('hostname')} ({host_info.get('name')})</p>
            <p><strong>Execution Time:</strong> {monitoring_run.get('execution_time', 0):.2f} seconds</p>
        </div>
        
        <div class="section">
            <h2>Summary</h2>
            <table>
                <tr>
                    <th>Metric</th>
                    <th>Value</th>
                </tr>
                <tr>
                    <td>Anomalies Detected</td>
                    <td>{monitoring_run.get('anomalies_detected', 0)}</td>
                </tr>
                <tr>
                    <td>Changes Detected</td>
                    <td>{monitoring_run.get('changes_detected', 0)}</td>
                </tr>
                <tr>
                    <td>Logs Analyzed</td>
                    <td>{len(monitoring_run.get('log_entries', []))}</td>
                </tr>
            </table>
        </div>
"""
        
        # Add AI analysis if available
        if monitoring_run.get('ai_summary'):
            html += f"""
        <div class="section">
            <h2>AI Analysis</h2>
            <p>{monitoring_run['ai_summary']}</p>
            {f"<p><strong>Recommendations:</strong> {monitoring_run['ai_recommendations']}</p>" if monitoring_run.get('ai_recommendations') else ""}
        </div>
"""
        
        # Add detected changes
        if changes:
            html += """
        <div class="section">
            <h2>Detected Changes</h2>
"""
            for change in changes[:10]:  # Limit to top 10 changes
                severity = change.get('severity', 'INFO')
                html += f"""
            <div class="change-item severity-{severity}">
                <strong>{change.get('change_type', 'Unknown').replace('_', ' ').title()}</strong> - {severity}
                <p>{change.get('description', 'No description')}</p>
                {f"<p><small>File: {change.get('log_file_path')}</small></p>" if change.get('log_file_path') else ""}
            </div>
"""
            
            if len(changes) > 10:
                html += f"<p><em>... and {len(changes) - 10} more changes</em></p>"
            
            html += "</div>"
        
        # Footer
        html += f"""
        <div class="footer">
            <p>This is an automated alert from dthostmon. Report ID: {monitoring_run.get('id', 'N/A')}</p>
            <p>Generated at {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
        </div>
    </div>
</body>
</html>
"""
        return html
    
    def _get_health_color(self, score: int) -> str:
        """Get color based on health score"""
        if score >= 90:
            return '#27ae60'  # Green
        elif score >= 70:
            return '#f39c12'  # Orange
        else:
            return '#e74c3c'  # Red
    
    def _get_alert_emoji(self, level: str) -> str:
        """Get emoji for alert level"""
        emoji_map = {
            'INFO': '✅',
            'WARN': '⚠️',
            'CRITICAL': '🚨'
        }
        return emoji_map.get(level, '📊')
    
    def send_monitoring_alert(self, recipients: List[str], monitoring_run: Dict, 
                             changes: List[Dict], host_info: Dict) -> bool:
        """
        Send monitoring alert email
        
        Args:
            recipients: Email recipients
            monitoring_run: Monitoring run data
            changes: Detected changes
            host_info: Host information
        
        Returns:
            True if email sent successfully
        """
        alert_level = monitoring_run.get('alert_level', 'INFO')
        host_name = host_info.get('name', 'Unknown Host')
        
        subject = f"[{alert_level}] dthostmon Alert: {host_name}"
        html_body = self.generate_monitoring_report(monitoring_run, changes, host_info)
        
        # Generate plain text version
        text_body = f"""
dthostmon Monitoring Alert

Host: {host_name} ({host_info.get('hostname')})
Alert Level: {alert_level}
Health Score: {monitoring_run.get('health_score', 0)}/100
Anomalies: {monitoring_run.get('anomalies_detected', 0)}
Changes: {monitoring_run.get('changes_detected', 0)}

{monitoring_run.get('ai_summary', 'No AI analysis available')}

Report ID: {monitoring_run.get('id')}
Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}
"""
        
        return self.send_alert(recipients, subject, html_body, text_body)
    
    def send_report(self, recipients: List[str], subject: str, 
                   markdown_content: str, report_type: str, host_or_site_name: str) -> bool:
        """
        Send monitoring report as email with Markdown attachment
        Last Updated: 11/15/2025 3:45:00 PM CST
        
        Args:
            recipients: List of recipient email addresses
            subject: Email subject line
            markdown_content: Markdown report content to attach
            report_type: Type of report ("host" or "site")
            host_or_site_name: Host or site name for filename
        
        Returns:
            True if email sent successfully
        
        Raises:
            EmailError: If email sending fails
        """
        try:
            # Create multipart message with mixed type for attachment
            msg = MIMEMultipart('mixed')
            msg['From'] = self.from_address
            msg['To'] = ', '.join(recipients)
            msg['Subject'] = subject
            msg['Date'] = formatdate(localtime=True)
            
            if self.reply_to_address:
                msg['Reply-To'] = self.reply_to_address
            
            # Create email body
            report_type_label = report_type.upper()
            body_text = f"""
dthostmon {report_type_label} Monitoring Report

This email contains a Markdown-formatted monitoring report for:
{host_or_site_name}

The report is attached as a .md file and can be viewed with any Markdown viewer
or text editor. See attachment: {report_type}_report_{host_or_site_name}_{datetime.utcnow().strftime('%Y%m%d')}.md

Report Type: {report_type_label}
Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}

---
dthostmon Automated Monitoring System
"""
            
            # Attach plain text body
            msg.attach(MIMEText(body_text, 'plain'))
            
            # Create Markdown attachment
            markdown_filename = f"{report_type}_report_{host_or_site_name}_{datetime.utcnow().strftime('%Y%m%d')}.md"
            attachment = MIMEBase('text', 'markdown')
            attachment.set_payload(markdown_content.encode('utf-8'))
            encoders.encode_base64(attachment)
            attachment.add_header('Content-Disposition', f'attachment; filename="{markdown_filename}"')
            msg.attach(attachment)
            
            # Send email
            if self.use_tls:
                # Use STARTTLS (port 587)
                server = smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=30)
                server.starttls()
            else:
                # Use SSL (port 465)
                server = smtplib.SMTP_SSL(self.smtp_host, self.smtp_port, timeout=30)
            
            if self.smtp_auth_required and self.smtp_auth_user and self.smtp_auth_password:
                server.login(self.smtp_auth_user, self.smtp_auth_password)
            
            server.sendmail(self.from_address, recipients, msg.as_string())
            server.quit()
            
            logger.info(f"Report email sent to {', '.join(recipients)}: {subject}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to send report email: {e}")
            raise EmailError(f"Report email sending failed: {e}")
