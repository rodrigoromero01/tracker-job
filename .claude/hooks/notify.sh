#!/bin/bash
# hooks/notify.sh — notificador de escritorio portable. Best-effort, nunca bloquea.
# Uso: notify.sh "Titulo" "Mensaje"
# Soporta: macOS (osascript), WSL->Windows (powershell.exe), Linux (notify-send),
# y fallback a la campana de la terminal (bell).

title="${1:-tracker-job}"
message="${2:-}"

# macOS
if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1
    exit 0
fi

# WSL -> Windows (toast via PowerShell BurntToast si esta, si no balloon simple)
if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "\
      [reflection.assembly]::LoadWithPartialName('System.Windows.Forms') > \$null; \
      \$n = New-Object System.Windows.Forms.NotifyIcon; \
      \$n.Icon = [System.Drawing.SystemIcons]::Information; \
      \$n.BalloonTipTitle = '${title}'; \
      \$n.BalloonTipText = '${message}'; \
      \$n.Visible = \$true; \$n.ShowBalloonTip(5000); Start-Sleep -Milliseconds 5200; \$n.Dispose()" \
      >/dev/null 2>&1
    exit 0
fi

# Linux nativo
if command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$message" >/dev/null 2>&1
    exit 0
fi

# Fallback: campana de terminal
printf '\a' >&2
exit 0
