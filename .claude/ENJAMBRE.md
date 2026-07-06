# 🐍 El Enjambre tracker-job — Arquitectura

> Documentación para humanos. Explica el sistema de agentes, skills y hooks que automatiza el
> desarrollo del proyecto **tracker-job** con **Claude Code**. Está adaptado del enjambre NEXIT
> (pensado para Odoo), *right-sized* para un proyecto de scraping en Python: se conservó la
> arquitectura (orquestador + subagentes + skills + hooks + workspace + references) y se reemplazó
> todo el dominio Odoo por el de este proyecto (scrapers, dedup, email, scheduling, deploy).

---

## 🎯 Filosofía

Un sistema de **agentes especializados** coordinados por un **orquestador**. Cada agente hace una
sola cosa y la hace bien. Ningún agente le habla a otro: toda la comunicación pasa por el orquestador.

**Principios:**
- **Entorno único**: versión de Python, deploy target, timezone, secretos se definen una sola vez en
  `workspace.md`; nada se hardcodea.
- **Robustez primero**: todo scraper degrada sin tumbar la corrida (try/except), todo request lleva
  `timeout`. Es NO-negociable y el hook lo vigila.
- **Secretos fuera del código**: siempre por variable de entorno; el hook **bloquea** literales.
- **Documentación viva**: el catálogo `references/portales.md` y el `README.md` se mantienen en sync
  con los scrapers.
- **Minimal footprint**: el menor cambio que cumpla; una dependencia nueva se justifica o no entra.

---

## 🧭 Tres fuentes de verdad (no se duplican)

| Capa | Fuente única | Contenido |
|------|--------------|-----------|
| **Entorno** (por dev) | `.claude/workspace.md` | Python, deploy target, timezone, `DB_PATH`, puntero a secretos |
| **Convenciones** | `.claude/AGENTS.md` + `CLAUDE.md` | idioma, NO-negociables, contrato de scraper/modelo, orquestación, fallback |
| **Conocimiento de dominio** | `.claude/references/` | catálogo de portales + gotchas del entorno + patrones del hook |

Todo lo demás (skills, agents, commands, hooks) **referencia** estas tres capas.

---

## 🗂️ Estructura de archivos

```
tracker-job/                            ← repo del proyecto
├── CLAUDE.md                           → symlink a .claude/CLAUDE.md (auto-cargado + importa AGENTS.md)
├── AGENTS.md                           → symlink a .claude/AGENTS.md (convenciones)
├── scraper.py  scheduler.py            ← el código real
│
└── .claude/                            ← el enjambre
    ├── settings.json                   ← permisos + hooks (Pre/PostToolUse, SessionStart, etc.)
    ├── statusline.sh                   ← línea de estado (branch, deploy, tz)
    ├── workspace.example.md            ← plantilla de entorno
    ├── workspace.md                    ← config de entorno POR DEV (gitignored)
    ├── ENJAMBRE.md                     ← este documento
    │
    ├── agents/                         ← 9 subagentes (Task)
    │   ├── researcher.md               ← inspecciona HTML vivo, propone selectores [read-only]
    │   ├── scraper-doctor.md           ← diagnostica scraper roto [read-only, opus]
    │   ├── scraper-dev.md              ← escribe/arregla scrape_<portal>()
    │   ├── data-model.md               ← Empleo, dedup (uid/SQLite), filtro de relevancia
    │   ├── notifier.md                 ← email HTML + envío SMTP
    │   ├── scaffold.md                 ← estructura base de una pieza nueva
    │   ├── testing.md                  ← dry-run, py_compile, validación
    │   ├── reviewer.md                 ← code review contra checklist [read-only, opus]
    │   └── git-flow.md                 ← Git flujo simple (commit/push a pedido)
    │
    ├── skills/                         ← 9 skills cargables (Skill)
    │   ├── scraping-patterns/          ← requests + bs4 + feedparser
    │   ├── anti-fragile-scrapers/      ← degradar sin romper, diagnosticar 0-resultados
    │   ├── data-dedup-sqlite/          ← SQLite, dedup por uid
    │   ├── email-html/                 ← HTML de email con CSS inline
    │   ├── scheduling-apscheduler/     ← BlockingScheduler, cron, timezone
    │   ├── railway-deploy/             ← Procfile, env vars, filesystem efímero
    │   ├── secrets-hygiene/            ← env vars, App Password, no filtrar
    │   ├── minimal-footprint/          ← anti-over-engineering (no-Odoo)
    │   └── git-simple/                 ← flujo Git simple (no gitflow)
    │
    ├── commands/                       ← 7 slash commands
    │   ├── scraper.md  fix-scraper.md  inspeccionar.md  probar.md
    │   └── deploy.md  contexto.md  salud.md
    │
    ├── hooks/                          ← validación + automatización (los cablea settings.json)
    │   ├── post_write.sh               ← dispatcher PostToolUse (lee el JSON del evento)
    │   ├── validate_py.sh              ← convenciones/robustez (avisos, no bloquea)
    │   ├── check_patterns.sh           ← patrones prohibidos data-driven (bloquea, exit 2)
    │   ├── protect.sh                  ← PreToolUse: impide editar .env y *.db
    │   ├── session_pull.sh             ← SessionStart: chequeo de sincronía git (read-only)
    │   ├── session_orient.sh           ← SessionStart: banner de orientación
    │   ├── mark_prompt.sh              ← UserPromptSubmit: marca inicio (umbral de notificación)
    │   ├── on_notification.sh          ← Notification: aviso de escritorio
    │   ├── on_stop.sh                  ← Stop: aviso al terminar tareas largas
    │   ├── notify.sh                   ← notificador portable (macOS/WSL/Linux/bell)
    │   └── lib.sh                      ← helpers compartidos (sourced)
    │
    ├── references/                     ← conocimiento de dominio
    │   ├── portales.md                 ← catálogo de portales (URL, método, selectores, fragilidad)
    │   ├── gotchas.md                  ← trampas del entorno (Railway efímero, Gmail, CSS inline...)
    │   └── patterns/scraper.patterns   ← patrones que consume check_patterns.sh
    │
    └── assets/
        └── email-template.html         ← plantilla de referencia del email (CSS inline)
```

