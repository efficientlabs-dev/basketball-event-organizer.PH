#!/bin/bash
# ============================================
# Phantomz Network — Step 5: Verification
# Can run from anywhere with curl access
# ============================================

echo "=== PHANTOMZ NETWORK DEPLOYMENT VERIFICATION ==="

MATRIX_URL="https://matrix.phantomznetwork.xyz"
ELEMENT_URL="https://element.phantomznetwork.xyz"

# 1. Synapse API responding
echo ""
echo "--- Synapse API ---"
VERSIONS=$(curl -s "${MATRIX_URL}/_matrix/client/versions" 2>/dev/null)
if echo "$VERSIONS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Matrix versions: {len(d[\"versions\"])} supported')" 2>/dev/null; then
    echo "PASS: Synapse API responding"
else
    echo "FAIL: Synapse API not responding"
fi

# 2. Well-known endpoints
echo ""
echo "--- Well-Known ---"
curl -s "https://phantomznetwork.xyz/.well-known/matrix/client" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "WARN: Client well-known not found"
curl -s "https://phantomznetwork.xyz/.well-known/matrix/server" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "WARN: Server well-known not found"

# 3. Element Web loading
echo ""
echo "--- Element Web ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ELEMENT_URL" 2>/dev/null)
echo "Element Web HTTP status: $HTTP_CODE (should be 200)"

# 4. Login test
echo ""
echo "--- Login Test ---"
LOGIN_RESULT=$(curl -s -X POST "${MATRIX_URL}/_matrix/client/v3/login" \
    -H "Content-Type: application/json" \
    -d '{"type":"m.login.password","user":"Phantomz","password":"PhantomzAdmin2026!"}' 2>/dev/null)
echo "$LOGIN_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Login: {\"SUCCESS\" if \"access_token\" in d else \"FAILED: \" + d.get(\"error\",\"unknown\")}')" 2>/dev/null

# 5. Room count
echo ""
echo "--- Rooms ---"
TOKEN=$(echo "$LOGIN_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
if [ -n "$TOKEN" ]; then
    ROOM_COUNT=$(curl -s "${MATRIX_URL}/_matrix/client/v3/joined_rooms" \
        -H "Authorization: Bearer $TOKEN" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)['joined_rooms']))" 2>/dev/null)
    echo "Rooms joined: $ROOM_COUNT (should be 12 = 1 space + 11 rooms)"
fi

echo ""
echo "=== VERIFICATION COMPLETE ==="
echo ""
echo "Manual checks:"
echo "  [ ] ${ELEMENT_URL} shows Phantomz branding (not Element)"
echo "  [ ] Login page shows only username + password"
echo "  [ ] No server picker visible"
echo "  [ ] No 'Create account' link"
echo "  [ ] No email/phone fields"
echo "  [ ] After login, room list shows Phantomz Network space with 11 rooms"
echo "  [ ] 'Phantomz Dark' theme colors applied (#7B68EE accent)"
echo "  [ ] No 'Powered by Matrix' or Element logos visible"
