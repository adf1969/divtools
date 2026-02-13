# Utility for managing OPNsense WireGuard peers via API; format peer config as .conf on -pc
# Last Updated: 10/29/2025 10:24:00 AM CDT
#!/bin/bash

# Load environment and helper functions
source "$DIVTOOLS/dotfiles/.bash_profile"
load_env_files

# Load logging utility (uses log "<LEVEL>" "message")
source "$DIVTOOLS/scripts/util/logging.sh"

# Defaults
DEBUG_MODE=0
TEST_MODE=0

export OPNSENSE_ROUTER_IP=10.4.0.1
export OPNSENSE_API_KEY=4rLQ6xJJJrtKqft6MSL48ItlBWLaz16K6IJqFEspzud+686tbeausddxs3ftuqIgLqf6COaIViriYAMx
export OPNSENSE_API_SECRET=tC146rSHzU612xQsImt1uq9IcyIli83spT4O6BngvMZ6EV8rGzJ2lHpMTvTUTvFzY1C4TqoFgLhom0kq


# Helper: mask secrets for debug output
mask_secret() {
  local s="$1"
  local len=${#s}
  if (( len <= 4 )); then
    echo "****"
  else
    echo "${s:0:2}***${s: -2}"
  fi
}

# Wrapper to run or stub curl calls (logs actions when in test/debug)
# Usage: run_curl <array_name> [capture] [suppress_errors]
run_curl() {
  local -n _cmd_ref=$1   # array name passed by caller
  local capture=${2:-}       # if "capture" then capture and echo output
  local suppress=${3:-0}     # if 1 then don't log curl errors for this attempt
  local cmd_str
  printf -v cmd_str "%q " "${_cmd_ref[@]}"

  if [[ $DEBUG_MODE -eq 1 ]]; then
    log "DEBUG" "Curl command: $cmd_str"
    log "DEBUG" "API_BASE: $API_BASE"
    log "DEBUG" "API_KEY: $(mask_secret "$OPNSENSE_API_KEY")"
  fi

  if [[ $TEST_MODE -eq 1 ]]; then
    log "TEST" "Would run: $cmd_str"
    return 0
  fi

  if [[ "$capture" == "capture" ]]; then
    local out
    out="$("${_cmd_ref[@]}" 2>/dev/null)"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
      if [[ $suppress -eq 0 ]]; then
        log "ERROR" "Curl failed (rc=$rc) for: $cmd_str"
      else
        [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Suppressed curl error (rc=$rc) for: $cmd_str"
      fi
      return $rc
    fi
    # Print captured output via logging (INFO)
    log "INFO" "$out"
    return 0
  else
    "${_cmd_ref[@]}" 2>/dev/null
    local rc=$?
    if [[ $rc -ne 0 && $suppress -eq 0 ]]; then
      log "ERROR" "Curl failed (rc=$rc) for: $cmd_str"
    elif [[ $rc -ne 0 && $suppress -eq 1 && $DEBUG_MODE -eq 1 ]]; then
      log "DEBUG" "Suppressed curl error (rc=$rc) for: $cmd_str"
    fi
    return $rc
  fi
}

# Validate required env vars (expects they may be set by load_env_files)
: "${OPNSENSE_ROUTER_IP:=10.4.0.1}"
: "${OPNSENSE_API_KEY:=}"
: "${OPNSENSE_API_SECRET:=}"

if [[ -z "$OPNSENSE_ROUTER_IP" || -z "$OPNSENSE_API_KEY" || -z "$OPNSENSE_API_SECRET" ]]; then
  log "ERROR" "Required environment variables not set. Ensure OPNSENSE_ROUTER_IP, OPNSENSE_API_KEY, and OPNSENSE_API_SECRET are defined."
  exit 1
fi

API_BASE="https://$OPNSENSE_ROUTER_IP/api/wireguard/client"

usage() {
  cat <<EOF
Usage: $(basename "$0") [flags] <command> [args]

Flags:
  -d | -debug     Enable debug output
  -t | -test      Test mode (stub permanent actions)

Commands:
  -lsp | -ls-peers           List WireGuard peers
  -pc  | -peer-conf <uuid>   Get peer config by UUID (prints .conf format)

Examples:
  $(basename "$0") -d -lsp
  $(basename "$0") -t -pc 0123-uuid-456

EOF
  exit 1
}

# First pass: collect and strip global flags (-d/-debug, -t/-test)
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|-debug) DEBUG_MODE=1; shift ;;
    -t|-test)  TEST_MODE=1; shift ;;
    -h|--help) usage ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]}"

