"""
Unit tests for email alert module
Last Updated: 11/15/2025 11:30:00 AM CDT
"""

import pytest
from unittest.mock import Mock, patch, MagicMock, call
from datetime import datetime
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dthostmon.core.email_alert import EmailAlert, EmailError


@pytest.fixture
def email_config():
    """Email configuration for testing"""
    return {
        'smtp_host': 'smtp.example.com',
        'smtp_port': 587,
        'smtp_auth_user': 'test@example.com',
        'smtp_auth_password': 'test_password',
        'from_address': 'dthostmon@example.com',
        'use_tls': True,
        'smtp_auth_required': True
    }


@pytest.fixture
def email_config_no_auth():
    """Email configuration without authentication"""
    return {
        'smtp_host': 'smtp.example.com',
        'smtp_port': 25,
        'smtp_auth_user': '',
        'smtp_auth_password': '',
        'from_address': 'dthostmon@example.com',
        'use_tls': False,
        'smtp_auth_required': False
    }


@pytest.fixture
def email_config_with_reply_to(email_config):
    """Email configuration with reply-to address"""
    config = email_config.copy()
    config['reply_to_address'] = 'support@example.com'
    return config


def test_email_alert_initialization(email_config):
    """Test EmailAlert initialization"""
    alert = EmailAlert(**email_config)
    
    assert alert.smtp_host == 'smtp.example.com'
    assert alert.smtp_port == 587
    assert alert.smtp_auth_user == 'test@example.com'
    assert alert.smtp_auth_password == 'test_password'
    assert alert.from_address == 'dthostmon@example.com'
    assert alert.use_tls is True
    assert alert.smtp_auth_required is True
    assert alert.reply_to_address == 'dthostmon@example.com'  # Defaults to from_address


def test_email_alert_with_reply_to(email_config_with_reply_to):
    """Test EmailAlert initialization with custom reply-to address"""
    alert = EmailAlert(**email_config_with_reply_to)
    
    assert alert.reply_to_address == 'support@example.com'


@patch('smtplib.SMTP')
def test_send_alert_success(mock_smtp, email_config):
    """Test successful email sending"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config)
    result = alert.send_alert(
        recipients=['admin@example.com'],
        subject='Test Alert',
        html_body='<p>This is a test alert</p>'
    )
    
    assert result is True
    mock_smtp.assert_called_once_with('smtp.example.com', 587, timeout=30)
    mock_server.starttls.assert_called_once()
    mock_server.login.assert_called_once_with('test@example.com', 'test_password')
    mock_server.sendmail.assert_called_once()
    mock_server.quit.assert_called_once()


@patch('smtplib.SMTP')
def test_send_alert_with_text_body(mock_smtp, email_config):
    """Test email sending with both HTML and text body"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config)
    result = alert.send_alert(
        recipients=['admin@example.com', 'user@example.com'],
        subject='Test Alert',
        html_body='<p>HTML content</p>',
        text_body='Text content'
    )
    
    assert result is True
    # Verify that sendmail was called with both recipients
    call_args = mock_server.sendmail.call_args
    recipients = call_args[0][1]
    assert 'admin@example.com' in recipients
    assert 'user@example.com' in recipients


@patch('smtplib.SMTP_SSL')
def test_send_alert_with_ssl_port_465(mock_smtp_ssl, email_config):
    """Test email sending with SSL port 465"""
    mock_server = MagicMock()
    mock_smtp_ssl.return_value = mock_server
    
    config = email_config.copy()
    config['smtp_port'] = 465
    config['use_tls'] = False
    
    alert = EmailAlert(**config)
    result = alert.send_alert(
        recipients=['admin@example.com'],
        subject='Test Alert',
        html_body='<p>Test</p>'
    )
    
    assert result is True
    mock_smtp_ssl.assert_called_once_with('smtp.example.com', 465, timeout=30)
    mock_server.login.assert_called_once()


