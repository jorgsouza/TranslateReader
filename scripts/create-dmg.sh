#!/bin/bash
# Script para criar DMG instalável do TranslateReader

set -e

echo "🦫 TranslateReader - Criando DMG instalável"
echo "============================================"

# Diretórios
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/dist"
APP_NAME="TranslateReader"
DMG_NAME="TranslateReader-Installer"

# Limpar builds anteriores
echo "📦 Limpando builds anteriores..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build Release
echo "🔨 Compilando versão Release..."
cd "$PROJECT_DIR"
xcodebuild -project TranslateReader.xcodeproj \
    -scheme TranslateReader \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/xcode" \
    -arch arm64 \
    -arch x86_64 \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

# Copiar app
echo "📋 Preparando app..."
APP_PATH="$BUILD_DIR/xcode/Build/Products/Release/$APP_NAME.app"
STAGING_DIR="$BUILD_DIR/dmg-staging"

mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"

# Criar link para Applications
ln -s /Applications "$STAGING_DIR/Applications"

# Criar DMG
echo "💿 Criando DMG..."
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# Limpar staging
rm -rf "$STAGING_DIR"

echo ""
echo "✅ DMG criado com sucesso!"
echo "📍 Localização: $DMG_PATH"
echo ""
echo "📝 Para instalar:"
echo "   1. Abra o arquivo $DMG_NAME.dmg"
echo "   2. Arraste TranslateReader para a pasta Applications"
echo "   3. Na primeira vez, clique com Ctrl+Click > Abrir"
echo ""

# Abrir pasta com o DMG
open "$BUILD_DIR"