# Functions for API actions
list_peers() {
  local cmd=(curl -s -k -u "${OPNSENSE_API_KEY}:${OPNSENSE_API_SECRET}" -X POST "${API_BASE}/search_client" -H "Content-Type: application/json" -d '{"current":1,"rowCount":-1,"sort":{"name":"asc"},"searchPhrase":""}')
  run_curl cmd capture
}

# Render a WireGuard .conf from JSON response (handles {"client":{...}} responses)
# Last Updated: 10/29/2025 11:55:00 AM CDT
format_wireguard_conf() {
  local json="$1"

  # If jq is available, parse robustly
  if command -v jq >/dev/null 2>&1; then
    # If API returned a "client" object (OPNsense wireguard plugin), extract fields
    if printf '%s\n' "$json" | jq -e '.client' >/dev/null 2>&1; then
      local addr pub_client psk keep serverport endpoint server_name keepalive

      # Address: find selected tunneladdress key or first key
      addr=$(printf '%s\n' "$json" | jq -r 'try (.client.tunneladdress | to_entries[] | select(.value.selected==1).key) // (.client.tunneladdress | keys[0]) // empty' 2>/dev/null)

      pub_client=$(printf '%s\n' "$json" | jq -r '.client.pubkey // empty' 2>/dev/null)
      psk=$(printf '%s\n' "$json" | jq -r '.client.psk // empty' 2>/dev/null)
      keepalive=$(printf '%s\n' "$json" | jq -r '.client.keepalive // empty' 2>/dev/null)
      serverport=$(printf '%s\n' "$json" | jq -r '.client.serverport // empty' 2>/dev/null)
      endpoint=$(printf '%s\n' "$json" | jq -r '.client.endpoint // empty' 2>/dev/null)
      # servers -> pick selected server value if present
      server_name=$(printf '%s\n' "$json" | jq -r 'try (.client.servers | to_entries[] | select(.value.selected==1).value.value) // empty' 2>/dev/null)
      # server host may not be present; leave placeholder if missing
      local endpoint_str=""
      if [[ -n "$endpoint" ]]; then
        endpoint_str="$endpoint"
        [[ -n "$serverport" ]] && endpoint_str="${endpoint_str}:${serverport}"
      elif [[ -n "$server_name" && -n "$serverport" ]]; then
        endpoint_str="${server_name}:${serverport}"
      fi

      # Interface block
      echo "[Interface]"
      # PrivateKey is not returned by OPNsense API for security; emit placeholder comment
      echo "# PrivateKey = <private key not provided by API>"
      [[ -n "$psk" ]] && echo "# PresharedKey (if used) = $psk"
      [[ -n "$addr" ]] && echo "Address = $addr"
      echo

      # Peer block: we don't have server public key in the client object; place placeholders
      echo "[Peer]"
      echo "# PublicKey = <server-public-key-here>    # server public key not provided by API"
      if [[ -n "$endpoint_str" ]]; then
        echo "Endpoint = $endpoint_str"
      else
        echo "# Endpoint = <server-host>:<port>        # not returned by API"
      fi
      # AllowedIPs should include the tunnel address
      if [[ -n "$addr" ]]; then
        echo "AllowedIPs = $addr"
      else
        echo "AllowedIPs = 0.0.0.0/0"
      fi
      if [[ -n "$keepalive" && "$keepalive" != "0" ]]; then
        echo "PersistentKeepalive = $keepalive"
      fi

      # If client pubkey present, print a comment to help map roles
      if [[ -n "$pub_client" ]]; then
        echo
        echo "# Note: this client reports its own public key below (for reference)"
        echo "# ClientPublicKey = $pub_client"
      fi

      return 0
    fi
  fi

  # Fallback generic extraction (best-effort) if structure differs or jq not available
  # Try to find tunneladdress key/value
  local addr_f pub_f keep_f
  addr_f=$(echo "$json" | grep -oP '"tunneladdress"\s*:\s*\{\s*"\K[^"]+' 2>/dev/null | head -n1)
  [[ -z "$addr_f" ]] && addr_f=$(echo "$json" | grep -oP '"address"\s*:\s*"\K[^"]+' 2>/dev/null | head -n1)
  pub_f=$(echo "$json" | grep -oP '"pubkey"\s*:\s*"\K[^"]+' 2>/dev/null | head -n1)
  keep_f=$(echo "$json" | grep -oP '"keepalive"\s*:\s*"\K[^"]+' 2>/dev/null | head -n1)

  echo "[Interface]"
  echo "# PrivateKey = <private key not provided by API>"
  [[ -n "$addr_f" ]] && echo "Address = $addr_f"
  echo

  echo "[Peer]"
  echo "# PublicKey = <server-public-key-here>"
  if [[ -n "$addr_f" ]]; then
    echo "AllowedIPs = $addr_f"
  else
    echo "AllowedIPs = 0.0.0.0/0"
  fi
  [[ -n "$keep_f" ]] && echo "PersistentKeepalive = $keep_f"

  # If nothing parsed, print raw JSON as last resort
  if [[ -z "$addr_f" && -z "$pub_f" && -z "$keep_f" ]]; then
    log "WARN" "Unable to render .conf from response; printing raw JSON"
    echo "$json"
  fi

  return 0
}

