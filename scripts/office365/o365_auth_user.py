# in o365_auth_user.py

import os
import msal
from dotenv import load_dotenv

env_path = os.path.join(os.path.dirname(__file__), "secrets", ".env")
load_dotenv(env_path)

TENANT_ID     = os.getenv("TENANT_ID")
CLIENT_ID     = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")
AUTHORITY     = f"https://login.microsoftonline.com/{TENANT_ID}"
# “.default” tells MSAL to use all the app-level Graph permissions you’ve granted
SCOPES        = ["https://graph.microsoft.com/.default"]

_app = msal.ConfidentialClientApplication(
    CLIENT_ID,
    authority=AUTHORITY,
    client_credential=CLIENT_SECRET,
)

def get_app_access_token() -> str:
    """Get a token non-interactively via client credentials."""
    result = _app.acquire_token_silent(SCOPES, account=None)
    if not result or "access_token" not in result:
        result = _app.acquire_token_for_client(scopes=SCOPES)
    if "access_token" in result:
        return result["access_token"]
    raise RuntimeError(f"Unable to get app token: {result}")


def get_access_token_user():
    if not CLIENT_ID or not TENANT_ID:
        raise ValueError("CLIENT_ID_USER or TENANT_ID not set in .env file")

    app = msal.PublicClientApplication(CLIENT_ID, authority=AUTHORITY)
    flow = app.initiate_device_flow(scopes=SCOPES)

    if "user_code" not in flow:
        raise RuntimeError("Failed to create device flow. Check app registration and permissions.")

    print(f"\nPlease go to {flow['verification_uri']} and enter the code: {flow['user_code']}\n")

    result = app.acquire_token_by_device_flow(flow)
    if "access_token" in result:
        return result["access_token"]
    else:
        raise RuntimeError(f"Failed to get token: {result.get('error_description', 'Unknown error')}")
    
## AKIFLOW
def get_akiflow_api_key():
    # Load .env from secrets folder
    env_path = os.path.join(os.path.dirname(__file__), "secrets", ".env")
    load_dotenv(env_path)

    api_key = os.getenv("AKIFLOW_API_KEY")
    if not api_key:
        raise ValueError("AKIFLOW_API_KEY not set in secrets/.env")
    return api_key


## TODOIST
def get_todoist_api_token():
    env_path = os.path.join(os.path.dirname(__file__), "secrets", ".env")
    load_dotenv(env_path)

    token = os.getenv("TODOIST_API_TOKEN")
    if not token:
        raise ValueError("TODOIST_API_TOKEN not set in secrets/.env")
    return token

def get_todoist_session():
    """
    Returns a requests.Session with the
    Authorization and Content-Type headers set.
    """
    import requests

    token = get_todoist_api_token()
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    })
    return session