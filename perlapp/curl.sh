#!/bin/bash

# Define the JSON payload
json_payload=$(cat <<EOF
{
    "jsonrpc": "1.1",
    "id": "42",
    "method": "getTnbList",
    "params": {
        "number": 1
    },
    "by-the-way": "this is a call from a e2e test"
}
EOF
)

# Define the URL to which you want to send the request
url="http://localhost:13360/jsonrpc"  # Replace with the actual URL

# Send the POST request using curl
curl -X POST "$url" \
     -H "Content-Type: application/json, charset=utf-8" \
     -d "$json_payload"