# Attempt multiple possible endpoints / methods to retrieve a peer config
# Last Updated: 10/29/2025 10:24:00 AM CDT
get_peer_conf() {
  local peer_id="$1"
  if [[ -z "$peer_id" ]]; then
    log "ERROR" "Peer ID (UUID) required for -pc / -peer-conf"
    return 1
  fi

  # Candidate endpoints (path suffix)|METHOD|PAYLOAD
  local -a paths=(
    "getConfig/${peer_id}|GET|"
    "getClient/${peer_id}|GET|"
    "getClientConfig/${peer_id}|GET|"
    "getConfigClient/${peer_id}|GET|"
    "peer/getConfig/${peer_id}|GET|"
    "peer/getClient/${peer_id}|GET|"
    "peer/getClientConfig/${peer_id}|GET|"
    "getConfig?uuid=${peer_id}|GET|"
    "getClient?uuid=${peer_id}|GET|"
    "getClientConfig?uuid=${peer_id}|GET|"
    "getConfig|POST|{\"uuid\":\"${peer_id}\"}"
    "getClient|POST|{\"uuid\":\"${peer_id}\"}"
    "getClientConfig|POST|{\"uuid\":\"${peer_id}\"}"
  )

  local tried_any=0
  for entry in "${paths[@]}"; do
    IFS='|' read -r suffix method payload <<< "$entry"
    local url="${API_BASE}/${suffix}"
    local cmd_arr
    if [[ "$method" == "POST" ]]; then
      cmd_arr=(curl -s -k -u "${OPNSENSE_API_KEY}:${OPNSENSE_API_SECRET}" -X POST "$url" -H "Content-Type: application/json" -d "$payload")
    else
      cmd_arr=(curl -s -k -u "${OPNSENSE_API_KEY}:${OPNSENSE_API_SECRET}" "$url")
    fi

    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Trying endpoint: $url (method=$method)"

    if [[ $TEST_MODE -eq 1 ]]; then
      log "TEST" "Would run: ${cmd_arr[*]}"
      tried_any=1
      continue
    fi

    # Execute and capture response for inspection
    local out
    out="$("${cmd_arr[@]}" 2>/dev/null)"
    local rc=$?
    tried_any=1

    if [[ $rc -ne 0 ]]; then
      [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Curl returned rc=$rc for $url"
      continue
    fi

    # If response contains an API-level error, treat as failure and try next candidate
    if printf '%s\n' "$out" | grep -q '"errorMessage"' 2>/dev/null || printf '%s\n' "$out" | grep -q '"error"' 2>/dev/null; then
      [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Endpoint returned error JSON for $url: $out"
      continue
    fi

    # Successful-looking response: render .conf and print it
    if [[ $DEBUG_MODE -eq 1 ]]; then
      log "DEBUG" "Successful response from $url; rendering .conf"
    fi

    format_wireguard_conf "$out"
    return 0
  done

  if [[ $tried_any -eq 0 ]]; then
    log "ERROR" "No endpoints to try for peer config"
    return 2
  fi

  # If we reach here, all candidates failed
  log "ERROR" "All probe endpoints failed for peer ${peer_id}. Run with -d to see attempts."
  return 3
}

# No command => usage
if [[ $# -lt 1 ]]; then
  usage
fi

# Dispatch command
case "$1" in
  -lsp|-ls-peers)
    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Running list_peers()"
    list_peers
    ;;
  -pc|-peer-conf)
    [[ $DEBUG_MODE -eq 1 ]] && log "DEBUG" "Running get_peer_conf() for: $2"
    get_peer_conf "$2"
    ;;
  *)
    log "ERROR" "Unknown command: $1"
    usage
    ;;
esac