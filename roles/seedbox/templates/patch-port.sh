#!/bin/sh

CONFIG="/config/config.xml"
# TODO: Fix this variable
TARGET_PORT={{ port }}

echo "[port-fix] Waiting for config.xml..."

for i in $(seq 1 30); do
  [ -f "$CONFIG" ] && break
  sleep 1
done

if [ ! -f "$CONFIG" ]; then
  echo "[port-fix] config.xml not found, skipping"
  exit 0
fi

CURRENT_PORT=$(sed -n 's|.*<Port>\([0-9]\+\)</Port>.*|\1|p' "$CONFIG")

if [ "$CURRENT_PORT" = "$TARGET_PORT" ]; then
  echo "[port-fix] Port already set to $TARGET_PORT, nothing to do"
  exit 0
fi

echo "[port-fix] Patching port from $CURRENT_PORT to $TARGET_PORT..."
sed -i "s|<Port>$CURRENT_PORT</Port>|<Port>$TARGET_PORT</Port>|" "$CONFIG"

ehco "Container with be restarted by the failing healthcheck"