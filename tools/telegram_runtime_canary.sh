#!/usr/bin/env bash
set -euo pipefail

SECRET_FILE="${BTRADES_TELEGRAM_SECRET_FILE:-$HOME/.config/btrades-secrets/telegram.env}"
EXPECTED_USERNAME="${BTRADES_TELEGRAM_EXPECTED_USERNAME:-BTradesOperationsBot}"
CANARY_TEXT="${BTRADES_TELEGRAM_CANARY_TEXT:-✅ B-Trades Operations Bot — security canary PASS}"

fail() {
  printf 'STATUS=TELEGRAM_RUNTIME_CANARY_FAIL\nREASON=%s\n' "$1" >&2
  exit 1
}

command -v curl >/dev/null 2>&1 || fail "curl_missing"
command -v jq >/dev/null 2>&1 || fail "jq_missing"

[ -f "$SECRET_FILE" ] || fail "secret_file_missing"
chmod 600 "$SECRET_FILE"

# shellcheck disable=SC1090
set -a
source "$SECRET_FILE"
set +a

[ -n "${TELEGRAM_BOT_TOKEN:-}" ] || fail "telegram_bot_token_missing"

cleanup() {
  unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID_DEBUG CHAT_ID WEBHOOK_URL || true
}
trap cleanup EXIT

telegram_get() {
  local method="$1"
  local target="$2"
  printf 'url = "https://api.telegram.org/bot%s/%s"\nsilent\nshow-error\nfail-with-body\n' \
    "$TELEGRAM_BOT_TOKEN" "$method" | curl --config - > "$target"
}

printf '=== B-TRADES TELEGRAM RUNTIME CANARY ===\n'
printf 'SECRET_FILE_PERMISSION='
stat -c '%a' "$SECRET_FILE"
printf 'TELEGRAM_BOT_TOKEN=[REDACTED]\n'

TMP_GETME="$(mktemp)"
TMP_WEBHOOK="$(mktemp)"
TMP_UPDATES="$(mktemp)"
TMP_SEND="$(mktemp)"
TMP_ENV=""
chmod 600 "$TMP_GETME" "$TMP_WEBHOOK" "$TMP_UPDATES" "$TMP_SEND"
trap 'rm -f "$TMP_GETME" "$TMP_WEBHOOK" "$TMP_UPDATES" "$TMP_SEND" "${TMP_ENV:-}"; cleanup' EXIT

telegram_get "getMe" "$TMP_GETME" || fail "getMe_request_failed"
AUTH_OK="$(jq -r '.ok // false' "$TMP_GETME")"
USERNAME="$(jq -r '.result.username // empty' "$TMP_GETME")"
BOT_ID="$(jq -r '.result.id // empty' "$TMP_GETME")"

printf 'API_AUTH=%s\n' "$AUTH_OK"
printf 'BOT_USERNAME=@%s\n' "$USERNAME"
printf 'BOT_ID=%s\n' "$BOT_ID"

[ "$AUTH_OK" = "true" ] || fail "bot_auth_failed"
[ "$USERNAME" = "$EXPECTED_USERNAME" ] || fail "unexpected_bot_identity"
printf 'BOT_IDENTITY=PASS\n'

telegram_get "getWebhookInfo" "$TMP_WEBHOOK" || fail "getWebhookInfo_request_failed"
WEBHOOK_URL="$(jq -r '.result.url // empty' "$TMP_WEBHOOK")"
if [ -n "$WEBHOOK_URL" ]; then
  printf 'WEBHOOK=CONFIGURED\n'
  fail "webhook_active_getUpdates_not_safe"
fi
printf 'WEBHOOK=NONE\n'

telegram_get "getUpdates?limit=50&timeout=0" "$TMP_UPDATES" || fail "getUpdates_request_failed"
UPDATES_OK="$(jq -r '.ok // false' "$TMP_UPDATES")"
CHAT_ID="$(jq -r '[.result[] | .message? | select(.chat.type == "private") | .chat.id] | last // empty' "$TMP_UPDATES")"
printf 'GET_UPDATES=%s\n' "$UPDATES_OK"
[ "$UPDATES_OK" = "true" ] || fail "getUpdates_failed"
[ -n "$CHAT_ID" ] || fail "private_chat_not_found_send_start_first"
printf 'PRIVATE_CHAT=FOUND\n'

TMP_ENV="$(mktemp)"
chmod 600 "$TMP_ENV"
grep -v '^TELEGRAM_CHAT_ID_DEBUG=' "$SECRET_FILE" > "$TMP_ENV" || true
printf 'TELEGRAM_CHAT_ID_DEBUG=%q\n' "$CHAT_ID" >> "$TMP_ENV"
mv "$TMP_ENV" "$SECRET_FILE"
TMP_ENV=""
chmod 600 "$SECRET_FILE"
printf 'PRIVATE_CHAT_BINDING=PASS\n'

printf 'url = "https://api.telegram.org/bot%s/sendMessage"\nsilent\nshow-error\nfail-with-body\n' \
  "$TELEGRAM_BOT_TOKEN" \
  | curl --config - \
      --request POST \
      --data-urlencode "chat_id=$CHAT_ID" \
      --data-urlencode "text=$CANARY_TEXT" \
      > "$TMP_SEND" || fail "sendMessage_request_failed"

SEND_OK="$(jq -r '.ok // false' "$TMP_SEND")"
MESSAGE_ID="$(jq -r '.result.message_id // empty' "$TMP_SEND")"
[ "$SEND_OK" = "true" ] || fail "sendMessage_failed"
[ -n "$MESSAGE_ID" ] || fail "message_id_missing"

printf 'SEND_MESSAGE=PASS\n'
printf 'MESSAGE_CREATED=YES\n'
printf 'BOT_AUTH=PASS\n'
printf 'BOT_IDENTITY=PASS\n'
printf 'DELIVERY_CANARY=PASS\n'
printf 'SECRET_STORAGE=PASS\n'
printf 'TOKEN_VALUE_EMITTED=false\n'
printf 'STATUS=TELEGRAM_RUNTIME_CANARY_GREEN\n'
