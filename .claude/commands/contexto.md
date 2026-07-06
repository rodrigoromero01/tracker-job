---
description: Resumen de orientación extendido del entorno y el catálogo de portales.
argument-hint:
---

Mostrá un banner de orientación completo del proyecto. Read-only, no toca código ni ejecuta scrapers.

Sos el orquestador. Recolectá y presentá (leyendo las fuentes de verdad, sin asumir):

1. De `.claude/workspace.md` (marcadores `KEY: valor`):
   - **Deploy target** (`DEPLOY_TARGET`), **timezone** (`TIMEZONE`), **Python** (`PYTHON_BIN`),
     **RUN_SCHEDULE**, **DB_PATH**, **SECRETS_FILE**.
   - Si `workspace.md` **no existe** → advertí que hay que copiar `workspace.example.md → workspace.md`.

2. **Estado git**: rama actual y si el árbol está limpio o con cambios (`git status -sb`).

3. **Catálogo de portales** desde `references/portales.md`: la tabla de estado rápido (portal, método,
   **fragilidad** 🟢/🟡/🔴, últ. verificación, función `scrape_*`).

4. **`.env` presente**: indicá solo **sí/no** que existe el archivo de secretos (`SECRETS_FILE`).
   **Nunca** muestres su contenido ni valores de variables.

Presentalo como un banner conciso (análogo al `session_orient`, pero completo). No invoques subagentes:
es una lectura directa.
