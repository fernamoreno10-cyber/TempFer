# TempFer 🌡️

Monitor de temperatura en vivo para la barra de menús del Mac. Nativo en Swift, sin sudo, sin dependencias externas.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20M2%20M3%20M4-green) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![Version](https://img.shields.io/badge/version-2.0-purple)

## ¿Qué hace?

- **3 gauges animados** (CPU, Batería, SSD) con arco estilo velocímetro
- Temperatura con colores: Óptima / Normal / Alta / Crítica
- Lista de procesos activos con barras de uso de CPU
- **Asistente IA** — consejos contextuales en español vía Claude de Anthropic
- **Notificaciones del sistema** con los consejos de la IA
- Ventana de Preferencias nativa (⌘,)
- Hover sobre el icono → popover con animación
- Inicio automático con el Mac

## Instalación rápida

### Opción A — Script (recomendado)
```bash
# Descarga, descomprime y ejecuta:
cd ~/Downloads/TempFer-2.0
bash install.sh
```
El script copia la app y elimina el bloqueo de Gatekeeper automáticamente.

### Opción B — Manual
1. Descarga `TempFer.zip` desde [Releases](../../releases/latest)
2. Descomprime y arrastra `TempFer.app` a `~/Applications` o `/Applications`
3. **Si macOS bloquea la app:**
   - Ve a **Configuración del Sistema → Privacidad y seguridad**
   - Haz scroll hasta ver el mensaje de TempFer
   - Haz click en **"Abrir de todos modos"**

   O desde Terminal (más rápido):
   ```bash
   xattr -cr ~/Applications/TempFer.app
   ```

> **¿Por qué el bloqueo?** TempFer no está firmada con Apple Developer ID (requiere $99/año). El código fuente completo está aquí para que lo revises — sin telemetría, sin red, excepto las llamadas opcionales a la API de Anthropic que tú configuras.

## Configurar el Asistente IA (opcional)

1. Abre TempFer → click derecho → **Preferencias** (o `⌘,`)
2. Sección **Asistente IA** → pega tu API key de [Anthropic](https://console.anthropic.com/)
3. Elige la frecuencia: 15min / 30min / 1h / 2h / 4h / Desactivado
4. Activa notificaciones del sistema si quieres que los consejos lleguen aunque el popover esté cerrado

Los consejos analizan temperatura, tiempo de sesión y procesos activos. Ejemplos:
- *"Llevas 4 horas sin descanso y tu CPU está a 80°. Toma 15 minutos."*
- *"Chrome está consumiendo mucho. Cierra algunas pestañas."*
- *"Tu batería está caliente. Desconecta el cargador unos minutos."*

## Requisitos

- macOS 13 Ventura o superior
- Apple Silicon (M1, M2, M3, M4)
- API key de Anthropic (solo para la función de IA — totalmente opcional)

## Compilar desde el código fuente

```bash
git clone https://github.com/fernamoreno10-cyber/TempFer.git
cd TempFer
swift build -c release

APP=~/Applications/TempFer.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/TempFer "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
xattr -cr "$APP"
open "$APP"
```

## Cómo funciona

Lee los sensores térmicos vía `IOHIDEventSystemClient` (IOKit) — sin `sudo`, sin acceso especial. Misma ruta que Stats o iStatistica.

Sensores en M4:
- `PMU tdie*` — núcleos de rendimiento (P-cores)
- `PMU2 tdie*` — núcleos de eficiencia (E-cores)
- `gas gauge battery` — batería
- `NAND CH0 temp` — SSD

## Licencia

MIT
