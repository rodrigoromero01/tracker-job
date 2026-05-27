#!/usr/bin/env python3
"""
Scheduler — Corre el scraper automáticamente todos los días a las 8am
Dos opciones: APScheduler (recomendado) o cron (Linux/Mac)
"""

# ─── OPCIÓN A: APScheduler (funciona en Windows, Linux y Mac) ─────────────────

import os
import logging
from apscheduler.schedulers.blocking import BlockingScheduler
from scraper import run

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")

HORA  = int(os.getenv("RUN_HOUR",   "8"))
MINUTO = int(os.getenv("RUN_MINUTE", "0"))

def iniciar_scheduler():
    scheduler = BlockingScheduler(timezone="America/Argentina/Buenos_Aires")

    # Corre todos los días a la hora configurada (default 8:00am)
    scheduler.add_job(run, "cron", hour=HORA, minute=MINUTO)

    # Corre UNA VEZ al arrancar (para verificar que todo funciona)
    scheduler.add_job(run, "date")

    print(f"Scheduler iniciado. Correrá todos los días a las {HORA:02d}:{MINUTO:02d}.")
    print("En Railway este proceso corre 24/7 en la nube.")
    print("Presioná Ctrl+C para detener localmente.\n")

    try:
        scheduler.start()
    except (KeyboardInterrupt, SystemExit):
        print("\nScheduler detenido.")


# ─── OPCIÓN B: Cron (Linux/Mac, más robusto para servidor) ────────────────────
#
# Para agregar al cron, ejecutá:   crontab -e
# Agregá esta línea:
#   0 8 * * * /usr/bin/python3 /ruta/completa/job-tracker/scraper.py
#
# Para ver los crons activos:      crontab -l


# ─── OPCIÓN C: Task Scheduler Windows ─────────────────────────────────────────
#
# 1. Abrí "Programador de tareas"
# 2. Crear tarea básica
# 3. Desencadenador: Diariamente a las 8:00am
# 4. Acción: Iniciar programa
#    Programa: python
#    Argumentos: C:\ruta\job-tracker\scraper.py
#    Iniciar en: C:\ruta\job-tracker\


if __name__ == "__main__":
    iniciar_scheduler()


# ─── OPCIÓN B: Cron (Linux/Mac, más robusto para servidor) ────────────────────
#
# Para agregar al cron, ejecutá:   crontab -e
# Agregá esta línea:
#   0 8 * * * /usr/bin/python3 /ruta/completa/job-tracker/scraper.py
#
# Para ver los crons activos:      crontab -l


# ─── OPCIÓN C: Task Scheduler Windows ─────────────────────────────────────────
#
# 1. Abrí "Programador de tareas"
# 2. Crear tarea básica
# 3. Desencadenador: Diariamente a las 8:00am
# 4. Acción: Iniciar programa
#    Programa: python
#    Argumentos: C:\ruta\job-tracker\scraper.py
#    Iniciar en: C:\ruta\job-tracker\
