---
name: email-html
description: Construir emails HTML que se vean bien en Gmail/Outlook — CSS SIEMPRE inline, tablas para layout, MIMEMultipart('alternative') + MIMEText(html). Cargá al tocar la plantilla o el envío del email.
---
# Email HTML que sobrevive a Gmail/Outlook

El resumen diario llega como email HTML. El generador real es `armar_email_html()` y el envío es
`enviar_email()` en `scraper.py`. Cambios al email los ejecuta **@notifier**.

Fuentes de verdad: gotcha "los clientes borran `<style>`/`<head>` → CSS inline" en
`.claude/references/gotchas.md`; App Password de Gmail (para el SMTP) en el mismo archivo y en la skill
`secrets-hygiene`. Si existe una plantilla de referencia standalone vive en
`.claude/assets/email-template.html`; la fuente viva es siempre `armar_email_html()`.

## Regla nº1: CSS SIEMPRE inline

Los clientes de correo (sobre todo Gmail y Outlook) **eliminan `<style>` y `<head>`** y no soportan
CSS moderno (flexbox, grid, variables, media queries fiables). Solo respetan `style=""` inline.

```python
# ✅ inline, se ve igual en todos lados
'<div style="border:1px solid #e0e0e0;border-radius:8px;padding:14px;background:#fff">...</div>'

# ❌ NO: un <style> en el <head> lo borra Gmail y el email queda sin formato
'<head><style>.card { border:1px solid #e0e0e0 }</style></head>'
```

## Regla nº2: tablas para layout complejo, no divs con flex

Para una tarjeta simple, un `<div>` con `style` inline alcanza (como ya usa `armar_email_html`). Para
layouts de columnas / grillas, usá `<table>` — es lo único que renderiza consistente en Outlook.

```python
html = """
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px">
  <tr>
    <td style="padding:12px;vertical-align:top;width:50%">Columna izquierda</td>
    <td style="padding:12px;vertical-align:top;width:50%">Columna derecha</td>
  </tr>
</table>
"""
```

## Estructura del mensaje: MIMEMultipart('alternative')

`alternative` = el cliente elige la mejor versión que sepa mostrar. Si sumás una versión texto plano,
adjuntala **antes** que la HTML (el orden importa: la última es la preferida).

```python
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def enviar_email(nuevos: list[Empleo]):
    msg = MIMEMultipart("alternative")
    msg["Subject"] = asunto
    msg["From"] = EMAIL_FROM               # os.getenv, nunca literal
    msg["To"] = EMAIL_TO

    # msg.attach(MIMEText(texto_plano, "plain"))   # opcional, va primero si se usa
    msg.attach(MIMEText(armar_email_html(nuevos), "html"))

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(EMAIL_FROM, EMAIL_PASS)   # EMAIL_PASS = App Password de Gmail
            server.sendmail(EMAIL_FROM, EMAIL_TO, msg.as_string())
        print("  Email enviado correctamente.")
    except Exception as e:
        print(f"  Error enviando email: {e}")       # NUNCA imprimas EMAIL_PASS (ver secrets-hygiene)
```

- `SMTP_SSL` en 465 con `with` cierra la conexión sola. Alternativa: `SMTP(...:587)` + `starttls()`.
- Los secretos (`EMAIL_FROM/TO/PASS`) vienen por `os.getenv` (skill `secrets-hygiene`). El hook bloquea
  literales y `print()` de credenciales.

## Buenas prácticas de render

- **Ancho ~600px** (`max-width:600px` / `max-width:620px` como ya usa el proyecto): es lo que entra en
  el panel de lectura de la mayoría de los clientes sin scroll horizontal.
- **Colores inline** en hex (`#2E75B6`, `#1F4E78`), no `var(--...)` ni `hsl()` exóticos.
- **Fuentes web-safe** (`font-family:Arial,sans-serif`): no cargues Google Fonts (muchos clientes las
  bloquean).
- **Emojis** como texto (🐍 🌐 📍) renderizan bien; no dependas de íconos por CSS/imagen externa.
- **Imágenes**: evitalas o usá `alt`; muchos clientes las bloquean por defecto. El proyecto usa emojis.
- **Siempre manejá el caso "sin novedades"** con su propio bloque (ya lo hace `armar_email_html`): el
  email igual sale (confirma que el agente está vivo).

## Snippet de tarjeta (patrón del proyecto)

```python
def tarjetas(lista):
    if not lista:
        return "<p style='color:#888'>Ninguno en esta categoría hoy.</p>"
    html = ""
    for e in lista:
        html += f"""
        <div style="border:1px solid #e0e0e0;border-radius:8px;padding:14px;margin-bottom:12px;background:#fff">
            <div style="font-weight:600;font-size:15px;color:#1a1a1a">{e.titulo}</div>
            <div style="color:#555;font-size:13px;margin:4px 0">{e.empresa} · {e.ubicacion}</div>
            <div style="font-size:12px;color:#888;margin-bottom:8px">Fuente: {e.fuente} · {e.fecha}</div>
            <a href="{e.url}" style="background:#2E75B6;color:#fff;padding:6px 14px;border-radius:5px;text-decoration:none;font-size:13px">Ver oferta →</a>
        </div>"""
    return html
```

## Verificación (dry-run, sin enviar)

Para ver el HTML sin mandar el email, generalo y volcalo a un archivo, abrilo en el navegador:

```python
with open("preview.html", "w", encoding="utf-8") as f:
    f.write(armar_email_html(nuevos_de_prueba))
```

Es el patrón que usa @testing / `/probar`. Ojo: el navegador es más permisivo que Gmail — si podés,
mandate un email de prueba a vos mismo para el render final.

## Do / Don't

- ✅ `style=""` inline en cada elemento.
- ✅ `<table>` para columnas; `max-width:600px`; colores hex; fuentes web-safe.
- ✅ `MIMEMultipart("alternative")` + `MIMEText(html, "html")`.
- ❌ `<style>`/`<head>` con reglas CSS (Gmail las borra).
- ❌ flexbox/grid/`var(--x)` para el layout del email.
- ❌ Google Fonts / imágenes externas críticas para que se entienda.
- ❌ Imprimir `EMAIL_PASS` al debuggear el envío.
