---
description: Checklist guiado de deploy a Railway (no ejecuta el deploy, guía).
argument-hint:
---

Guiá el deploy a Railway. **No ejecutás el deploy** — armás y verificás el checklist.

Sos el orquestador. Cargá la skill **railway-deploy** con la tool Skill y leé `.claude/workspace.md`
(`DEPLOY_TARGET`, `TIMEZONE`, `SECRETS_FILE`) y `references/gotchas.md`.

Verificá y reportá OK/WARN por ítem:

1. **Procfile** presente con el proceso `worker` (`worker: python scheduler.py`).
2. **requirements.txt** completo (requests, beautifulsoup4, feedparser, apscheduler, python-dotenv) y
   sin deps de más.
3. **Variables de entorno** en el dashboard de Railway (NO en `.env`, que no se sube):
   `EMAIL_FROM`, `EMAIL_TO`, `EMAIL_PASS` (App Password de Gmail, no la contraseña real; ver gotcha), y
   `DB_PATH`/`TIMEZONE` si aplican. Chequealas contra `.env.example`.
4. **`.gitignore`** raíz ignora `.env` y `empleos.db` (no filtrar secretos ni la base).

**ADVERTÍ SIEMPRE el gotcha del filesystem efímero**: Railway borra el disco en cada build/redeploy →
`empleos.db` (SQLite local) se **pierde** y la dedup "se olvida" (llegan empleos repetidos tras un
deploy). Para persistir de verdad: montar un **Railway Volume** y apuntar `DB_PATH` ahí, o migrar la
dedup a un store persistente (Postgres/Redis). Mencioná también que `scheduler.py` corre `run()` al
bootear → **cada redeploy dispara un email**.

No ejecutés comandos de deploy ni `git push`. Entregá el checklist con marcas OK/WARN y los pasos manuales
que le quedan al usuario.
