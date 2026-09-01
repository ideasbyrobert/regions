#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Regions"
BUNDLE_ID="com.ideasbyrobert.Places"
APP_IDENTITY="${APP_IDENTITY:-Developer ID Application: ROBERT KARAPETYAN (X87D35HM5V)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_NOTARY}"
TEAM_ID="${TEAM_ID:-X87D35HM5V}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFO_PLIST="$ROOT/Resources/Info.plist"
ENTITLEMENTS="$ROOT/Resources/Regions.entitlements"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
BUILD="$(plutil -extract CFBundleVersion raw "$INFO_PLIST")"
DIST="$ROOT/dist"
STAGE="$(mktemp -d /private/tmp/regions-release.XXXXXX)"
BUNDLE="$STAGE/$APP_NAME.app"

cleanup()
{
    if mount | grep -Fq "on ${STAGE}/MountedDMG " 2>/dev/null; then
        diskutil eject "${STAGE}/MountedDMG" >/dev/null 2>&1 || true
    fi
    rm -rf "$STAGE"
}
trap cleanup EXIT

say()
{
    printf '==> %s\n' "$*"
}

die()
{
    printf 'error: %s\n' "$*" >&2
    exit 65
}

identities="$(security find-identity -v -p codesigning)"
[[ "$identities" == *"$APP_IDENTITY"* ]] || die "the Developer ID Application identity is unavailable."

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 || die "the ${NOTARY_PROFILE} notary profile is unusable."

say "1. Building universal $APP_NAME (x86_64 + arm64)"
cd "$ROOT"

build_slice()
{
    local arch="$1"
    local triple="$arch-apple-macosx15.0"
    local scratch_dir="$ROOT/.build/release-$arch"
    local bin_dir
    say "    compiling $arch ($triple)"
    swift build -c release --triple "$triple" --scratch-path "$scratch_dir"
    bin_dir="$(swift build -c release --triple "$triple" --scratch-path "$scratch_dir" --show-bin-path)"
    [ -x "$bin_dir/$APP_NAME" ] || die "$arch build product missing: $bin_dir/$APP_NAME"
    cp "$bin_dir/$APP_NAME" "$STAGE/$arch-$APP_NAME"
}

build_slice arm64
build_slice x86_64

UNIVERSAL_DIR="$STAGE/universal"
mkdir -p "$UNIVERSAL_DIR"
APP_EXEC="$UNIVERSAL_DIR/$APP_NAME"

lipo -create "$STAGE/arm64-$APP_NAME" "$STAGE/x86_64-$APP_NAME" -output "$APP_EXEC"
for architecture in x86_64 arm64; do
    lipo "$APP_EXEC" -verify_arch "$architecture" || die "release executable is missing $architecture: $APP_EXEC"
done
say "    app architectures: $(lipo "$APP_EXEC" -archs)"

say "2. Assembling App Bundle ($BUNDLE)"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

cp "$APP_EXEC" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp "$INFO_PLIST" "$BUNDLE/Contents/Info.plist"

say "3. Rendering and bundling App Icon"
ICON_TMP="$(mktemp -d)"
if swift "$ROOT/tools/make_icon.swift" "$ICON_TMP" >/dev/null 2>&1 \
   && iconutil -c icns "$ICON_TMP/Regions.iconset" -o "$BUNDLE/Contents/Resources/Regions.icns" 2>/dev/null; then
    say "    bundled Regions.icns"
else
    say "    (icon generation skipped)"
fi
rm -rf "$ICON_TMP"

say "4. Embedding and signing Sparkle"
"$ROOT/tools/embed_sparkle.sh" "$BUNDLE" "$APP_IDENTITY" "$ENTITLEMENTS"

say "5. Signing App Bundle with Developer ID & Hardened Runtime"
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" \
    --sign "$APP_IDENTITY" "$BUNDLE/Contents/MacOS/$APP_NAME"
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" \
    --sign "$APP_IDENTITY" "$BUNDLE"

codesign --verify --deep --strict --verbose=2 "$BUNDLE" 2>&1 | sed 's/^/    /'

say "6. Notarising the app bundle"
APP_ZIP="$STAGE/$APP_NAME-app.zip"
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE" "$APP_ZIP"

