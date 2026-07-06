#!/bin/bash
# hooks/session_pull.sh — SessionStart: chequeo de sincronia con el remoto, SEGURO.
#
# A diferencia del enjambre de referencia (donde .claude/ es su propio repo), aca el
# enjambre vive DENTRO del repo del proyecto. Por eso este hook NO hace merge automatico
# (no queremos pisar codigo de trabajo): solo hace un `fetch` read-only y REPORTA el
# estado (al dia / atrasado N / adelantado N / sucio / offline) por additionalContext.
# El pull real lo decide el usuario. Nunca bloquea; usa timeout para no colgar el arranque.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib.sh"

repo="$TJ_PROJECT_ROOT"
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)"
upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"

status=""
if [ -z "$upstream" ]; then
    status="rama '$branch' sin upstream configurado"
else
    # fetch read-only, sin prompts, con timeout
    GIT_TERMINAL_PROMPT=0 timeout 8 git -C "$repo" fetch --quiet 2>/dev/null
    if [ $? -ne 0 ]; then
        status="offline o sin auth (no se pudo fetch)"
    else
        behind="$(git -C "$repo" rev-list --count 'HEAD..@{u}' 2>/dev/null)"
        ahead="$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null)"
        dirty=""
        [ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ] && dirty=" · arbol con cambios sin commitear"
        if [ "${behind:-0}" -gt 0 ] && [ "${ahead:-0}" -gt 0 ]; then
            status="divergencia: ${behind} atras / ${ahead} adelante de $upstream${dirty}"
        elif [ "${behind:-0}" -gt 0 ]; then
            status="atrasado ${behind} commit(s) respecto de $upstream (corre 'git pull' cuando quieras)${dirty}"
        elif [ "${ahead:-0}" -gt 0 ]; then
            status="adelantado ${ahead} commit(s) sin pushear${dirty}"
        else
            status="al dia con $upstream${dirty}"
        fi
    fi
fi

python3 - "$status" <<'PY'
import json, sys
status = sys.argv[1]
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Estado git del repo tracker-job: " + status + ". (session_pull.sh no hace merge automatico: el pull lo decidis vos.)"
}}))
PY
exit 0
