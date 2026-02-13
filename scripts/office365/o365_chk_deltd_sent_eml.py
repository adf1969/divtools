import os
import json
import argparse
import requests
import smtplib
import sys
from email.mime.text import MIMEText
from email import policy
from email.parser import BytesParser
from datetime import datetime, timezone
from dateutil import parser as dateparser
from o365_auth import get_access_token

sys.stdout.reconfigure(line_buffering=True)

GRAPH_API_ENDPOINT = "https://graph.microsoft.com/v1.0"
EXCEPTIONS_DIR = "sent_deleted_exceptions"
ALERTS_DIR = "alerts"
ARCHIVE_DIR = "alerts.archive"
USER_FILE = "o365_users.txt"
EMAIL_SUBJECT_PREFIX = "Office365 Deleted-Sent Exceptions"
SENDER_NAME = "Office365 Monitor"
SENDER_EMAIL = "avcorp.smtp@gmail.com"
INTERNAL_DOMAIN = "avcorp.biz"  # <<<--- CHANGE THIS

# Ensure directories exist
for directory in [EXCEPTIONS_DIR, ALERTS_DIR, ARCHIVE_DIR]:
    os.makedirs(directory, exist_ok=True)

def get_users_from_file():
    users = []
    try:
        with open(USER_FILE, "r") as file:
            for line in file:
                parts = line.strip().split(",")
                if parts and parts[0]:
                    users.append(parts[0].strip())
    except FileNotFoundError:
        print(f"❌ Error: User file '{USER_FILE}' not found.")
    return users

def parse_datetime_arg(date_str, is_from=True):
    try:
        if ':' in date_str:
            date_part, time_part = date_str.split(':')
            dt_str = f"{date_part} {time_part[:2]}:{time_part[2:]}"
            dt = datetime.strptime(dt_str, "%Y-%m-%d %H:%M")
        else:
            default_time = "00:00" if is_from else "23:59"
            dt_str = f"{date_str} {default_time}"
            dt = datetime.strptime(dt_str, "%Y-%m-%d %H:%M")
        return dt.replace(tzinfo=timezone.utc)
    except Exception as e:
        raise ValueError(f"Invalid date format: {date_str}. Use YYYY-MM-DD or YYYY-MM-DD:HHMM")

def within_date_range(msg, from_date, to_date):
    sent_time_str = msg.get("sentDateTime", None)
    if not sent_time_str:
        return False
    try:
        sent_time = dateparser.isoparse(sent_time_str)
        return from_date <= sent_time <= to_date
    except Exception as e:
        print(f"⚠ Failed to parse sentDateTime: {sent_time_str} ({e})")
        return False

def message_is_suspect_graph(user_email, msg, debug=False):
    from_address = msg.get("from", {}).get("emailAddress", {}).get("address", "").lower()
    recipients = []

    for field in ["toRecipients", "ccRecipients", "bccRecipients"]:
        for rec in msg.get(field, []):
            address = rec.get("emailAddress", {}).get("address", "").lower()
            recipients.append(address)

    if debug:
        print(f"From (Graph): {from_address}")
        print(f"Recipients (Graph): {recipients}")

    if from_address == user_email.lower():
        if debug:
            print("[SUSPECT] From address matches user (Graph)")
        return True

    for rec in recipients:
        if rec and not rec.endswith(INTERNAL_DOMAIN.lower()):
            if debug:
                print(f"[SUSPECT] External recipient found: {rec} (Graph)")
            return True

    return False

def message_is_suspect_mime(user_email, mime_bytes, debug=False):
    msg = BytesParser(policy=policy.default).parsebytes(mime_bytes)

    from_address = msg.get("From", "").lower()
    recipients = []
    for header in ["To", "Cc", "Bcc"]:
        values = msg.get_all(header, [])
        for val in values:
            recipients.extend([addr.strip().lower() for addr in val.split(",")])

    if debug:
        print(f"From (MIME): {from_address}")
        print(f"Recipients (MIME): {recipients}")

    if user_email.lower() in from_address:
        if debug:
            print("[SUSPECT] From address matches user (MIME)")
        return True

    for rec in recipients:
        if rec and not rec.endswith(INTERNAL_DOMAIN.lower()):
            if debug:
                print(f"[SUSPECT] External recipient found: {rec} (MIME)")
            return True

    return False

def fetch_mime(user_email, message_id, token, debug=False):
    url = f"{GRAPH_API_ENDPOINT}/users/{user_email}/messages/{message_id}/$value"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.content
    else:
        if debug:
            print(f"⚠ Failed to fetch MIME content: {response.status_code} {response.text}")
        return None

def get_deleted_item_count(user_email, token, debug=False):
    url = f"{GRAPH_API_ENDPOINT}/users/{user_email}/mailFolders/deletedItems?$top=1&$count=true"
    headers = {
        "Authorization": f"Bearer {token}",
        "ConsistencyLevel": "eventual"
    }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        count = response.json().get("@odata.count", None)
        if debug and count is not None:
            print(f"Mailbox {user_email} Deleted Items count: {count}")
        return count
    else:
        print(f"⚠ Failed to retrieve message count for {user_email}: {response.text}")
        return None

