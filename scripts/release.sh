#!/bin/bash
# Release de Fold: archive → firma Developer ID → notarización → staple → ZIP.
# NO contiene credenciales. Requiere estas variables de entorno:
#
#   FOLD_SIGN_IDENTITY   p. ej. "Developer ID Application: Nombre (TEAMID)"
#   FOLD_NOTARY_PROFILE  perfil de notarytool creado con:
#     xcrun notarytool store-credentials fold-notary \
#       --apple-id <apple-id> --team-id <TEAMID> --password <app-specific-pw>
#
# Uso: FOLD_SIGN_IDENTITY="..." FOLD_NOTARY_PROFILE=fold-notary ./scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(grep -m1 'MARKETING_VERSION = ' Fold.xcodeproj/project.pbxproj | sed 's/[^0-9.]*//g')
DIST="dist"
ARCHIVE="$DIST/Fold.xcarchive"
APP="$DIST/Fold.app"
ZIP="$DIST/Fold-$VERSION.zip"

if [ -z "${FOLD_SIGN_IDENTITY:-}" ]; then
  echo "⚠ Falta FOLD_SIGN_IDENTITY (certificado Developer ID Application)."
  echo "  Pendiente externo: certificado + Team ID. Con ellos, ejecuta:"
  echo '  FOLD_SIGN_IDENTITY="Developer ID Application: TU NOMBRE (TEAMID)" \'
  echo '  FOLD_NOTARY_PROFILE=fold-notary ./scripts/release.sh'
  exit 1
fi

echo "══ 1/6 · Archive Release ($VERSION)"
rm -rf "$DIST" && mkdir -p "$DIST"
xcodebuild -project Fold.xcodeproj -scheme Fold -configuration Release \
  -destination 'platform=macOS' archive -archivePath "$ARCHIVE" -quiet \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
cp -R "$ARCHIVE/Products/Applications/Fold.app" "$APP"

echo "══ 2/6 · Firma (Hardened Runtime, deep)"
codesign --force --deep --options runtime --timestamp \
  --sign "$FOLD_SIGN_IDENTITY" "$APP"

echo "══ 3/6 · Verificación local de la firma"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "══ 4/6 · Notarización"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "${FOLD_NOTARY_PROFILE:-fold-notary}" --wait

echo "══ 5/6 · Staple + re-empaquetado"
xcrun stapler staple "$APP"
rm "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "══ 6/6 · Verificación Gatekeeper"
spctl --assess --type execute --verbose=2 "$APP"
xcrun stapler validate "$APP"

echo "✓ Release listo: $ZIP"
