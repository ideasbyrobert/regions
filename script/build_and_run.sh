#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Regions"
BUNDLE_ID="com.ideasbyrobert.Places"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
DEVELOPMENT_TEAM_IDENTIFIER="${GRIDWINDOWMANAGER_DEVELOPMENT_TEAM:-X87D35HM5V}"
DEVELOPMENT_SIGNING_IDENTITY="${GRIDWINDOWMANAGER_DEVELOPMENT_IDENTITY:-Apple Development}"
XCODEGEN="${XCODEGEN:-xcodegen}"

build_app()
{
    cd "$ROOT_DIR"
    "$XCODEGEN" generate
    xcodebuild \
        -project "$ROOT_DIR/Regions.xcodeproj" \
        -scheme "$APP_NAME" \
        -configuration Debug \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="$DEVELOPMENT_SIGNING_IDENTITY" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM_IDENTIFIER" \
        build
}

open_app()
{
    /usr/bin/open "$APP_BUNDLE"
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
build_app

case "$MODE" in
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
        printf 'usage: %s [run|--debug|--logs|--telemetry|--verify]\n' "$0" >&2
        exit 2
        ;;
esac
