#!/bin/bash
# ============================================
# Phantomz Network — Step 3: Create Room Structure
# Can run from anywhere with curl access
# ============================================

set -euo pipefail

MATRIX_URL="https://matrix.phantomznetwork.xyz"
ADMIN_USER="Phantomz"
ADMIN_PASS="PhantomzAdmin2026!"

echo "=== Phantomz Network Room Setup ==="

# Get admin access token
echo "[1/3] Logging in as @${ADMIN_USER}..."
LOGIN_RESPONSE=$(curl -s -X POST "${MATRIX_URL}/_matrix/client/v3/login" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"m.login.password\",\"user\":\"${ADMIN_USER}\",\"password\":\"${ADMIN_PASS}\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
if [ -z "$TOKEN" ]; then
    echo "FAILED: Could not get access token"
    echo "$LOGIN_RESPONSE"
    exit 1
fi
echo "Login successful."

# Create the Space
echo ""
echo "[2/3] Creating Phantomz Network Space..."
SPACE_RESPONSE=$(curl -s -X POST "${MATRIX_URL}/_matrix/client/v3/createRoom" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Phantomz Network",
        "topic": "The underground network for sovereign minds \u2014 master money, privacy, health, and freedom.",
        "preset": "public_chat",
        "creation_content": {"type": "m.space"},
        "initial_state": [
            {"type": "m.room.guest_access", "content": {"guest_access": "forbidden"}},
            {"type": "m.room.history_visibility", "content": {"history_visibility": "shared"}}
        ]
    }')

SPACE_ID=$(echo "$SPACE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('room_id','FAILED'))" 2>/dev/null)
if [ "$SPACE_ID" = "FAILED" ]; then
    echo "Space creation failed (may already exist):"
    echo "$SPACE_RESPONSE"
    echo "Enter existing Space ID manually (or press Enter to skip):"
    read -r SPACE_ID
    if [ -z "$SPACE_ID" ]; then
        echo "Skipping space child assignments."
        SPACE_ID=""
    fi
else
    echo "Space created: $SPACE_ID"
fi

# Room creation function
create_room() {
    local ALIAS=$1
    local NAME=$2
    local TOPIC=$3
    local EVENTS_DEFAULT=$4
    local ENCRYPT=$5
    local ORDER=$6

    local INITIAL_STATE='[
        {"type":"m.room.guest_access","content":{"guest_access":"forbidden"}},
        {"type":"m.room.history_visibility","content":{"history_visibility":"shared"}}'

    if [ "$ENCRYPT" = "true" ]; then
        INITIAL_STATE="${INITIAL_STATE},
        {\"type\":\"m.room.encryption\",\"content\":{\"algorithm\":\"m.megolm.v1.aes-sha2\"}}"
    fi

    INITIAL_STATE="${INITIAL_STATE}]"

    local ROOM_RESPONSE=$(curl -s -X POST "${MATRIX_URL}/_matrix/client/v3/createRoom" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"room_alias_name\": \"$ALIAS\",
            \"name\": \"$NAME\",
            \"topic\": \"$TOPIC\",
            \"preset\": \"public_chat\",
            \"power_level_content_override\": {
                \"events_default\": $EVENTS_DEFAULT,
                \"users_default\": 0,
                \"state_default\": 50,
                \"ban\": 50,
                \"kick\": 50,
                \"redact\": 50,
                \"invite\": 0
            },
            \"initial_state\": $INITIAL_STATE
        }")

    local ROOM_ID=$(echo "$ROOM_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('room_id','FAILED'))" 2>/dev/null)
    echo "  #$ALIAS → $ROOM_ID"

    # Add room to Space
    if [ "$ROOM_ID" != "FAILED" ] && [ -n "$SPACE_ID" ]; then
        curl -s -X PUT "${MATRIX_URL}/_matrix/client/v3/rooms/$SPACE_ID/state/m.space.child/$ROOM_ID" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"via\":[\"phantomznetwork.xyz\"],\"suggested\":true,\"order\":\"$ORDER\"}" > /dev/null
    fi

    # Invite QueenKaay
    if [ "$ROOM_ID" != "FAILED" ]; then
        curl -s -X POST "${MATRIX_URL}/_matrix/client/v3/rooms/$ROOM_ID/invite" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"user_id": "@QueenKaay:phantomznetwork.xyz"}' > /dev/null
    fi
}

echo ""
echo "[3/3] Creating rooms..."

create_room "gateway" "Gateway" "Verification and onboarding. Start here." 50 "false" "01"
create_room "rules" "Rules" "Network rules and guidelines. Read before participating." 100 "false" "02"
create_room "announcements" "Announcements" "Official Phantomz Network announcements." 50 "false" "03"
create_room "global-news" "Global News" "Curated news from around the world. Auto-posted by ContentBot." 50 "false" "04"
create_room "lounge" "The Lounge" "Main community hangout. Be cool, be real." 0 "true" "05"
create_room "money" "Money Moves" "Wealth building, crypto, investing, and financial sovereignty." 0 "true" "06"
create_room "opsec" "OPSEC" "Privacy, security, and operational security discussion." 0 "true" "07"
create_room "signals" "Signals" "Trading signals and market analysis. Bot-posted." 50 "false" "08"
create_room "marketplace" "Marketplace" "Buy, sell, and trade. XMR accepted." 0 "true" "09"
create_room "promo" "Promo" "Promote your projects. One post per day limit." 0 "false" "10"
create_room "game-room" "Game Room" "Games, challenges, and entertainment." 0 "false" "11"

# Invite QueenKaay to Space too
if [ -n "$SPACE_ID" ]; then
    curl -s -X POST "${MATRIX_URL}/_matrix/client/v3/rooms/$SPACE_ID/invite" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"user_id": "@QueenKaay:phantomznetwork.xyz"}' > /dev/null
    echo "  Invited @QueenKaay to Space"
fi

echo ""
echo "=== Room Setup Complete ==="
echo "All 11 rooms created and added to Phantomz Network Space."
echo "@QueenKaay invited to all rooms."
