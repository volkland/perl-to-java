#!/bin/bash

curl localhost:8099/hello
echo ""
curl localhost:8080/java-war/health
echo ""

json_payload_perl_only_method=$(cat <<EOF
{
    "jsonrpc": "1.1",
    "id": "42",
    "method": "getTnbList",
    "params": {
        "number": "V001"
    },
    "by-the-way": "this is a call from a e2e test"
}
EOF
)

curl -X POST "localhost:8099/jsonrpc" \
     -H "Content-Type: application/json, charset=utf-8" \
     -d "$json_payload_perl_only_method"

echo ""

json_payload_java_only_method=$(cat <<EOF
{
    "jsonrpc": "1.1",
    "id": "42",
    "method": "javaTest",
    "params": {
        "id": 1,
        "name": "acul",
        "temperatureOver20Degree": true
    },
    "by-the-way": "this is a call from a e2e test"
}
EOF
)

curl -X POST "localhost:8099/jsonrpc" \
     -H "Content-Type: application/json, charset=utf-8" \
     -d "$json_payload_java_only_method"

