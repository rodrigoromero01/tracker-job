#!/bin/bash
# statusline.sh — linea de estado de Claude Code para tracker-job.
# Recibe el JSON de Claude Code por stdin. Muestra: proyecto, branch git, target de
# deploy y timezone (leidos de workspace.md). Best-effort.

json=$(cat)

# project_dir del JSON, con fallback
dir=$(printf '%s' "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('workspace',{}).get('project_dir') or d.get('cwd') or '')" 2>/dev/null)
[ -z "$dir" ] && dir="${CLAUDE_PROJECT_DIR:-$PWD}"

claude_dir="$dir/.claude"
ws="$claude_dir/workspace.md"
[ -f "$ws" ] || ws="$claude_dir/workspace.example.md"

marker() {
    [ -f "$ws" ] || return
    grep -oE "^[[:space:]]*$1:[[:space:]]*.*" "$ws" 2>/dev/null | head -1 \
        | sed -E "s/^[[:space:]]*$1:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//"
}

branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$branch" ] && branch="-"
deploy=$(marker DEPLOY_TARGET); [ -z "$deploy" ] && deploy="?"
tz=$(marker TIMEZONE); [ -z "$tz" ] && tz="?"

# dirty flag
dirty=""
[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ] && dirty="*"

printf '🐍 tracker-job · ⎇ %s%s · ☁ %s · 🕐 %s' "$branch" "$dirty" "$deploy" "$tz"
