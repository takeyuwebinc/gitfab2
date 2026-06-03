#!/usr/bin/env bash
# /var/run/docker.sock の GID にコンテナ内 docker グループの GID を合わせ、
# ruby ユーザーから docker CLI を実行可能にする。
set -euo pipefail

SOCKET=/var/run/docker.sock
if [ ! -S "$SOCKET" ]; then
  echo "docker socket not found at $SOCKET; skipping" >&2
  exit 0
fi

HOST_GID=$(stat -c '%g' "$SOCKET")
CURRENT_GID=$(getent group docker | cut -d: -f3 || true)

if [ -z "$CURRENT_GID" ]; then
  sudo groupadd -g "$HOST_GID" docker
elif [ "$CURRENT_GID" != "$HOST_GID" ]; then
  # 既存 GID とぶつかる場合は既存側を退避
  if getent group "$HOST_GID" >/dev/null; then
    EXISTING=$(getent group "$HOST_GID" | cut -d: -f1)
    if [ "$EXISTING" != "docker" ]; then
      sudo groupmod -g "$((HOST_GID + 10000))" "$EXISTING" || true
    fi
  fi
  sudo groupmod -g "$HOST_GID" docker
fi

sudo usermod -aG docker ruby