---

## 🧠 Cómo funciona

### 1. Arranque
Claude Code lee `.claude/settings.json`: carga permisos, la statusline y los hooks. En `SessionStart`
corren `session_pull.sh` (chequeo read-only de sincronía con el remoto — **no** hace merge, solo
reporta) y `session_orient.sh` (banner: python, deploy, timezone, branch). `CLAUDE.md` (que importa
`AGENTS.md` con `@AGENTS.md`) queda siempre en contexto del orquestador.

### 2. El orquestador
Es el único agente que le habla al usuario. **No escribe código**: decide qué subagentes invocar,
integra resultados y reporta. Su comportamiento está en `CLAUDE.md`: tabla de 9 subagentes, flujos
típicos, reglas de orquestación, protocolo de fallback, handoff estandarizado y **Result Envelope**.

### 3. Agentes (subagentes)
Cada uno es un subproceso con su propio contexto y su allowlist de tools (frontmatter `tools`).

| Agente | Rol | Modelo |
|--------|-----|--------|
| `researcher` | Inspecciona HTML vivo, propone selectores | sonnet |
| `scraper-doctor` | Diagnostica scraper roto | **opus** |
| `scraper-dev` | Escribe/arregla scrapers | sonnet |
| `data-model` | Modelo, dedup, filtros | sonnet |
| `notifier` | Email HTML + SMTP | sonnet |
| `scaffold` | Estructura base nueva | sonnet |
| `testing` | Dry-run y validación | sonnet |
| `reviewer` | Code review | **opus** |
| `git-flow` | Git flujo simple | sonnet |

**Model tiering**: Opus donde hay **juicio de alto costo de error** (diagnóstico de `scraper-doctor`,
consistencia de `reviewer`); Sonnet para **ejecución guiada** por contrato/plantilla/grep. El
orquestador corre en Opus.

### 4. Skills
A diferencia de los agentes (subprocesos), los skills se **inyectan en contexto** con la tool `Skill`.
El orquestador los inyecta como "Project Standards" a los agentes que escriben (Skill Resolution
Contract): `scraping-patterns` y `anti-fragile-scrapers` a `scraper-dev`, `data-dedup-sqlite` a
`data-model`, `email-html` a `notifier`, `minimal-footprint` como lente transversal, etc.

