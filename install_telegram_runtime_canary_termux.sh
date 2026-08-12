#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

REPO_DIR="${1:-$(pwd)}"
SCRIPT="$REPO_DIR/tools/telegram_runtime_canary.sh"
DEV_DIR="$HOME/.jarvis_voice/dev_commands"
COMMAND="$DEV_DIR/jarvis-telegram-canary"

[ -f "$SCRIPT" ] || {
  echo "FAIL: $SCRIPT ontbreekt"
  echo "Voer dit script uit vanuit de crypto_crawler repository of geef het repo-pad mee."
  exit 1
}

pkg install -y curl jq >/dev/null
mkdir -p "$DEV_DIR"
chmod 700 "$DEV_DIR"
chmod +x "$SCRIPT"
ln -sf "$SCRIPT" "$COMMAND"
chmod +x "$COMMAND"

if [ -w "$PREFIX/bin" ]; then
  ln -sf "$COMMAND" "$PREFIX/bin/jarvis-telegram-canary"
fi

echo "STATUS=TELEGRAM_CANARY_COMMAND_INSTALLED"
echo "COMMAND=$COMMAND"
echo "RUN=jarvis-telegram-canary"
echo "SECRET_FILE=$HOME/.config/btrades-secrets/telegram.env"
