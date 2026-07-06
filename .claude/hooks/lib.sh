#!/bin/bash
# hooks/lib.sh — helpers compartidos por los hooks del enjambre tracker-job.
#
# No hardcodea nada del entorno: todo se deriva de la ubicacion del propio hook
# y de los marcadores de .claude/workspace.md. Se sourcea desde los demas hooks.

# Rutas resueltas al sourcear (absolutas). ${BASH_SOURCE} dentro de funciones
# se comporta mal en zsh, por eso se calculan aca.
TJ_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TJ_CLAUDE_DIR="$(cd "$TJ_HOOK_DIR/.." && pwd)"
TJ_PROJECT_ROOT="$(cd "$TJ_CLAUDE_DIR/.." && pwd)"

# Archivo de entorno: workspace.md (por dev, gitignored) con fallback al ejemplo.
tj_workspace_file() {
    if [ -f "$TJ_CLAUDE_DIR/workspace.md" ]; then
        printf '%s' "$TJ_CLAUDE_DIR/workspace.md"
    elif [ -f "$TJ_CLAUDE_DIR/workspace.example.md" ]; then
        printf '%s' "$TJ_CLAUDE_DIR/workspace.example.md"
    fi
}

# Lee un marcador "KEY: valor" de workspace.md. Vacio si no existe.
tj_ws_marker() {
    local key="$1" ws; ws="$(tj_workspace_file)"
    [ -n "$ws" ] && [ -f "$ws" ] || return 0
    grep -oE "^[[:space:]]*${key}:[[:space:]]*.*" "$ws" 2>/dev/null \
        | head -1 \
        | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//"
}

# True (0) si el path es un archivo Python del PROYECTO (no del enjambre .claude/).
tj_is_project_py() {
    local f="$1"
    case "$f" in
        *.py) ;;
        *) return 1 ;;
    esac
    case "$f" in
        */.claude/*) return 1 ;;
    esac
    return 0
}

# Heuristica: True si el archivo .py parece contener un scraper (fetch de red).
tj_looks_like_scraper() {
    local f="$1"
    [ -f "$f" ] || return 1
    grep -qE 'requests\.(get|post|request)|feedparser\.parse|urlopen' "$f" 2>/dev/null
}

# Linea corta de orientacion para el banner de sesion.
tj_orientation_line() {
    local py deploy tz branch
    py="$(python3 --version 2>&1 | awk '{print $2}')"
    deploy="$(tj_ws_marker DEPLOY_TARGET)"; [ -z "$deploy" ] && deploy="?"
    tz="$(tj_ws_marker TIMEZONE)"; [ -z "$tz" ] && tz="?"
    branch="$(git -C "$TJ_PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [ -z "$branch" ] && branch="(sin git)"
    printf '🐍 tracker-job · py %s · deploy %s · tz %s · git %s' \
        "${py:-?}" "$deploy" "$tz" "$branch"
}
