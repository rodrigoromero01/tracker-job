# Workspace — tracker-job (plantilla)

> Copiá este archivo a `.claude/workspace.md` y ajustalo a **tu** entorno. `workspace.md` está
> gitignored (es por-dev). **Es la única fuente de verdad del entorno**: ningún agente, skill ni
> hook hardcodea paths, intérprete ni target de deploy — todo sale de acá.
>
> Los hooks y el statusline leen algunos valores como **marcadores** `KEY: valor` (líneas exactas,
> ver abajo). El resto es prosa para orientar a Claude.

## Marcadores (los leen hooks/statusline — respetá el formato `KEY: valor`)

```
PYTHON_BIN: python3                 # intérprete a usar (o ruta a un venv)
DEPLOY_TARGET: Railway              # Railway | local | cron | otro
TIMEZONE: America/Argentina/Buenos_Aires
RUN_SCHEDULE: 08:00                 # hora diaria de corrida (informativo)
DB_PATH: empleos.db                 # ruta de la base de dedup
SECRETS_FILE: .env                  # dónde viven los secretos REALES (fuera de git)
```

## Entorno (prosa)

- **Cómo corro el proyecto**: describí si usás venv (`python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`) o el Python del sistema.
- **Dónde está desplegado**: proyecto de Railway (nombre), o cron local, o nada todavía.
- **Secretos**: `EMAIL_FROM`, `EMAIL_TO`, `EMAIL_PASS` (App Password de Gmail). En local viven en `.env`
  (copiado de `.env.example`); en Railway, en el dashboard → Variables. **Nunca** en el código ni en git.
- **Persistencia de la dedup**: ¿`empleos.db` en disco local (se pierde en cada redeploy de Railway —
  ver `references/gotchas.md`) o en un Volume/DB persistente?

## Repo

- **Origin**: https://github.com/rodrigoromero01/tracker-job.git
- **Flujo git**: simple (ver skill `git-simple`). Commit/push **solo a pedido**.
