#!/usr/bin/env bash
# =============================================================================
# signal-collect.sh — Lightweight signal collection
# =============================================================================
# Runs every 6h via systemd timer. Pulls recent incidents from Uptime Kuma
# and Docker events (die, oom) from the last 24h.
#
# Output: /opt/auditor/signals/YYYY-MM-DD.json (appended)
set -euo pipefail

SIGNALS_DIR="/opt/auditor/signals"
LOG_PREFIX="[$(date +%Y-%m-%dT%H:%M:%S)]"
TODAY=$(date +%Y-%m-%d)
OUTPUT_FILE="${SIGNALS_DIR}/${TODAY}.json"

SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -p 2222"
DOCKER_HOSTS="databases:192.168.1.58 services:192.168.1.59"
UPTIME_KUMA_URL="http://192.168.1.59:3001"

mkdir -p "$SIGNALS_DIR"

echo "$LOG_PREFIX Starting signal collection..."

# Initialize today's file if it doesn't exist
if [ ! -f "$OUTPUT_FILE" ]; then
    echo '{"signals": []}' > "$OUTPUT_FILE"
fi

TIMESTAMP=$(date -Iseconds)
SIGNALS="[]"

# =============================================================================
# Uptime Kuma — Recent incidents (public status page API)
# =============================================================================
echo "$LOG_PREFIX Checking Uptime Kuma..."
KUMA_STATUS=$(curl -sf --max-time 10 "${UPTIME_KUMA_URL}/api/status-page/heartbeat/default" 2>/dev/null) || KUMA_STATUS=""

if [ -n "$KUMA_STATUS" ]; then
    # Extract any monitors that are down
    DOWN_MONITORS=$(echo "$KUMA_STATUS" | jq -r '
        [.heartbeatList // {} | to_entries[] |
         select(.value[-1].status == 0) |
         {monitor_id: .key, status: "down"}] // []' 2>/dev/null) || DOWN_MONITORS="[]"

    if [ "$DOWN_MONITORS" != "[]" ]; then
        SIGNALS=$(echo "$SIGNALS" | jq --argjson monitors "$DOWN_MONITORS" \
            '. + [{"type": "uptime_kuma_down", "timestamp": "'"$TIMESTAMP"'", "monitors": $monitors}]')
    fi
else
    SIGNALS=$(echo "$SIGNALS" | jq \
        '. + [{"type": "uptime_kuma_unreachable", "timestamp": "'"$TIMESTAMP"'"}]')
fi

# =============================================================================
# Docker Events — die, oom, kill from last 24h
# =============================================================================
SINCE="24h"

for target in $DOCKER_HOSTS; do
    name="${target%%:*}"
    host="${target##*:}"
    echo "$LOG_PREFIX Checking Docker events on $name..."

    EVENTS=$(ssh $SSH_OPTS "root@${host}" \
        "docker events --since ${SINCE} --until 0s --filter event=die --filter event=oom --format '{{json .}}'" 2>/dev/null | head -100) || {
        echo "$LOG_PREFIX WARNING: Failed to get Docker events from $name"
        SIGNALS=$(echo "$SIGNALS" | jq \
            '. + [{"type": "docker_events_unreachable", "timestamp": "'"$TIMESTAMP"'", "host": "'"$name"'"}]')
        continue
    }

    if [ -n "$EVENTS" ]; then
        EVENT_COUNT=$(echo "$EVENTS" | wc -l)
        # Extract container names from events
        CONTAINERS=$(echo "$EVENTS" | jq -r '.Actor.Attributes.name // "unknown"' 2>/dev/null | sort | uniq -c | sort -rn | head -10)
        SIGNALS=$(echo "$SIGNALS" | jq \
            --arg host "$name" \
            --arg count "$EVENT_COUNT" \
            --arg containers "$CONTAINERS" \
            '. + [{"type": "docker_events", "timestamp": "'"$TIMESTAMP"'", "host": $host, "event_count": ($count | tonumber), "top_containers": $containers}]')
    fi
done

# =============================================================================
# Write signals to today's file
# =============================================================================
if [ "$SIGNALS" != "[]" ]; then
    # Append new signals to existing file
    EXISTING=$(cat "$OUTPUT_FILE")
    echo "$EXISTING" | jq --argjson new "$SIGNALS" '.signals += $new' > "${OUTPUT_FILE}.tmp"
    mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
    echo "$LOG_PREFIX Collected $(echo "$SIGNALS" | jq 'length') new signals → ${OUTPUT_FILE}"
else
    echo "$LOG_PREFIX No new signals detected."
fi

echo "$LOG_PREFIX Signal collection complete."
