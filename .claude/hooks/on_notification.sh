#!/bin/bash
# hooks/on_notification.sh — Notification: Claude pide input o permiso.
# Dispara un aviso de escritorio. Best-effort, nunca bloquea.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat 2>/dev/null)
msg=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message','Claude necesita tu atencion'))" 2>/dev/null)
[ -z "$msg" ] && msg="Claude necesita tu atencion"

bash "$DIR/notify.sh" "tracker-job · Claude" "$msg" >/dev/null 2>&1 &
exit 0
