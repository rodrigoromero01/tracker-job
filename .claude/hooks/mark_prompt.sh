#!/bin/bash
# hooks/mark_prompt.sh — UserPromptSubmit: marca el inicio de un turno para medir
# duracion. on_stop.sh usa esta marca para avisar solo si la tarea fue "larga".
# Best-effort, nunca bloquea.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mark_dir="${TMPDIR:-/tmp}/tracker-job-enjambre"
mkdir -p "$mark_dir" 2>/dev/null
date +%s > "$mark_dir/prompt_start" 2>/dev/null
exit 0