def stream_deleted_messages(user_email, token, debug=False):
    url = f"{GRAPH_API_ENDPOINT}/users/{user_email}/mailFolders/deletedItems/messages?$top=100"
    headers = {"Authorization": f"Bearer {token}"}
    total = 0
    batch_num = 0

    if debug:
        print(f"Opening mailbox for user: {user_email}")
        print("Retrieving Deleted Items messages...")

    while url:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            batch = data.get("value", [])
            batch_num += 1
            total += len(batch)
            if debug:
                print(f"Retrieved batch #{batch_num}: {len(batch)} messages (total so far: {total})")
            yield from batch
            url = data.get("@odata.nextLink", None)
        else:
            print(f"❌ Failed to retrieve messages: {response.status_code} {response.text}")
            break

    if debug:
        print(f"Finished retrieving Deleted Items. Total messages streamed: {total}")

def scan_user(user_email, token, debug=False, from_date=None, to_date=None, quiet=False, use_mime=False):
    exceptions = []
    total_scanned = 0

    for msg in stream_deleted_messages(user_email, token, debug):
        total_scanned += 1
        sent_time = msg.get("sentDateTime", "")
        subject = msg.get("subject", "(No Subject)")
        internet_msg_id = msg.get("internetMessageId", "(No ID)")
        message_id = msg.get("id", None)

        if not within_date_range(msg, from_date, to_date):
            if debug and not quiet:
                print(f"Checking Email #{total_scanned}: {sent_time}, {subject}, Message-ID: {internet_msg_id} [SKIP - Out of Range]")
            continue

        suspect = False

        if use_mime and message_id:
            mime_data = fetch_mime(user_email, message_id, token, debug)
            if mime_data:
                suspect = message_is_suspect_mime(user_email, mime_data, debug)
            else:
                suspect = message_is_suspect_graph(user_email, msg, debug)
        else:
            suspect = message_is_suspect_graph(user_email, msg, debug)

        if suspect:
            exceptions.append(f"Subject: {subject}\nSent: {sent_time}\nMessage-ID: {internet_msg_id}\n")
            status = "[DELETED]"
        else:
            status = "[OK]"

        print(f"Checking Email #{total_scanned}: {sent_time}, {subject}, Message-ID: {internet_msg_id} {status}")

    if exceptions:
        file_path = os.path.join(EXCEPTIONS_DIR, f"{user_email}.txt")
        with open(file_path, "w") as f:
            f.write("\n\n".join(exceptions))
        print(f"⚠ Found {len(exceptions)} suspicious messages for {user_email}. Saved to {file_path}")
    else:
        print(f"✅ No suspicious messages found for {user_email}")

    return exceptions

def send_email(recipient, subject, body):
    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = SENDER_NAME
    msg["To"] = recipient
    msg["X-Priority"] = "3"
    msg["Importance"] = "Normal"

    with smtplib.SMTP("localhost") as server:
        server.sendmail(SENDER_EMAIL, [recipient], msg.as_string())

def clear_alerts():
    for file in os.listdir(ALERTS_DIR):
        original_path = os.path.join(ALERTS_DIR, file)
        timestamp = datetime.utcnow().strftime("%Y-%m-%d-%H%M")
        base_name, ext = os.path.splitext(file)
        new_file_name = f"{base_name}-{timestamp}.txt"
        new_path = os.path.join(ARCHIVE_DIR, new_file_name)
        os.rename(original_path, new_path)
        print(f"🗑 Cleared alert: {file} → Archived as {new_file_name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-scan", action="store_true", help="Scan Deleted Items for sent messages.")
    parser.add_argument("-clear", action="store_true", help="Clear saved alert flags.")
    parser.add_argument("-ls", action="store_true", help="List saved exception files.")
    parser.add_argument("-u", "--users", help="Comma-separated list of users.")
    parser.add_argument("-m", "--email", help="Send email if exceptions are found.")
    parser.add_argument("-d", "--debug", action="store_true", help="Enable debug output.")
    parser.add_argument("--fromdate", help="Filter start date: YYYY-MM-DD or YYYY-MM-DD:HHMM")
    parser.add_argument("--todate", help="Filter end date: YYYY-MM-DD or YYYY-MM-DD:HHMM")
    parser.add_argument("--precount", action="store_true", help="Precount total messages before scanning.")
    parser.add_argument("--quiet", action="store_true", help="Suppress out-of-range messages.")
    parser.add_argument("--mime", action="store_true", help="Enable MIME header parsing.")

    args = parser.parse_args()
    users = args.users.split(",") if args.users else get_users_from_file()

    if args.ls:
        for file in os.listdir(EXCEPTIONS_DIR):
            print(file)
    elif args.clear:
        clear_alerts()
    elif args.scan:
        token = get_access_token()
        if not token:
            print("❌ Failed to authenticate.")
            exit(1)

        try:
            from_date = parse_datetime_arg(args.fromdate, is_from=True) if args.fromdate else datetime(1970,1,1,tzinfo=timezone.utc)
            to_date = parse_datetime_arg(args.todate, is_from=False) if args.todate else datetime.utcnow().replace(tzinfo=timezone.utc)
        except ValueError as e:
            print(str(e))
            exit(1)

        for user in users:
            if args.precount:
                count = get_deleted_item_count(user, token, args.debug)
                if count is not None:
                    print(f"Precount: {count} total messages found in Deleted Items for {user}")
            scan_user(user, token, args.debug, from_date, to_date, quiet=args.quiet, use_mime=args.mime)
