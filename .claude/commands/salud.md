---
description: Health check del entorno; reporta OK/WARN por ítem.
argument-hint:
---

Corré un health check del entorno del enjambre. Read-only (salvo `py_compile`, que no modifica fuentes).

Sos el orquestador. Verificá cada ítem y reportá **OK / WARN** (con el motivo del WARN). Usá el
`PYTHON_BIN` de `.claude/workspace.md`.

1. **workspace.md presente y con marcadores**: existe `.claude/workspace.md` y tiene las líneas
   `PYTHON_BIN:`, `DEPLOY_TARGET:`, `TIMEZONE:`, `DB_PATH:`, `SECRETS_FILE:`. Si falta → WARN (copiar de
   `workspace.example.md`).
2. **python3 disponible**: `<PYTHON_BIN> --version` corre.
3. **deps instaladas**: `pip check` y/o import de las de `requirements.txt` (requests, bs4/`beautifulsoup4`,
   feedparser, apscheduler, dotenv/`python-dotenv`). Reportá cuáles faltan.
4. **.env presente**: existe el archivo `SECRETS_FILE` (default `.env`). Reportá **solo** presencia,
   **nunca** los valores. Si falta → WARN (copiar de `.env.example`).
5. **compilan**: `<PYTHON_BIN> -m py_compile scraper.py scheduler.py` sin errores.
6. **git status**: rama actual y árbol limpio o con cambios (`git status -sb`).

Cerrá con un resumen: cuántos OK / cuántos WARN y qué acción concreta resuelve cada WARN. No invoques
subagentes ni modifiques fuentes.
