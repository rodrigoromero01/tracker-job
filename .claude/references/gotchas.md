# Gotchas — tracker-job

> Trampas verificadas del proyecto. El equivalente a `references/v{N}_gotchas.md` del enjambre Odoo.
> Cuando algo te muerda, documentalo acá con **síntoma → causa → fix**.

## 🔴 Railway tiene filesystem efímero → `empleos.db` se borra en cada deploy

- **Síntoma**: después de un redeploy (o reinicio del worker), llegan emails con empleos que ya habías visto. La deduplicación "se olvida".
- **Causa**: `empleos.db` es SQLite en disco local. El filesystem de Railway es **efímero**: cada build/redeploy arranca de cero. La base de dedup se pierde.
- **Fix**: para persistir de verdad, usar un **Railway Volume** montado (y apuntar `DB_PATH` ahí) o migrar la dedup a un store persistente (Postgres de Railway, Redis, o un servicio externo). Mientras tanto, asumir que tras un deploy puede repetirse un batch. Ver skills `railway-deploy` y `data-dedup-sqlite`.

## 🔴 Gmail exige App Password, no la contraseña de la cuenta

- **Síntoma**: `SMTPAuthenticationError` / "Username and Password not accepted".
- **Causa**: Gmail bloquea el login SMTP con la contraseña normal desde 2022. Requiere **App Password** (2FA activado + generar clave de aplicación de 16 caracteres).
- **Fix**: generar App Password en la cuenta Google y ponerla en `EMAIL_PASS` (formato `xxxx xxxx xxxx xxxx`, los espacios se aceptan). Nunca la contraseña real. Ver skill `secrets-hygiene`.

## 🟡 Los emails HTML necesitan CSS inline

- **Síntoma**: el email se ve sin estilos (o roto) en Gmail/Outlook, aunque en el navegador se vea bien.
- **Causa**: los clientes de correo **eliminan `<style>` y `<head>`** y no soportan CSS moderno (flexbox, grid, variables). Solo respetan `style=""` inline y tablas.
- **Fix**: estilos inline en cada elemento (como ya hace `armar_email_html()`). Para layouts complejos, usar tablas, no divs con flex. Ver skill `email-html`.

## 🟡 Un scraper que devuelve 0 casi nunca significa "no hay empleos"

- **Síntoma**: `scrape_X()` imprime "0 encontrados" de forma consistente.
- **Causa**: selector CSS muerto (el sitio cambió el markup), anti-bot (403/429/captcha), o contenido JS-rendered que BeautifulSoup no ve.
- **Fix**: confirmar contra el HTML vivo (agente `researcher`/`scraper-doctor`), no asumir. Ver `references/portales.md` y skill `anti-fragile-scrapers`.

## 🟡 Sin `User-Agent` de navegador muchos sitios responden 403

- **Síntoma**: `requests.get` devuelve 403/406 o HTML de "acceso denegado".
- **Causa**: el sitio filtra el `User-Agent` por defecto de `requests` (`python-requests/x.y`).
- **Fix**: mandar un `User-Agent` de navegador real (ya se hace en Computrabajo/BairesDev). No abusar: respetar rate-limits y `robots.txt`. Ver skill `scraping-patterns`.

## 🟡 `requests` sin `timeout` cuelga el worker para siempre

- **Síntoma**: el worker de Railway queda "vivo" pero no vuelve a mandar emails; el cron no dispara.
- **Causa**: un `requests.get` sin `timeout` puede bloquear el hilo indefinidamente si el servidor no responde. Como el scheduler es `BlockingScheduler`, cuelga toda la app.
- **Fix**: **siempre** `timeout=` en cada request (el hook `validate_py.sh` lo avisa). Ver skill `scraping-patterns`.

## 🟢 Timezone hardcodeada a Buenos Aires

- **Síntoma**: el email llega a una hora inesperada si el server está en otra TZ.
- **Causa**: `BlockingScheduler(timezone="America/Argentina/Buenos_Aires")` fija la TZ; `RUN_HOUR`/`RUN_MINUTE` se interpretan en esa zona.
- **Fix**: si se cambia de región, parametrizar la TZ por env var. Documentar en `workspace.md` (`TIMEZONE`). Ver skill `scheduling-apscheduler`.

## 🟢 El scheduler corre una vez al arrancar (job `date`)

- **Nota**: `scheduler.py` agrega `scheduler.add_job(run, "date")` → corre `run()` inmediatamente al bootear, además del cron diario. Es intencional (verificar que todo funciona en el deploy), pero significa que **cada redeploy dispara un email**. Tenerlo presente al iterar en producción.
