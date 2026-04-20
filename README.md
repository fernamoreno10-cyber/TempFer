# TempFer 🌡️

Monitor de temperatura en vivo para la barra de menús del Mac. Nativo en Swift, sin sudo, sin dependencias externas.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20M2%20M3%20M4-green) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)

## ¿Qué hace?

- Muestra la temperatura del CPU en la barra de menús en tiempo real
- Colores por nivel de temperatura:
  - 🟢 Verde — Óptima (< 50°C)
  - 🟡 Amarillo — Normal (50–70°C)
  - 🟠 Naranja — Alta (70–85°C)
  - 🔴 Rojo — Crítica (> 85°C)
- Muestra batería y SSD en el menú
- Submenu con todos los sensores del dispositivo
- Opción para iniciar automáticamente con el Mac
- Color activable/desactivable desde el menú

## Requisitos

- macOS 13 Ventura o superior
- Apple Silicon (M1, M2, M3, M4)

## Instalación

1. Descarga `TempFer.zip` desde [Releases](../../releases/latest)
2. Descomprime y mueve `TempFer.app` a tu carpeta `/Applications`
3. Clic derecho → **Abrir** → **Abrir de todas formas** (solo la primera vez, por Gatekeeper)

> La app no está firmada con Apple Developer ID. macOS pide confirmación una vez. No hay malware — el código fuente está aquí para revisarlo.

## Compilar desde el código fuente

Requiere Xcode Command Line Tools y Swift 5.9+.

```bash
git clone https://github.com/fernamoreno10-cyber/TempFer.git
cd TempFer
swift build -c release

# Crear el .app manualmente
APP=/Applications/TempFer.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/TempFer "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
```

## Cómo funciona

Lee los sensores térmicos directamente vía `IOHIDEventSystemClient` del framework IOKit de Apple — la misma ruta que usan apps como Stats o iStatistica. No requiere `sudo` ni acceso especial.

Sensores disponibles en M4:
- `PMU tdie*` — núcleos de rendimiento (P-cores)
- `PMU2 tdie*` — núcleos de eficiencia (E-cores)
- `gas gauge battery` — batería
- `NAND CH0 temp` — almacenamiento SSD

## Licencia

MIT
