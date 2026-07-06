#!/bin/bash
# hooks/validate_py.sh — validador INFORMATIVO (no bloquea). Chequea convenciones
# y robustez del proyecto tracker-job sobre un archivo .py. Emite warnings por stdout.
#
# Bloqueo real (secretos, etc.) lo hace check_patterns.sh. Aca solo avisos.
#
# Uso: validate_py.sh <archivo.py>

file="$1"
[ -f "$file" ] || exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib.sh"

warns=""
add_warn() { warns="${warns}  ⚠ $1
"; }

# 1) Sintaxis Python (no bloquea, pero avisa fuerte)
if command -v python3 >/dev/null 2>&1; then
    err="$(python3 -m py_compile "$file" 2>&1)"
    if [ $? -ne 0 ]; then
        add_warn "Error de sintaxis Python: ${err}"
    fi
fi

# 2) requests sin timeout (cuelga el worker para siempre en la nube)
if grep -nE 'requests\.(get|post|request|put|delete)\(' "$file" 2>/dev/null | grep -qv 'timeout'; then
    lines="$(grep -nE 'requests\.(get|post|request|put|delete)\(' "$file" 2>/dev/null | grep -v 'timeout' | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')"
    add_warn "requests SIN timeout (lineas ${lines}). En la nube un request colgado frena todo. Agrega timeout=. Ver skill scraping-patterns."
fi

# 3) except pelado que se traga todo
if grep -nqE '^[[:space:]]*except[[:space:]]*:' "$file" 2>/dev/null; then
    lines="$(grep -nE '^[[:space:]]*except[[:space:]]*:' "$file" 2>/dev/null | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')"
    add_warn "'except:' pelado (lineas ${lines}) captura hasta KeyboardInterrupt. Usa 'except Exception as e:' y logueala. Ver skill anti-fragile-scrapers."
fi

# 4) Scraper sin manejo de errores (cada scraper debe degradar sin tumbar la corrida)
if tj_looks_like_scraper "$file"; then
    if ! grep -qE '(try:|except )' "$file" 2>/dev/null; then
        add_warn "Este archivo hace fetch de red pero no tiene try/except. Un scraper que revienta no debe tumbar la corrida entera: envolvelo. Ver skill anti-fragile-scrapers."
    fi
fi

if [ -n "$warns" ]; then
    printf 'Convenciones tracker-job — avisos para %s:\n%s' "$(basename "$file")" "$warns"
fi
exit 0
