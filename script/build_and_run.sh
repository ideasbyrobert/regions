#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Regions"
BUNDLE_ID="com.ideasbyrobert.Places"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Resources/Regions.entitlements"
DEVELOPMENT_TEAM_IDENTIFIER="${GRIDWINDOWMANAGER_DEVELOPMENT_TEAM:-X87D35HM5V}"
XCODEGEN="${XCODEGEN:-xcodegen}"

resolve_signing_identity()
{
    if [ -n "${GRIDWINDOWMANAGER_DEVELOPMENT_IDENTITY:-}" ]
    then
        printf '%s\n' "$GRIDWINDOWMANAGER_DEVELOPMENT_IDENTITY"
        return
    fi
    local identities
    identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    if [[ "$identities" == *"Apple Development"* ]]
    then
        printf '%s\n' "Apple Development"
        return
    fi
    if [[ "$identities" == *"Developer ID Application: ROBERT KARAPETYAN ($DEVELOPMENT_TEAM_IDENTIFIER)"* ]]
    then
        printf '%s\n' "Developer ID Application: ROBERT KARAPETYAN ($DEVELOPMENT_TEAM_IDENTIFIER)"
        return
    fi
    printf '%s\n' "-"
}

DEVELOPMENT_SIGNING_IDENTITY="$(resolve_signing_identity)"

build_with_swiftpm()
{
    local stage_dir="$DERIVED_DATA/SwiftPMStage"
    rm -rf "$stage_dir"
    mkdir -p "$stage_dir"

    for arch in arm64 x86_64
    do
        local triple="${arch}-apple-macosx15.0"
        local scratch_dir="$ROOT_DIR/.build/debug-${arch}"
        swift build -c debug --product "$APP_NAME" --triple "$triple" --scratch-path "$scratch_dir"
        local bin_dir
        bin_dir="$(swift build -c debug --product "$APP_NAME" --triple "$triple" --scratch-path "$scratch_dir" --show-bin-path)"
        cp "$bin_dir/$APP_NAME" "$stage_dir/${arch}-$APP_NAME"
    done

    rm -rf "$APP_BUNDLE"
    mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
    lipo -create "$stage_dir/arm64-$APP_NAME" "$stage_dir/x86_64-$APP_NAME" -output "$APP_BINARY"
    cp "$INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"

    local icon_tmp
    icon_tmp="$(mktemp -d)"
    if swift "$ROOT_DIR/tools/make_icon.swift" "$icon_tmp" >/dev/null 2>&1 \
       && iconutil -c icns "$icon_tmp/Regions.iconset" -o "$APP_BUNDLE/Contents/Resources/Regions.icns" 2>/dev/null
    then
        :
    fi
    rm -rf "$icon_tmp" "$stage_dir"

    "$ROOT_DIR/tools/embed_sparkle.sh" "$APP_BUNDLE" "$DEVELOPMENT_SIGNING_IDENTITY" "$ENTITLEMENTS"

    local sign_args=(--force --entitlements "$ENTITLEMENTS" --sign "$DEVELOPMENT_SIGNING_IDENTITY")
    if [ "$DEVELOPMENT_SIGNING_IDENTITY" != "-" ]
    then
        sign_args+=(--options runtime --timestamp=none)
    else
        sign_args+=(--timestamp=none)
    fi
    codesign "${sign_args[@]}" "$APP_BINARY"
    codesign "${sign_args[@]}" "$APP_BUNDLE"
}

build_app()
{
    cd "$ROOT_DIR"
    if command -v "$XCODEGEN" >/dev/null 2>&1 && [ "$DEVELOPMENT_SIGNING_IDENTITY" = "Apple Development" ]
    then
        "$XCODEGEN" generate
        xcodebuild \
            -project "$ROOT_DIR/Regions.xcodeproj" \
            -scheme "$APP_NAME" \
            -configuration Debug \
            -derivedDataPath "$DERIVED_DATA" \
            ARCHS="arm64 x86_64" \
            ONLY_ACTIVE_ARCH=NO \
            CODE_SIGNING_ALLOWED=YES \
            CODE_SIGN_STYLE=Manual \
            CODE_SIGN_IDENTITY="$DEVELOPMENT_SIGNING_IDENTITY" \
            DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM_IDENTIFIER" \
            build
    else
        build_with_swiftpm
    fi
}

open_app()
{
    /usr/bin/open "$APP_BUNDLE"
}

if [ "$MODE" != "--build-only" ] && [ "$MODE" != "build" ]
then
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi
build_app

case "$MODE" in
    --build-only|build)
        ;;
    run)
        open_app
        ;;
    --debug|debug)
        lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        open_app
        for attempt in 1 2 3 4 5
        do
            if pgrep -x "$APP_NAME" >/dev/null
            then
                exit 0
            fi
            sleep 1
        done
        exit 1
        ;;
    *)
        printf 'usage: %s [run|build|--build-only|--debug|--logs|--telemetry|--verify]\n' "$0" >&2
        exit 2
        ;;
esac
