#!/bin/bash
# hooks/protect.sh — PreToolUse (Write|Edit|MultiEdit): impide escribir archivos
# que NUNCA deben editarse desde el enjambre:
#   - .env / *.env         (secretos reales; el template es .env.example)
#   - *.db / *.sqlite*     (base de datos de runtime; se regenera sola)
# Contrato Claude Code: exit 2 con mensaje por stderr bloquea la escritura.

input=$(cat)
file_path=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path','') or '')" 2>/dev/null)

[ -z "$file_path" ] && exit 0

base="$(basename "$file_path")"

case "$base" in
    .env|*.env)
        # Permitir el template versionado
        case "$base" in
            .env.example|*.example) exit 0 ;;
        esac
        echo "BLOQUEADO: '$file_path' contiene secretos reales y no debe editarse desde el enjambre. Los secretos se configuran a mano en .env (local) o en el dashboard de Railway. Si queres cambiar el CONTRATO de variables, edita .env.example. Ver skill secrets-hygiene." >&2
        exit 2
        ;;
esac

case "$file_path" in
    *.db|*.sqlite|*.sqlite3)
        echo "BLOQUEADO: '$file_path' es una base de datos de runtime (se crea/regenera sola al correr el scraper). No la edites a mano. Si necesitas cambiar el schema, hacelo en el codigo Python (ver skill data-dedup-sqlite)." >&2
        exit 2
        ;;
esac

exit 0
