#!/bin/bash
# TempFer — Script de instalación
# Copia la app y elimina el bloqueo de Gatekeeper

set -e

APP="TempFer.app"
DEST="$HOME/Applications"

# Buscar la app en el directorio actual o carpeta padre
if [ -d "$APP" ]; then
    SRC="$APP"
elif [ -d "../$APP" ]; then
    SRC="../$APP"
else
    echo "❌  No se encontró $APP. Ejecuta este script desde la carpeta que contiene TempFer.app"
    exit 1
fi

echo "🌡  Instalando TempFer..."

# Crear ~/Applications si no existe
mkdir -p "$DEST"

# Copiar app
cp -R "$SRC" "$DEST/"

# Eliminar atributo de cuarentena (evita el bloqueo de Gatekeeper)
xattr -cr "$DEST/$APP"

echo "✅  TempFer instalado en $DEST"
echo "   Abre Launchpad o $DEST y haz doble click en TempFer."
