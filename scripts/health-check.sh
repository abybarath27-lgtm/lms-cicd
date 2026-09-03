#!/bin/bash

set -e

LMS_URL="${LMS_URL:-http://172.31.8.158}"

MAX_ATTEMPTS=12
SLEEP_SECONDS=5

echo "========================================"
echo "LMS Health Check"
echo "URL: $LMS_URL"
echo "========================================"

for ((i=1; i<=MAX_ATTEMPTS; i++))
do
    echo "Attempt $i/$MAX_ATTEMPTS..."

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time 15 \
        "$LMS_URL" || true)

    echo "HTTP Status: $HTTP_CODE"

    if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]] || \
       [[ "$HTTP_CODE" =~ ^3[0-9][0-9]$ ]]; then

        echo "LMS HEALTH CHECK PASSED"
        exit 0
    fi

    if [ "$i" -lt "$MAX_ATTEMPTS" ]; then
        echo "Waiting ${SLEEP_SECONDS}s..."
        sleep "$SLEEP_SECONDS"
    fi
done

echo "LMS HEALTH CHECK FAILED"
exit 1