APP_RESULT="$(xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" \
              --wait --output-format json)"
APP_STATUS="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['status'])" "$APP_RESULT")"
if [ "$APP_STATUS" != "Accepted" ]; then
    printf '  App notarization failed with status %s:\n%s\n' "$APP_STATUS" "$APP_RESULT"
    exit 1
fi
xcrun stapler staple "$BUNDLE"
xcrun stapler validate "$BUNDLE" >/dev/null || die "the app bundle has no stapled ticket after stapling"
say "    app stapled — validates offline"

say "7. Packaging DMG ($APP_NAME.dmg)"
mkdir -p "$DIST" "$STAGE/dmg"
cp -R "$BUNDLE" "$STAGE/dmg/"
ln -s /Applications "$STAGE/dmg/Applications"

DMG="$STAGE/$APP_NAME-$VERSION-$BUILD.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE/dmg" \
               -ov -format UDZO "$DMG" >/dev/null 2>&1

codesign --force --sign "$APP_IDENTITY" --timestamp "$DMG"
say "DMG created and signed"

say "8. Notarising the DMG ($NOTARY_PROFILE)..."
DMG_RESULT="$(xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" \
              --wait --output-format json)"
DMG_STATUS="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['status'])" "$DMG_RESULT")"
if [ "$DMG_STATUS" != "Accepted" ]; then
    printf '  Notarization failed with status %s:\n%s\n' "$DMG_STATUS" "$DMG_RESULT"
    exit 1
fi
say "Notarization accepted by Apple"

say "9. Stapling the DMG"
xcrun stapler staple "$DMG" >/dev/null
say "Stapled successfully"

say "10. Gatekeeper Verification"
spctl -a -t exec -v "$BUNDLE" 2>&1 | sed 's/^/    /'
spctl -a -t open --context context:primary-signature -v "$DMG" 2>&1 | sed 's/^/    /'
xcrun stapler validate "$DMG" 2>&1 | sed 's/^/    /'

MOUNT_POINT="${STAGE}/MountedDMG"
mkdir -p "$MOUNT_POINT"
diskutil image attach --mountOptions nobrowse --readOnly --mountPoint "$MOUNT_POINT" "$DMG" >/dev/null

if xcrun stapler validate "$MOUNT_POINT/$APP_NAME.app" >/dev/null 2>&1; then
    codesign --verify --deep --strict --verbose=2 "$MOUNT_POINT/$APP_NAME.app" >/dev/null 2>&1 || {
        diskutil eject "$MOUNT_POINT" >/dev/null 2>&1 || true
        die "the app inside the DMG has invalid nested code signatures"
    }
    for architecture in x86_64 arm64; do
        lipo "$MOUNT_POINT/$APP_NAME.app/Contents/MacOS/$APP_NAME" -verify_arch "$architecture" || {
            diskutil eject "$MOUNT_POINT" >/dev/null 2>&1 || true
            die "the app inside the DMG is missing $architecture"
        }
    done
    diskutil eject "$MOUNT_POINT" >/dev/null 2>&1 || true
    say "    the universal app is stapled and all nested code is intact inside the DMG"
else
    diskutil eject "$MOUNT_POINT" >/dev/null 2>&1 || true
    die "the app inside the DMG has no stapled ticket"
fi

say "11. Promoting verified artifacts into dist/"
mkdir -p "$DIST"
cp "$DMG" "$DIST/$APP_NAME.dmg"
cp "$DMG" "$DIST/$APP_NAME-$VERSION-$BUILD.dmg"
(cd "$DIST" && shasum -a 256 "$APP_NAME.dmg" "$APP_NAME-$VERSION-$BUILD.dmg") > "$DIST/SHA256SUMS"

say "12. Publishing to the Sparkle update channel on Cloudflare R2"
if [ "${REGIONS_PUBLISH:-${PLACES_PUBLISH:-1}}" = "1" ]; then
    "$ROOT/tools/publish_update.sh" "$DIST/$APP_NAME.dmg" "$BUNDLE"
else
	say "    (skipped publishing: REGIONS_PUBLISH=0)"
fi

say "=== Release Complete ==="
ls -lh "$DIST"