@patch('smtplib.SMTP')
def test_send_alert_no_authentication(mock_smtp, email_config_no_auth):
    """Test email sending without authentication"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config_no_auth)
    result = alert.send_alert(
        recipients=['admin@example.com'],
        subject='Test Alert',
        html_body='<p>Test</p>'
    )
    
    assert result is True
    # login should not be called when smtp_auth_required is False
    mock_server.login.assert_not_called()
    mock_server.starttls.assert_not_called()
    mock_server.sendmail.assert_called_once()


@patch('smtplib.SMTP')
def test_send_alert_connection_failure(mock_smtp, email_config):
    """Test email sending with SMTP connection failure"""
    mock_smtp.side_effect = smtplib.SMTPException("Connection failed")
    
    alert = EmailAlert(**email_config)
    
    with pytest.raises(EmailError, match="Email sending failed"):
        alert.send_alert(
            recipients=['admin@example.com'],
            subject='Test Alert',
            html_body='<p>Test</p>'
        )


@patch('smtplib.SMTP')
def test_send_alert_authentication_failure(mock_smtp, email_config):
    """Test email sending with SMTP authentication failure"""
    mock_server = MagicMock()
    mock_server.login.side_effect = smtplib.SMTPAuthenticationError(401, "Invalid credentials")
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config)
    
    with pytest.raises(EmailError, match="Email sending failed"):
        alert.send_alert(
            recipients=['admin@example.com'],
            subject='Test Alert',
            html_body='<p>Test</p>'
        )


@patch('smtplib.SMTP')
def test_send_alert_sendmail_failure(mock_smtp, email_config):
    """Test email sending with sendmail failure"""
    mock_server = MagicMock()
    mock_server.sendmail.side_effect = smtplib.SMTPException("Send failed")
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config)
    
    with pytest.raises(EmailError, match="Email sending failed"):
        alert.send_alert(
            recipients=['admin@example.com'],
            subject='Test Alert',
            html_body='<p>Test</p>'
        )


@patch('smtplib.SMTP')
def test_send_alert_sets_headers_correctly(mock_smtp, email_config_with_reply_to):
    """Test that email headers are set correctly"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config_with_reply_to)
    alert.send_alert(
        recipients=['admin@example.com'],
        subject='Test Alert',
        html_body='<p>Test</p>'
    )
    
    # Extract the message from sendmail call
    call_args = mock_server.sendmail.call_args
    msg_str = call_args[0][2]
    
    # Verify headers
    assert 'Subject: Test Alert' in msg_str
    assert 'From: dthostmon@example.com' in msg_str
    assert 'Reply-To: support@example.com' in msg_str
    assert 'To: admin@example.com' in msg_str


def test_generate_monitoring_report_basic(email_config):
    """Test basic monitoring report generation"""
    alert = EmailAlert(**email_config)
    
    monitoring_run = {
        'id': 'run-123',
        'health_score': 85,
        'alert_level': 'WARN',
        'anomalies_detected': 2,
        'changes_detected': 5,
        'execution_time': 12.5,
        'log_entries': [],
        'run_date': datetime(2025, 11, 15, 12, 30, 0)
    }
    
    host_info = {
        'name': 'test-host',
        'hostname': '192.168.1.100'
    }
    
    html = alert.generate_monitoring_report(monitoring_run, [], host_info)
    
    assert '85/100' in html
    assert 'WARN' in html
    assert 'test-host' in html
    assert '192.168.1.100' in html
    assert '<h1>' in html
    assert '</html>' in html


def test_generate_monitoring_report_with_ai_analysis(email_config):
    """Test monitoring report with AI analysis included"""
    alert = EmailAlert(**email_config)
    
    monitoring_run = {
        'id': 'run-123',
        'health_score': 75,
        'alert_level': 'WARN',
        'anomalies_detected': 3,
        'changes_detected': 8,
        'execution_time': 15.0,
        'log_entries': [],
        'run_date': datetime(2025, 11, 15, 12, 30, 0),
        'ai_summary': 'Multiple security-related anomalies detected in system logs',
        'ai_recommendations': 'Review failed SSH attempts and check system access logs'
    }
    
    host_info = {
        'name': 'prod-server',
        'hostname': '10.0.0.5'
    }
    
    html = alert.generate_monitoring_report(monitoring_run, [], host_info)
    
    assert 'AI Analysis' in html
    assert 'Multiple security-related anomalies' in html
    assert 'Review failed SSH attempts' in html


