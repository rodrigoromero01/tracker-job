# 🐍 Job Tracker — Rastreador de Empleos Python Junior

Agente Python que rastrea empleos todos los días y manda un resumen por email.
Funciona 24/7 en Railway (nube gratuita) sin necesidad de dejar la PC encendida.

## Portales rastreados
- **PyAr** — python.org.ar (RSS oficial)
- **Computrabajo** — ar.computrabajo.com
- **BairesDev** — applicants.bairesdev.com
- **Wellfound** — wellfound.com/location/argentina

---

## Opción A — Deploy en Railway (recomendado)

### Paso 1: Subir a GitHub

```bash
git init
git add .
git commit -m "feat: job tracker inicial"
git remote add origin https://github.com/TU-USUARIO/job-tracker.git
git push -u origin main
```

### Paso 2: Crear proyecto en Railway

1. Ir a https://railway.app y crear cuenta (gratis con GitHub)
2. New Project → Deploy from GitHub repo
3. Seleccionar tu repo `job-tracker`
4. Railway detecta el Procfile automáticamente

### Paso 3: Variables de entorno en Railway

En tu proyecto → pestaña Variables → agregar:

```
EMAIL_FROM   → tu@gmail.com
EMAIL_TO     → tu@gmail.com
EMAIL_PASS   → xxxx xxxx xxxx xxxx
RUN_HOUR     → 8
RUN_MINUTE   → 0
```

### Paso 4: Deploy

Click Deploy → Railway instala dependencias y arranca el worker.
El agente corre todos los días a las 8am y te manda el resumen por email.

---

## Opción B — Local

```bash
pip install -r requirements.txt
cp .env.example .env   # editar con tus datos
python scraper.py      # probar una vez
python scheduler.py    # correr automáticamente
```

---

## Variables disponibles

| Variable     | Default | Descripción                    |
|--------------|---------|--------------------------------|
| EMAIL_FROM   | —       | Gmail de envío                 |
| EMAIL_TO     | —       | Gmail donde recibís el resumen |
| EMAIL_PASS   | —       | App Password de Google         |
| RUN_HOUR     | 8       | Hora de ejecución (0-23)       |
| RUN_MINUTE   | 0       | Minuto de ejecución            |

