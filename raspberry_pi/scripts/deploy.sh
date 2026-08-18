#!/bin/sh
set -eu

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 SSH_USER SSH_HOST BIND_HOST_OR_AUTO [REMOTE_MODEL_DIR]" >&2
  exit 2
fi

SSH_USER=$1
SSH_HOST=$2
BIND_HOST=$3
REMOTE_MODEL_DIR=${4:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REMOTE_STAGE="/tmp/ai-blind-assistant-deploy-$(date +%Y%m%d-%H%M%S)"

# Host-key verification and normal SSH authentication remain enabled.
ssh -o BatchMode=yes "$SSH_USER@$SSH_HOST" "mkdir -m 0700 '$REMOTE_STAGE'"
scp -r "$SOURCE_ROOT"/. "$SSH_USER@$SSH_HOST:$REMOTE_STAGE/"

if [ -n "$REMOTE_MODEL_DIR" ]; then
  ssh -t "$SSH_USER@$SSH_HOST" \
    "sudo '$REMOTE_STAGE/scripts/install.sh' --bind-host '$BIND_HOST' --model-source '$REMOTE_MODEL_DIR' --start"
else
  ssh -t "$SSH_USER@$SSH_HOST" \
    "sudo '$REMOTE_STAGE/scripts/install.sh' --bind-host '$BIND_HOST' --start"
fi

echo "Deployment staging remains at $REMOTE_STAGE for audit/recovery. Remove it manually after verification."
