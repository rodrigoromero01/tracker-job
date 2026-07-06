#!/bin/bash
# hooks/post_write.sh — dispatcher PostToolUse (Write|Edit|MultiEdit).
#
# Claude Code entrega el payload como JSON por stdin. Extraemos file_path, filtramos
# a archivos .py DEL PROYECTO (no del enjambre .claude/) y corremos:
#   1. validate_py.sh     -> avisos de convencion/robustez (no bloquea)
#   2. check_patterns.sh  -> patrones prohibidos (secretos, etc.) -> BLOQUEA (exit 2)
# Ademas inyecta recordatorios no bloqueantes por additionalContext (catalogo de
# portales y README) que SI llegan al agente.
#
# Codigos de salida (contrato Claude Code):
#   0  -> ok (warnings por stdout)
#   2  -> bloqueante: stderr vuelve a Claude para que corrija

input=$(cat)
file_path=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path','') or '')" 2>/dev/null)

[ -z "$file_path" ] && exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib.sh"

# Solo archivos .py del proyecto.
tj_is_project_py "$file_path" || exit 0

# --- Hook 1: convenciones/robustez (informativo) ---
validator_output="$(bash "$DIR/validate_py.sh" "$file_path")"

# --- Hook 2: patrones prohibidos (bloqueante) ---
bc_output="$(bash "$DIR/check_patterns.sh" "$file_path")"
bc_status=$?
if [ "$bc_status" -ne 0 ]; then
    printf '%s\n' "$bc_output" >&2
    exit 2
fi

# --- Recordatorios no bloqueantes (additionalContext -> agente) ---
notes=""
add_note() {
    [ -n "$notes" ] && notes="$notes
"
    notes="$notes$1"
}

# Si tocaste un scraper, el catalogo de portales debe reflejarlo.
if tj_looks_like_scraper "$file_path"; then
    add_note "Editaste un scraper. Manten sincronizado references/portales.md (URL, metodo, selectores, fragilidad, fecha de ultima verificacion) para el portal afectado antes de cerrar la tarea."
fi

# README del proyecto: si cambia comportamiento visible, actualizalo.
if [ -f "$TJ_PROJECT_ROOT/README.md" ]; then
    add_note "Si este cambio altera comportamiento visible (portales, filtros, formato de email, variables de entorno, deploy), actualiza README.md en consecuencia."
else
    add_note "El proyecto no tiene README.md. Genera/actualiza la documentacion antes de cerrar la tarea."
fi

# Sin nada para el agente: salida normal (warnings al usuario por stdout).
if [ -z "$notes" ]; then
    printf '%s\n' "$validator_output"
    exit 0
fi

# JSON: additionalContext -> agente; systemMessage -> usuario.
python3 - "$validator_output" "$notes" <<'PY'
import json, sys
validator = sys.argv[1]
notes = sys.argv[2]
out = {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": notes}}
if validator.strip():
    out["systemMessage"] = validator
print(json.dumps(out))
PY
exit 0
