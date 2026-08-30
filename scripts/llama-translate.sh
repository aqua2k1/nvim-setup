#!/usr/bin/env bash
# Prepare the Hy-MT2 model and install the system-managed translation service.
# Usage: ./scripts/llama-translate.sh
set -euo pipefail

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "error: run this script without sudo; it elevates only service installation" >&2
    exit 1
fi

if ! LLAMA_SERVER="$(which llama-server 2>/dev/null)" || [ -z "$LLAMA_SERVER" ]; then
    echo "error: llama-server not found in PATH" >&2
    echo "Install llama.cpp with this machine's package manager, then rerun this script." >&2
    exit 1
fi

for command in curl python3 sha256sum; do
    if ! which "$command" >/dev/null 2>&1; then
        echo "error: required command not found: $command" >&2
        exit 1
    fi
done

USERNAME="$(id -un)"
USER_HOME="$(python3 -c 'import os, pwd; print(pwd.getpwuid(os.getuid()).pw_dir)')"
EXPECTED_HOME="/home/$USERNAME"
if [ "$USER_HOME" != "$EXPECTED_HOME" ]; then
    echo "error: expected home $EXPECTED_HOME, got $USER_HOME" >&2
    exit 1
fi

MODEL_DIR="$USER_HOME/models"
MODEL_PATH="$MODEL_DIR/Hy-MT2-1.8B-Q4_K_M.gguf"
MODEL_SHA256="dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699"
MODEL_URL="https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF/resolve/main/Hy-MT2-1.8B-Q4_K_M.gguf?download=true"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PART=""

cleanup() {
    if [ -n "$PART" ]; then
        rm -f -- "$PART"
    fi
}
trap cleanup EXIT

printf 'llama-server: %s\n' "$LLAMA_SERVER"

mkdir -p -- "$MODEL_DIR"
if [ -s "$MODEL_PATH" ]; then
    printf '%s  %s\n' "$MODEL_SHA256" "$MODEL_PATH" | sha256sum --check --status || {
        echo "error: existing model checksum mismatch: $MODEL_PATH" >&2
        exit 1
    }
    printf 'model already present and verified: %s\n' "$MODEL_PATH"
else
    PART="$(mktemp "$MODEL_DIR/.Hy-MT2-1.8B-Q4_K_M.gguf.XXXXXX.part")"
    printf 'downloading model to %s\n' "$MODEL_PATH"
    curl --fail --location --retry 3 --output "$PART" "$MODEL_URL"
    if [ ! -s "$PART" ]; then
        echo "error: downloaded model is empty" >&2
        exit 1
    fi
    printf '%s  %s\n' "$MODEL_SHA256" "$PART" | sha256sum --check --status || {
        echo "error: downloaded model checksum mismatch" >&2
        exit 1
    }
    chmod 0644 "$PART"
    mv -- "$PART" "$MODEL_PATH"
    PART=""
fi

exec python3 "$SCRIPT_DIR/llama-translate-service.py" install "$@"