def test_generate_monitoring_report_with_changes(email_config):
    """Test monitoring report with detected changes"""
    alert = EmailAlert(**email_config)
    
    monitoring_run = {
        'id': 'run-123',
        'health_score': 65,
        'alert_level': 'CRITICAL',
        'anomalies_detected': 5,
        'changes_detected': 3,
        'execution_time': 20.0,
        'log_entries': [],
        'run_date': datetime(2025, 11, 15, 12, 30, 0)
    }
    
    host_info = {
        'name': 'database-server',
        'hostname': '10.0.1.10'
    }
    
    changes = [
        {
            'change_type': 'new_error',
            'severity': 'CRITICAL',
            'description': 'Disk space critically low: 5% remaining',
            'log_file_path': '/var/log/syslog'
        },
        {
            'change_type': 'configuration_change',
            'severity': 'WARN',
            'description': 'SSH configuration modified',
            'log_file_path': '/var/log/auth.log'
        }
    ]
    
    html = alert.generate_monitoring_report(monitoring_run, changes, host_info)
    
    assert 'Detected Changes' in html
    assert 'Disk space critically low' in html
    assert 'SSH configuration modified' in html
    assert 'severity-CRITICAL' in html
    assert 'severity-WARN' in html


def test_generate_monitoring_report_many_changes(email_config):
    """Test monitoring report limits displayed changes"""
    alert = EmailAlert(**email_config)
    
    monitoring_run = {
        'id': 'run-123',
        'health_score': 50,
        'alert_level': 'CRITICAL',
        'anomalies_detected': 20,
        'changes_detected': 15,
        'execution_time': 30.0,
        'log_entries': [],
        'run_date': datetime(2025, 11, 15, 12, 30, 0)
    }
    
    host_info = {
        'name': 'busy-server',
        'hostname': '10.0.2.5'
    }
    
    # Create 15 changes
    changes = [
        {
            'change_type': 'error_log',
            'severity': 'WARN' if i % 2 == 0 else 'CRITICAL',
            'description': f'Error event {i+1}',
            'log_file_path': '/var/log/syslog'
        }
        for i in range(15)
    ]
    
    html = alert.generate_monitoring_report(monitoring_run, changes, host_info)
    
    # First 10 changes should be shown
    assert 'Error event 1' in html
    assert 'Error event 10' in html
    # Last 5 should be summarized
    assert '... and 5 more changes' in html


def test_get_health_color_green(email_config):
    """Test health color for score >= 90 (green)"""
    alert = EmailAlert(**email_config)
    
    assert alert._get_health_color(100) == '#27ae60'
    assert alert._get_health_color(95) == '#27ae60'
    assert alert._get_health_color(90) == '#27ae60'


def test_get_health_color_orange(email_config):
    """Test health color for 70 <= score < 90 (orange)"""
    alert = EmailAlert(**email_config)
    
    assert alert._get_health_color(89) == '#f39c12'
    assert alert._get_health_color(80) == '#f39c12'
    assert alert._get_health_color(70) == '#f39c12'


def test_get_health_color_red(email_config):
    """Test health color for score < 70 (red)"""
    alert = EmailAlert(**email_config)
    
    assert alert._get_health_color(69) == '#e74c3c'
    assert alert._get_health_color(50) == '#e74c3c'
    assert alert._get_health_color(0) == '#e74c3c'


def test_get_alert_emoji_info(email_config):
    """Test alert emoji for INFO level"""
    alert = EmailAlert(**email_config)
    
    assert alert._get_alert_emoji('INFO') == '✅'


def test_get_alert_emoji_warn(email_config):
    """Test alert emoji for WARN level"""
    alert = EmailAlert(**email_config)
    
    assert alert._get_alert_emoji('WARN') == '⚠️'


def test_get_alert_emoji_critical(email_config):
    """Test alert emoji for CRITICAL level"""
    alert = EmailAlert(**email_config)
    
    assert alert._get_alert_emoji('CRITICAL') == '🚨'


def test_get_alert_emoji_unknown(email_config):
    """Test alert emoji for unknown level"""
    alert = EmailAlert(**email_config)
    
    assert alert._get_alert_emoji('UNKNOWN') == '📊'