### 5. Hooks — validación automática

**`PreToolUse` (Write|Edit) → `protect.sh`**: bloquea editar `.env` (secretos reales) y `*.db` (base
de runtime). El contrato de variables se cambia en `.env.example`.

**`PostToolUse` (Write|Edit) → `post_write.sh`** (dispatcher). Para archivos `.py` **del proyecto**
(no los del enjambre):
```
Claude escribe/edita un .py del proyecto
  → post_write.sh
    → validate_py.sh       (avisos: py_compile, requests sin timeout, except pelado, scraper sin try/except)  [no bloquea]
    → check_patterns.sh    (patrones prohibidos de references/patterns/scraper.patterns)                       [BLOQUEA exit 2]
    → recordatorio (additionalContext): mantené portales.md y README en sync
```
`check_patterns.sh` es **data-driven**: los patrones prohibidos (secretos hardcodeados, print de
secretos, etc.) viven en `references/patterns/scraper.patterns`. **Agregar una regla = agregar una
línea**, sin tocar el script.

**Notificaciones de escritorio**: `Notification` (`on_notification.sh`) y `Stop` (`on_stop.sh`, solo
si la tarea fue "larga" — umbral `TJ_NOTIFY_MIN_SECONDS`, default 45s, marcado por `mark_prompt.sh`)
avisan vía `notify.sh`, portable (macOS/WSL/Linux/bell). Best-effort, nunca bloquean.

---

## 🔄 Flujo típico: "El scraper de Computrabajo dejó de traer resultados"

```
1. ORQUESTADOR lee workspace.md + recibe el request
   ├── @scraper-doctor diagnostica (read-only): ¿selector muerto? ¿anti-bot? ¿JS-rendered? ¿no hay?
   │     └── si hay que cambiar de enfoque (API/headless) → Status: BLOCKED → consulta al usuario
   ├── @researcher confirma el selector nuevo contra el HTML vivo
   ├── @scraper-dev aplica el fix (HOOKS validan cada write)
   ├── @testing corre /probar (dry-run, sin mandar email)
   └── ORQUESTADOR actualiza references/portales.md + reporta (handoff git: commit a pedido)
```

---

## 🛠️ Comandos rápidos

| Comando | Hace |
|---------|------|
| `/scraper <portal\|url>` | Agregar un scraper nuevo |
| `/fix-scraper <portal>` | Diagnosticar y arreglar un scraper roto |
| `/inspeccionar <url>` | Traer el HTML vivo y proponer selectores (read-only) |
| `/probar` | Dry-run: corre el scraper sin mandar email |
| `/deploy` | Checklist de deploy a Railway |
| `/contexto` | Orientación extendida del entorno |
| `/salud` | Health check (workspace, python, deps, .env, compilación, git) |

---

## 📊 Resumen

| Capa | Cantidad | Rol |
|------|----------|-----|
| Entorno | `workspace.md` | Python, deploy, timezone, secretos (por dev) |
| Orquestador + convenciones | `CLAUDE.md` + `AGENTS.md` | Coordinación y reglas |
| Configuración | `settings.json` | Permisos + hooks |
| Agentes | 9 | Trabajo especializado |
| Skills | 9 | Conocimiento cargable |
| Commands | 7 | Atajos |
| Hooks | 11 | Validación, protección, sesión, notificaciones |
| References | 3 | Portales + gotchas + patterns del hook |
| Assets | 1 | Plantilla de email |

---

## 🧬 Qué se dejó afuera del enjambre NEXIT (y por qué)

Aplicando `minimal-footprint`: **SDD por módulo** (no hay módulos ni manifest), **`index.html` de
módulo / licencia OPL-1 / COPYRIGHT** (packaging Odoo), **`l10n-fiscal` y `odoo-migration`** (dominio
Odoo), y **Gitflow con ramas largas** (es un repo personal → flujo simple). Se conservó el esqueleto:
orquestador, subagentes con model tiering, skills inyectables, hooks data-driven, workspace por-dev y
references como conocimiento de dominio.

---

*Enjambre tracker-job — Claude Code · adaptado del enjambre NEXIT (Odoo), right-sized para scraping Python.*
