#!/bin/bash


source ./.env
# The following keys need to be defined in the .env file in the same directory
# PUSH_USER_KEY=key
# PUSH_BASH_API_TOKEN=token

# Usage: script-name "title" "message-body"

curl -s \
-F "user=$PUSH_USER_KEY" \
-F "token=$PUSH_BASH_API_TOKEN" \
-F 'title=$1' \
-F "message=$2" \
https://api.pushover.net/1/messages.json