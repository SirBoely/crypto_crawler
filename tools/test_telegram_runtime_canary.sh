#!/usr/bin/env bash
set -euo pipefail

SCRIPT="${1:-tools/telegram_runtime_canary.sh}"
[ -f "$SCRIPT" ] || { echo "FAIL: missing $SCRIPT"; exit 1; }

bash -n "$SCRIPT"

grep -q 'TOKEN_VALUE_EMITTED=false' "$SCRIPT"
grep -q 'STATUS=TELEGRAM_RUNTIME_CANARY_GREEN' "$SCRIPT"
grep -q 'BTradesOperationsBot' "$SCRIPT"
grep -q 'chmod 600' "$SCRIPT"
grep -q 'getMe' "$SCRIPT"
grep -q 'getWebhookInfo' "$SCRIPT"
grep -q 'getUpdates' "$SCRIPT"
grep -q 'sendMessage' "$SCRIPT"

# Safety invariants: never print/source-dump the credential value.
if grep -En 'echo[[:space:]]+.*TELEGRAM_BOT_TOKEN|printf[^\n]*%s[^\n]*TELEGRAM_BOT_TOKEN|cat[[:space:]]+.*telegram\.env' "$SCRIPT"; then
  echo "FAIL: unsafe token output pattern detected"
  exit 1
fi

# No mutation against trading, exchange, payment, order, or pricing APIs.
if grep -Ein 'place.?order|create.?order|execute.?trade|withdraw|payment|update.?price|shopify' "$SCRIPT"; then
  echo "FAIL: unrelated mutating API pattern detected"
  exit 1
fi

echo "TELEGRAM_CANARY_TESTS=PASS"
echo "TOKEN_OUTPUT_SCAN=PASS"
echo "UNRELATED_WRITE_PATH_SCAN=PASS"
