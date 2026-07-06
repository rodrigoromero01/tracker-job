#!/bin/bash
# hooks/session_orient.sh — SessionStart: imprime una linea de orientacion al iniciar
# la sesion (version de Python, target de deploy, timezone, branch git). Visible para
# el usuario (systemMessage) y para Claude (additionalContext). El comando /contexto da
# la version extendida on-demand. Best-effort, nunca bloquea.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib.sh"

line="$(tj_orientation_line)"

python3 - "$line" <<'PY'
import json, sys
line = sys.argv[1]
print(json.dumps({
    "systemMessage": line,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "Orientacion del entorno: " + line + ". Detalles y salud del entorno con /contexto y /salud. La config de entorno (por dev) vive en .claude/workspace.md."
    }
}))
PY
exit 0
