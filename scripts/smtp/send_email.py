#!/usr/bin/env python3
"""
SMTP Email Utility - Send emails via configured SMTP server
Last Updated: 12/30/2025 10:05:00 PM CDT

Usage:
    send_email.py --to <recipient> --subject <subject> --body <body> \\
                  --smtp-server <server> --smtp-port <port> \\
                  [--from <sender>]

Important: Use port 25 for relay (less strict validation). Port 587 requires authentication.

Examples:
    # Use port 25 for relay (recommended for internal mail servers)
    send_email.py --to andrew@avcorp.biz --subject "Test" --body "Test email" \\
                  --smtp-server monitor --smtp-port 25

    # For port 587 (submission), you typically need SMTP authentication
    send_email.py --to user@example.com --subject "Backup Report" \\
                  --body "Backup completed successfully" \\
                  --smtp-server mail.example.com --smtp-port 587 \\
                  --from backup@myhost.local
"""

import argparse
import smtplib
import ssl
import sys
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart


def send_email(smtp_server, smtp_port, to_addr, subject, body, from_addr="root@localhost", high_priority=False):
    """
    Send email via SMTP server
    
    Args:
        smtp_server: SMTP server hostname or IP
        smtp_port: SMTP server port (use 25 for relay, 587 for submission with auth)
        to_addr: Recipient email address
        subject: Email subject
        body: Email body
        from_addr: Sender email address (default: root@localhost)
        high_priority: Set high priority headers (only for failures) (default: False)
    
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        # Create SSL context that doesn't verify certificates (for internal relays)
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        
        # Create SMTP connection
        # Note: Use port 25 for relay (less strict validation)
        # Use port 587 only if you have authentication credentials
        with smtplib.SMTP(smtp_server, smtp_port, timeout=10) as server:
            # Try STARTTLS if available (continue if it fails)
            try:
                server.starttls(context=context)
            except Exception as e:
                print(f"DEBUG: STARTTLS failed, continuing without TLS: {e}", file=sys.stderr)
                pass
            
            # Build message
            msg = MIMEText(body)
            msg["Subject"] = subject
            msg["From"] = from_addr
            msg["To"] = to_addr
            
            # Only set high priority headers if this is a failure notification
            if high_priority:
                msg["X-Priority"] = "1"
                msg["X-MSMail-Priority"] = "High"
                msg["Importance"] = "High"
            
            # Send email
            server.sendmail(from_addr, to_addr, msg.as_string())
            
        print(f"Email sent successfully to {to_addr}", file=sys.stderr)
        return True
        
    except Exception as e:
        print(f"Error sending email: {e}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Send emails via SMTP server",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument("--to", required=True, help="Recipient email address")
    parser.add_argument("--subject", required=True, help="Email subject")
    parser.add_argument("--body", required=True, help="Email body")
    parser.add_argument("--smtp-server", required=True, help="SMTP server hostname/IP")
    parser.add_argument("--smtp-port", type=int, required=True, help="SMTP server port")
    parser.add_argument("--from", dest="from_addr", default="root@localhost", 
                        help="Sender email address (default: root@localhost)")
    parser.add_argument("--high-priority", action="store_true",
                        help="Set high priority headers (only for failure notifications)")
    
    args = parser.parse_args()
    
    # Send email
    success = send_email(
        args.smtp_server,
        args.smtp_port,
        args.to,
        args.subject,
        args.body,
        args.from_addr,
        args.high_priority
    )
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
