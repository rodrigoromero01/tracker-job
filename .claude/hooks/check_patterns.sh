#!/bin/bash
# hooks/check_patterns.sh — validador BLOQUEANTE data-driven.
#
# Lee los patrones prohibidos de references/patterns/scraper.patterns y, si el
# archivo .py escrito matchea alguno, bloquea (exit 2) devolviendo la explicacion.
# Agregar/quitar una regla = editar el .patterns, sin tocar este script.
#
# Formato de scraper.patterns:  <regex ERE> ::: <explicacion para corregir>
# (lineas que empiezan con # o vacias se ignoran)
#
# Uso: check_patterns.sh <archivo.py>

file="$1"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
patterns_file="$DIR/../references/patterns/scraper.patterns"

[ -f "$file" ] || exit 0
[ -f "$patterns_file" ] || exit 0

hits=""
while IFS= read -r line || [ -n "$line" ]; do
    # Saltar comentarios y lineas vacias
    case "$line" in
        ''|\#*) continue ;;
    esac
    # Requiere el separador ' ::: '
    case "$line" in
        *' ::: '*) ;;
        *) continue ;;
    esac
    pattern="${line%% ::: *}"
    msg="${line#* ::: }"
    if grep -Eq -- "$pattern" "$file" 2>/dev/null; then
        lineno="$(grep -nE -- "$pattern" "$file" 2>/dev/null | head -1 | cut -d: -f1)"
        hits="${hits}  • [linea ${lineno:-?}] ${msg}
"
    fi
done < "$patterns_file"

if [ -n "$hits" ]; then
    printf 'PATRON PROHIBIDO detectado en %s:\n%s' "$file" "$hits"
    exit 2
fi
exit 0