@patch.object(EmailAlert, 'send_alert')
def test_send_monitoring_alert_success(mock_send, email_config):
    """Test successful monitoring alert sending"""
    mock_send.return_value = True
    
    alert = EmailAlert(**email_config)
    
    monitoring_run = {
        'id': 'run-123',
        'health_score': 85,
        'alert_level': 'WARN',
        'anomalies_detected': 2,
        'changes_detected': 5,
        'execution_time': 12.5,
        'log_entries': [],
        'ai_summary': 'System operating normally with minor issues'
    }
    
    host_info = {
        'name': 'test-host',
        'hostname': '192.168.1.100'
    }
    
    result = alert.send_monitoring_alert(
        recipients=['admin@example.com'],
        monitoring_run=monitoring_run,
        changes=[],
        host_info=host_info
    )
    
    assert result is True
    mock_send.assert_called_once()
    
    # Verify subject line
    call_args = mock_send.call_args
    subject = call_args[0][2]
    assert '[WARN]' in subject
    assert 'test-host' in subject


@patch.object(EmailAlert, 'send_alert')
def test_send_monitoring_alert_with_changes(mock_send, email_config):
    """Test monitoring alert with detected changes"""
    mock_send.return_value = True
    
    alert = EmailAlert(**email_config)
    
    monitoring_run = {
        'id': 'run-456',
        'health_score': 45,
        'alert_level': 'CRITICAL',
        'anomalies_detected': 10,
        'changes_detected': 8,
        'execution_time': 25.0,
        'log_entries': [],
        'ai_summary': 'Critical security issues detected'
    }
    
    host_info = {
        'name': 'prod-db',
        'hostname': '10.0.0.100'
    }
    
    changes = [
        {
            'change_type': 'security_event',
            'severity': 'CRITICAL',
            'description': 'Unauthorized access attempt detected',
            'log_file_path': '/var/log/auth.log'
        }
    ]
    
    result = alert.send_monitoring_alert(
        recipients=['ops@example.com', 'security@example.com'],
        monitoring_run=monitoring_run,
        changes=changes,
        host_info=host_info
    )
    
    assert result is True
    
    call_args = mock_send.call_args
    subject = call_args[0][2]
    assert '[CRITICAL]' in subject
    assert 'prod-db' in subject


def test_send_monitoring_alert_text_body_format(email_config):
    """Test that monitoring alert text body is properly formatted"""
    alert = EmailAlert(**email_config)
    
    monitoring_run = {
        'id': 'run-789',
        'health_score': 72,
        'alert_level': 'WARN',
        'anomalies_detected': 4,
        'changes_detected': 6,
        'ai_summary': 'Several warnings in system logs'
    }
    
    host_info = {
        'name': 'web-server',
        'hostname': '10.1.1.50'
    }
    
    # We need to capture the send_alert call to check text_body
    with patch('smtplib.SMTP'):
        with patch.object(alert, 'send_alert', wraps=alert.send_alert) as mock_send:
            alert.send_monitoring_alert(
                recipients=['admin@example.com'],
                monitoring_run=monitoring_run,
                changes=[],
                host_info=host_info
            )
            
            # Verify send_alert was called with text_body
            call_args = mock_send.call_args
            text_body = call_args[1]['text_body']
            assert 'web-server' in text_body
            assert '10.1.1.50' in text_body
            assert 'WARN' in text_body


@patch('smtplib.SMTP')
def test_send_alert_with_special_characters(mock_smtp, email_config):
    """Test email sending with special characters in content"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config)
    result = alert.send_alert(
        recipients=['admin@example.com'],
        subject='Alert with special chars: <>&"',
        html_body='<p>Test with unicode: café, naïve, 中文</p>'
    )
    
    assert result is True
    mock_server.sendmail.assert_called_once()


@patch('smtplib.SMTP')
def test_send_report_with_markdown_attachment(mock_smtp, email_config):
    """Test sending report with Markdown attachment"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config)
    markdown_content = """# Host Report
## System Health
- CPU: 45%
- Memory: 60%
"""
    
    result = alert.send_report(
        recipients=['admin@example.com'],
        subject='Host Report: prod-web-01',
        markdown_content=markdown_content,
        report_type='host',
        host_or_site_name='prod-web-01'
    )
    
    assert result is True
    mock_server.sendmail.assert_called_once()
    
    # Verify sendmail was called with correct parameters
    call_args = mock_server.sendmail.call_args
    assert call_args[0][0] == 'dthostmon@example.com'  # from_address
    assert call_args[0][1] == ['admin@example.com']  # recipients
    
    # Message should contain Markdown attachment
    message = call_args[0][2]
    assert 'host_report_prod-web-01' in message
    assert '.md' in message


