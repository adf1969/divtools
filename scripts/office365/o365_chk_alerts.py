import os
import argparse
import smtplib
from email.mime.text import MIMEText
from datetime import datetime
import socket
from o365_auth import get_access_token  # Import authentication function

ALERTS_DIR = "alerts"
SENDER_NAME = "Office365 Monitor"
SENDER_EMAIL = "avcorp.smtp@gmail.com"
EMAIL_SUBJECT_PREFIX = "Office365 Existing Alerts"

def list_alerts():
    """ List all existing alerts. """
    alerts = os.listdir(ALERTS_DIR)
    if not alerts:
        print("✅ No alerts found.")
        return

    print("📂 Existing Alerts:")
    for alert in alerts:
        print(f" - {alert}")

def load_alert_content(alert_filename):
    """ Load the content of an alert file. """
    with open(alert_filename, "r") as f:
        return f.read()

def generate_footer():
    """ Generate footer with server hostname and alerts directory path. """
    hostname = socket.gethostname()
    alerts_path = os.path.abspath(ALERTS_DIR)
    return f"<br><br>Sent from server: {hostname}<br>Alerts folder: {alerts_path}"

def send_email(recipient, subject, body, token, html=False, high_priority=True):
    if html:
        msg = MIMEText(body, "html")
    else:
        msg = MIMEText(body, "plain")

    msg["Subject"] = subject
    msg["From"] = f"{SENDER_NAME}"
    msg["To"] = recipient

    if high_priority:
        # Set high-priority headers only if needed
        msg["X-Priority"] = "1"  # 1 = High, 3 = Normal, 5 = Low
        msg["X-MSMail-Priority"] = "High"
        msg["Importance"] = "High"

    with smtplib.SMTP("localhost") as server:
        # Authenticate if needed
        # server.starttls()
        # server.login(SENDER_EMAIL, token)

        server.sendmail(SENDER_EMAIL, [recipient], msg.as_string())

def send_alerts(email, debug=False, combine=False, all_clear=False):
    """ Send email for each alert in ALERTS_DIR, or combine into one if combine is True. """
    token = get_access_token()
    if not token:
        print("❌ Failed to authenticate. Cannot send emails.")
        return

    alerts = sorted(os.listdir(ALERTS_DIR))

    if not alerts:
        if all_clear:
            subject = f"{EMAIL_SUBJECT_PREFIX}: No Alerts"
            body = "All Clear. No Alerts."
            body += generate_footer()

            if debug:
                print(f"📧 Would send (No Priority) to {email}:\nSubject: {subject}\nBody:\n{body}\n{'-'*40}")
            else:
                send_email(email, subject, body, token, html=True, high_priority=False)
                print(f"📧 Sent All Clear email to {email}")
        else:
            print("✅ No alerts to send. (No All Clear flag set.)")
        return

    if combine:
        combined_body = ""
        for idx, alert_file in enumerate(alerts, start=1):
            alert_path = os.path.join(ALERTS_DIR, alert_file)
            alert_content = load_alert_content(alert_path)
            alert_title = alert_file.replace('alert_', '').replace('.txt', '')

            combined_body += f"<b><u>Alert {idx}: {alert_title}:</u></b><br>\n"
            combined_body += f"{alert_content.replace(chr(10), '<br>')}\n<br><br>\n"

        combined_body += generate_footer()
        subject = f"{EMAIL_SUBJECT_PREFIX}: {len(alerts)} Alerts"

        if debug:
            print(f"📧 Would send (High Priority) to {email}:\nSubject: {subject}\nBody:\n{combined_body}\n{'-'*40}")
        else:
            send_email(email, subject, combined_body.strip(), token, html=True)
            print(f"📧 Sent combined alert email with {len(alerts)} alerts to {email}")

    else:
        for alert_file in alerts:
            alert_path = os.path.join(ALERTS_DIR, alert_file)
            alert_content = load_alert_content(alert_path)
            subject = f"{EMAIL_SUBJECT_PREFIX}: {alert_file.replace('alert_', '').replace('.txt', '')}"
            full_body = alert_content + "\n\n" + generate_footer()

            if debug:
                print(f"📧 Would send (High Priority) to {email}:\nSubject: {subject}\nBody:\n{full_body}\n{'-'*40}")
            else:
                send_email(email, subject, full_body, token, html=True)
                print(f"📧 Sent alert email for {alert_file} to {email}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check and email existing Office365 alerts.")
    parser.add_argument("-d", "--debug", action="store_true", help="Enable debug output.")
    parser.add_argument("-m", "--email", help="Send alerts to specified email address.")
    parser.add_argument("-c", "--combine", action="store_true", help="Combine all alerts into one email.")
    parser.add_argument("-ac", "--all-clear", action="store_true", help="Send All Clear email if no alerts.")
    parser.add_argument("-ls", action="store_true", help="List existing alerts.")

    args = parser.parse_args()

    if args.ls:
        list_alerts()
    elif args.email:
        send_alerts(args.email, args.debug, args.combine, args.all_clear)
    else:
        parser.print_help()
