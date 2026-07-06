#!/bin/bash
# hooks/on_stop.sh — Stop: Claude termino de responder. Avisa por escritorio SOLO
# si la tarea fue "larga" (umbral TJ_NOTIFY_MIN_SECONDS, default 45s), marcada por
# mark_prompt.sh en UserPromptSubmit. Best-effort, nunca bloquea.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
threshold="${TJ_NOTIFY_MIN_SECONDS:-45}"

mark_dir="${TMPDIR:-/tmp}/tracker-job-enjambre"
start_file="$mark_dir/prompt_start"
[ -f "$start_file" ] || exit 0

start=$(cat "$start_file" 2>/dev/null)
now=$(date +%s)
[ -z "$start" ] && exit 0
elapsed=$(( now - start ))
rm -f "$start_file" 2>/dev/null

if [ "$elapsed" -ge "$threshold" ]; then
    bash "$DIR/notify.sh" "tracker-job · listo" "Tarea terminada (${elapsed}s)" >/dev/null 2>&1 &
fi
exit 0
