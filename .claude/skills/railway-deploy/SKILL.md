---
name: railway-deploy
description: Deploy en Railway — Procfile worker, variables de entorno en el dashboard, el gotcha del filesystem efímero (la .db se borra), Volumes, logs, plan gratis y checklist. Cargá al deployar o diagnosticar el deploy.
---
# Deploy en Railway

Railway corre el worker 24/7 en la nube (sin dejar la PC prendida). Es el target propuesto en el
README. El `DEPLOY_TARGET` real está en `workspace.md`.

Fuentes de verdad: pasos de deploy y variables en `README.md` (Opción A); gotchas "filesystem efímero
→ `empleos.db` se borra" y "el job `date` dispara un email por redeploy" en
`.claude/references/gotchas.md`; el scheduler en la skill `scheduling-apscheduler`; secretos en
`secrets-hygiene`.

## Cómo funciona

1. Railway se conecta a tu repo de GitHub y builda en cada push.
2. Lee el **`Procfile`** para saber qué proceso arrancar:
   ```
   worker: python scheduler.py
   ```
   `worker:` = proceso de fondo persistente, sin puerto HTTP. **No uses `web:`** (Railway esperaría un
   puerto abierto y mataría el proceso; ver `scheduling-apscheduler`).
3. Instala `requirements.txt` y arranca `scheduler.py`, que corre `run()` al bootear (job `date`) y
   después todos los días a la hora configurada.

## Variables de entorno (dashboard, NO en el código)

En el proyecto → pestaña **Variables** → agregá (nunca como literales en el repo — skill
`secrets-hygiene`):

| Variable | Ejemplo | Qué es |
|----------|---------|--------|
| `EMAIL_FROM` | `tu@gmail.com` | Remitente (login SMTP). |
| `EMAIL_TO` | `tu@gmail.com` | Destinatario del resumen. |
| `EMAIL_PASS` | `xxxx xxxx xxxx xxxx` | **App Password de Gmail**, no la contraseña real (gotcha). |
| `RUN_HOUR` | `8` | Hora del disparo diario (en la TZ del scheduler). |
| `RUN_MINUTE` | `0` | Minuto del disparo. |
| `DB_PATH` | `/data/empleos.db` | Ruta de la base (apuntá a un Volume para persistir — ver abajo). |

Las mismas variables van en `.env` local (copiado de `.env.example`) para desarrollo. El contrato de
variables se cambia en `.env.example`, no acá.

## 🔴 Gotcha central: el filesystem es efímero → la `.db` se borra

Cada build/redeploy arranca de un filesystem nuevo. `empleos.db` (la dedup) **se pierde** → tras un
deploy pueden repetirse empleos ya vistos (gotcha verificado). No es bug del scraper.

Persistir de verdad:
- **Railway Volume (recomendado, mínimo cambio):**
  1. En el servicio → **Volumes** → creá uno y montalo en, p.ej., `/data`.
  2. Seteá `DB_PATH=/data/empleos.db` en Variables.
  3. El código ya lee `DB_PATH = os.getenv("DB_PATH", "empleos.db")` → no hay que tocar Python.
- **Postgres de Railway** u otro store: más robusto pero es cambiar de motor de dedup → decisión del
  usuario (ver skill `data-dedup-sqlite`), no lo hagas por defecto.
- **Sin Volume**: asumí que un redeploy puede reenviar un batch. Aceptable si deployás poco.

## 🟡 Cada redeploy dispara un email

`scheduler.py` corre `run()` al arrancar (job `date`) → cada deploy manda un email fuera de horario.
Es intencional (verifica el deploy), pero molesta si iterás mucho. Ver `scheduling-apscheduler`.

## Ver logs

Dashboard → servicio → pestaña **Deployments / Logs**. Ahí ves los `print()` en español del scraper
(`→ PyAr...`, `N encontrados`, `Email enviado correctamente`) y cualquier traceback. Como el proyecto
loguea el progreso, los logs alcanzan para diagnosticar sin instrumentar nada extra.
Recordá: **no se imprimen secretos** — quedan en estos logs (skill `secrets-hygiene`).

## Plan gratis

- El plan free da un crédito/horas mensuales limitadas. Un `BlockingScheduler` **corre 24/7** → consume
  horas todo el mes aunque solo trabaje 1 vez por día.
- Si te quedás corto de horas: pasá a **Railway Cron / scheduled job** (dispara el proceso a la hora y
  lo apaga; no gasta horas ociosas) — ver `scheduling-apscheduler`. Con cron, el job `date` sobra.

## Checklist de deploy

1. `Procfile` = `worker: python scheduler.py`. ✔
2. `requirements.txt` con las 5 deps (`requests`, `beautifulsoup4`, `feedparser`, `apscheduler`,
   `python-dotenv`). ✔
3. `.env` y `empleos.db` en `.gitignore` (no subir secretos ni la base). ✔
4. Push a GitHub → New Project → Deploy from repo.
5. Cargar las 6 variables en el dashboard (App Password, no contraseña real).
6. (Persistencia) Crear Volume + `DB_PATH=/data/empleos.db`.
7. Deploy → mirar logs → confirmar el email de arranque (job `date`).
8. Si cambiaste comportamiento visible (portales/variables/deploy), actualizá `README.md`.

## Do / Don't

- ✅ `worker:` en el Procfile; variables en el dashboard; App Password en `EMAIL_PASS`.
- ✅ Volume + `DB_PATH` para que la dedup sobreviva a los redeploys.
- ❌ `web:` en el Procfile (mata el proceso por falta de puerto).
- ❌ Poner secretos en el repo/código (el hook los bloquea; skill `secrets-hygiene`).
- ❌ Esperar que `empleos.db` persista sin Volume.