@patch('smtplib.SMTP')
def test_send_report_filename_format(mock_smtp, email_config):
    """Test report attachment filename format"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config)
    
    result = alert.send_report(
        recipients=['admin@example.com'],
        subject='Site Report: s01-chicago',
        markdown_content='# Site Report',
        report_type='site',
        host_or_site_name='s01-chicago'
    )
    
    assert result is True
    
    # Check filename format in message
    message = mock_server.sendmail.call_args[0][2]
    assert 'site_report_s01-chicago' in message
    
    # Should include date in filename (YYYYMMDD format)
    from datetime import datetime
    date_str = datetime.utcnow().strftime('%Y%m%d')
    assert date_str in message


@patch('smtplib.SMTP')
def test_send_report_multiple_recipients(mock_smtp, email_config):
    """Test sending report to multiple recipients"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config)
    recipients = ['admin1@example.com', 'admin2@example.com', 'ops@example.com']
    
    result = alert.send_report(
        recipients=recipients,
        subject='Host Report',
        markdown_content='# Report Content',
        report_type='host',
        host_or_site_name='test-host'
    )
    
    assert result is True
    
    # Verify all recipients in sendmail call
    call_args = mock_server.sendmail.call_args
    assert call_args[0][1] == recipients


@patch('smtplib.SMTP')
def test_send_report_with_tls(mock_smtp, email_config):
    """Test sending report with TLS configuration"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    email_config['use_tls'] = True
    email_config['smtp_port'] = 587
    
    alert = EmailAlert(**email_config)
    
    result = alert.send_report(
        recipients=['admin@example.com'],
        subject='Report',
        markdown_content='# Content',
        report_type='host',
        host_or_site_name='host1'
    )
    
    assert result is True
    
    # Verify STARTTLS was called
    mock_server.starttls.assert_called_once()
    mock_server.login.assert_called_once_with('test@example.com', 'test_password')


@patch('smtplib.SMTP_SSL')
def test_send_report_with_ssl(mock_smtp_ssl, email_config):
    """Test sending report with SSL configuration"""
    mock_server = MagicMock()
    mock_smtp_ssl.return_value = mock_server
    
    email_config['use_tls'] = False
    email_config['smtp_port'] = 465
    
    alert = EmailAlert(**email_config)
    
    result = alert.send_report(
        recipients=['admin@example.com'],
        subject='Report',
        markdown_content='# Content',
        report_type='host',
        host_or_site_name='host1'
    )
    
    assert result is True
    
    # Verify SMTP_SSL was used (not SMTP with STARTTLS)
    mock_smtp_ssl.assert_called_once_with('smtp.example.com', 465, timeout=30)
    assert not hasattr(mock_server, 'starttls') or not mock_server.starttls.called


@patch('smtplib.SMTP')
def test_send_report_no_auth(mock_smtp, email_config_no_auth):
    """Test sending report without SMTP authentication"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config_no_auth)
    
    result = alert.send_report(
        recipients=['admin@example.com'],
        subject='Report',
        markdown_content='# Content',
        report_type='host',
        host_or_site_name='host1'
    )
    
    assert result is True
    
    # Verify login was NOT called when auth not required
    mock_server.login.assert_not_called()


@patch('smtplib.SMTP')
def test_send_report_with_reply_to(mock_smtp, email_config_with_reply_to):
    """Test sending report with Reply-To header"""
    mock_server = MagicMock()
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config_with_reply_to)
    
    result = alert.send_report(
        recipients=['admin@example.com'],
        subject='Report',
        markdown_content='# Content',
        report_type='host',
        host_or_site_name='host1'
    )
    
    assert result is True
    
    # Check Reply-To header in message
    message = mock_server.sendmail.call_args[0][2]
    assert 'Reply-To: support@example.com' in message


@patch('smtplib.SMTP')
def test_send_report_failure_raises_error(mock_smtp, email_config):
    """Test that send_report raises EmailError on failure"""
    mock_server = MagicMock()
    mock_server.sendmail.side_effect = smtplib.SMTPException('Connection failed')
    mock_smtp.return_value = mock_server
    
    alert = EmailAlert(**email_config)
    
    with pytest.raises(EmailError) as exc_info:
        alert.send_report(
            recipients=['admin@example.com'],
            subject='Report',
            markdown_content='# Content',
            report_type='host',
            host_or_site_name='host1'
        )
    
    assert 'Report email sending failed' in str(exc_info.value)
