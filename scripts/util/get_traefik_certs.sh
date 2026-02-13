#!/bin/bash

ACME_FILE="${DOCKERDIR}/appdata/traefik3/acme/acme.json"
GREEN='\033[0;32m'
BOLD_GREEN='\033[1;32m'
NC='\033[0m' # No Color

if ! [ -f "$ACME_FILE" ]; then
  echo "❌ acme.json not found at $ACME_FILE"
  exit 1
fi

jq -r '.[]?.Certificates[]? | [.domain.main, .certificate] | @tsv' "$ACME_FILE" | while IFS=$'\t' read -r domain cert_b64; do
  decoded_cert=$(echo "$cert_b64" | base64 -d 2>/dev/null)
  if [[ -z "$decoded_cert" ]]; then
    echo "⚠ Failed to decode certificate for domain: $domain"
    echo "---------------------------"
    continue
  fi

  subject=$(echo "$decoded_cert" | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject=CN =/Domain: /')
  not_before=$(echo "$decoded_cert" | openssl x509 -noout -startdate 2>/dev/null | sed 's/^notBefore=/notBefore: /')
  not_after=$(echo "$decoded_cert" | openssl x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=/notAfter: /')
  san=$(echo "$decoded_cert" | openssl x509 -noout -text 2>/dev/null \
    | awk '/X509v3 Subject Alternative Name/ {getline; gsub(/[[:space:]]+DNS:/, ""); gsub(/, DNS:/, ", "); print "SANs: " $0}')

  if [[ -n "$subject" && -n "$not_before" && -n "$not_after" ]]; then
    echo -e "${BOLD_GREEN}${subject}${NC}"
    echo "$not_before"
    echo "$not_after"
    if [[ -n "$san" ]]; then
      echo "$san"
    fi
    echo "---------------------------"
  else
    echo "⚠ Failed to parse certificate for domain: $domain"
    echo "---------------------------"
  fi
done
