from o365_auth_user import get_access_token_user
import requests
import msal
import os
import json
from dotenv import load_dotenv

# Load environment variables
env_path = os.path.join(os.path.dirname(__file__), "secrets", ".env")
load_dotenv(env_path)

TENANT_ID = os.getenv("TENANT_ID")
CLIENT_ID = os.getenv("CLIENT_ID")

AUTHORITY = f"https://login.microsoftonline.com/{TENANT_ID}"
SCOPES = ["Mail.Read", "Mail.ReadBasic", "MailboxSettings.Read", "User.Read"]

# Token cache file for persistent login
CACHE_PATH = os.path.join(os.path.dirname(__file__), "token_cache.bin_secret")
cache = msal.SerializableTokenCache()
if os.path.exists(CACHE_PATH):
    cache.deserialize(open(CACHE_PATH, "r").read())

app = msal.PublicClientApplication(
    CLIENT_ID,
    authority=AUTHORITY,
    token_cache=cache
)

def get_access_token_user():
    accounts = app.get_accounts()
    if accounts:
        result = app.acquire_token_silent(SCOPES, account=accounts[0])
    else:
        flow = app.initiate_device_flow(scopes=SCOPES)
        if "user_code" not in flow:
            raise ValueError("Failed to create device flow. Check app registration.")
        print(flow["message"])  # Includes URL and code
        result = app.acquire_token_by_device_flow(flow)

    if "access_token" in result:
        # Save token cache
        with open(CACHE_PATH, "w") as f:
            f.write(cache.serialize())
        return result["access_token"]
    else:
        raise RuntimeError("Failed to get token: " + json.dumps(result, indent=2))

# Test the token and email access
try:
    print("\U0001F511 Getting access token using delegated flow...")
    token = get_access_token_user()
    print("\u2705 Token acquired successfully!")
    print("Access token (truncated):", token[:80] + "...\n")

    print("\U0001F4E7 Fetching the most recent 10 emails...")
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get("https://graph.microsoft.com/v1.0/me/messages?$top=10&$orderby=receivedDateTime desc", headers=headers)

    if response.status_code == 200:
        messages = response.json().get("value", [])
        for i, msg in enumerate(messages, 1):
            date = msg.get("receivedDateTime", "(No Date)")
            subject = msg.get("subject", "(No Subject)")
            print(f"{i:2}. {date} | {subject}")
    else:
        print(f"\u274C Failed to access /me: {response.status_code}")
        print(response.text)
except Exception as e:
    print(f"\u274C Error: {e}")
