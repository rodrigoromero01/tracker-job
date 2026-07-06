---
name: scheduling-apscheduler
description: BlockingScheduler + cron de APScheduler, timezone, el job "date" que corre al arrancar (y dispara un email por deploy), worker vs web en el Procfile, alternativas. Cargá al tocar scheduler.py o el disparo.
---
# Scheduling con APScheduler

El disparo diario lo hace `scheduler.py` con `BlockingScheduler`. Es lo que corre 24/7 en la nube (el
worker del Procfile) y llama a `run()` de `scraper.py`.

Fuentes de verdad: el código real es `scheduler.py`; gotchas "timezone hardcodeada a Buenos Aires" y
"el scheduler corre una vez al arrancar (job `date`) → cada redeploy dispara un email" en
`.claude/references/gotchas.md`; deploy y Procfile en la skill `railway-deploy`.

## Patrón base

```python
import os
import logging
from apscheduler.schedulers.blocking import BlockingScheduler
from scraper import run

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")

HORA   = int(os.getenv("RUN_HOUR",   "8"))     # config por env var, no literal
MINUTO = int(os.getenv("RUN_MINUTE", "0"))

def iniciar_scheduler():
    scheduler = BlockingScheduler(timezone="America/Argentina/Buenos_Aires")
    scheduler.add_job(run, "cron", hour=HORA, minute=MINUTO)   # diario a la hora fijada
    scheduler.add_job(run, "date")                             # una vez al arrancar (ver gotcha)
    try:
        scheduler.start()          # BLOQUEA el hilo: es el corazón del worker
    except (KeyboardInterrupt, SystemExit):
        print("\nScheduler detenido.")
```

- **`BlockingScheduler`** (no `BackgroundScheduler`): el proceso no tiene otra cosa que hacer, así que
  bloquear el hilo principal es lo correcto para un worker. `start()` no retorna.
- **`RUN_HOUR`/`RUN_MINUTE` por `os.getenv`** con default → se ajusta el horario en Railway sin tocar
  código.
- Como `start()` bloquea, **todo request de red debe tener `timeout`** (skill `scraping-patterns`): un
  fetch colgado congela el scheduler entero y no vuelve a disparar (gotcha verificado).

## Cron de APScheduler

`add_job(run, "cron", ...)` acepta los campos típicos de cron: `hour`, `minute`, `day_of_week`,
`day`, `month`. Ejemplos:

```python
scheduler.add_job(run, "cron", hour=8, minute=0)                       # todos los días 08:00
scheduler.add_job(run, "cron", day_of_week="mon-fri", hour=9)          # días hábiles 09:00
scheduler.add_job(run, "cron", hour="8,20", minute=0)                  # 08:00 y 20:00
```

## Timezone

`BlockingScheduler(timezone="America/Argentina/Buenos_Aires")` fija la zona; `RUN_HOUR`/`RUN_MINUTE` se
interpretan **en esa zona**, sin importar la TZ del server (Railway suele estar en UTC). Gotcha: si se
cambia de región, parametrizá la TZ por env var (`TIMEZONE`, documentada en `workspace.md`) en vez de
dejarla hardcodeada.

```python
TZ = os.getenv("TIMEZONE", "America/Argentina/Buenos_Aires")
scheduler = BlockingScheduler(timezone=TZ)
```

## 🟡 El job "date" corre al arrancar → cada redeploy manda un email

`scheduler.add_job(run, "date")` (sin fecha) programa **una corrida inmediata** al bootear, además del
cron. Es intencional: verifica que todo funciona apenas deployás. **Consecuencia (gotcha):** cada
redeploy del worker dispara `run()` → llega un email fuera de horario. Al iterar en producción,
tenelo presente (o comentá temporalmente ese `add_job` si vas a redeployar muchas veces seguidas).

## Worker vs web en el Procfile

Railway lee el `Procfile`. Este proyecto es un **worker** (proceso de fondo, sin puerto HTTP):

```
worker: python scheduler.py
```

- **`worker:`** = proceso de fondo persistente. Es lo correcto: el scheduler corre 24/7.
- **`web:`** = Railway esperaría que abras un puerto HTTP (`$PORT`) y te mata el proceso si no lo hacés
  ("no open ports detected"). **No uses `web:` para este scheduler.**

## Alternativas al scheduler propio

`BlockingScheduler` mantiene el proceso vivo 24/7 (consume horas del plan). Alternativas según entorno:

- **Cron del sistema (Linux/Mac)**: corré `scraper.py` directo, sin scheduler. El scraper ya corre
  `run()` en `if __name__ == "__main__"`. Más robusto para un servidor propio.
  ```cron
  0 8 * * * /usr/bin/python3 /ruta/completa/tracker-job/scraper.py
  ```
- **Railway Cron / Scheduled jobs**: en vez de un worker 24/7, Railway dispara el proceso a una hora y
  lo apaga → no gastás horas ociosas. Si migrás a esto, el `add_job(run, "date")` deja de tener sentido
  (el disparo lo hace Railway). Ver skill `railway-deploy`.
- **Task Scheduler de Windows**: dispara `python scraper.py` a las 8:00 (ya documentado en
  `scheduler.py`, Opción C).

Elegí según `DEPLOY_TARGET` en `workspace.md`. No sumes una dependencia de scheduling nueva:
APScheduler ya está en `requirements.txt` (minimal-footprint).

## Do / Don't

- ✅ `BlockingScheduler` + `add_job(run, "cron", ...)`; `RUN_HOUR`/`RUN_MINUTE` por env var.
- ✅ `Procfile` con `worker:` (no `web:`).
- ✅ `timeout` en todo request (si no, el scheduler bloqueante se cuelga).
- ❌ `BackgroundScheduler` sin nada que mantenga vivo el proceso (termina y muere).
- ❌ Olvidar que el job `"date"` manda un email por cada redeploy.
- ❌ Sumar Celery/otra lib de scheduling para un único job diario.
