#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-all}"
APP_NAME="Regions"
FIXTURE_APP_NAME="WindowFixtureApp"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
ARCHITECTURE="$(uname -m)"
DEVELOPMENT_TEAM_IDENTIFIER="${GRIDWINDOWMANAGER_DEVELOPMENT_TEAM:-X87D35HM5V}"
DEVELOPMENT_SIGNING_IDENTITY="${GRIDWINDOWMANAGER_DEVELOPMENT_IDENTITY:-Apple Development}"
XCODEGEN="${XCODEGEN:-xcodegen}"
XCODEBUILD_ARGUMENTS=(
    -project "$ROOT_DIR/Regions.xcodeproj"
    -scheme "$APP_NAME"
    -configuration Debug
    -derivedDataPath "$DERIVED_DATA"
    -destination "platform=macOS,arch=$ARCHITECTURE"
    CODE_SIGNING_ALLOWED=YES
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$DEVELOPMENT_SIGNING_IDENTITY"
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM_IDENTIFIER"
    -quiet
    test
)

case "$MODE" in
    all)
        ;;
    --live-accessibility|live-accessibility)
        XCODEBUILD_ARGUMENTS+=(
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) GRIDWINDOWMANAGER_RUN_AX_TESTS'
            "-only-testing:RegionsTests/AccessibilityIntegrationTests"
        )
        ;;
    --live-app-accessibility|live-app-accessibility)
        XCODEBUILD_ARGUMENTS+=(
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) GRIDWINDOWMANAGER_RUN_APP_AX_UI_TESTS'
            "-only-testing:RegionsUITests/LiveAccessibilityUITests"
        )
        ;;
    --live-terminal|live-terminal)
        XCODEBUILD_ARGUMENTS+=(
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) GRIDWINDOWMANAGER_RUN_TERMINAL_TESTS'
            "-only-testing:RegionsTests/TerminalAccessibilityIntegrationTests"
        )
        ;;
    *)
        printf 'usage: %s [--live-accessibility|--live-app-accessibility|--live-terminal]\n' "$0" >&2
        exit 2
        ;;
esac

cd "$ROOT_DIR"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "$FIXTURE_APP_NAME" >/dev/null 2>&1 || true
"$XCODEGEN" generate
xcodebuild "${XCODEBUILD_ARGUMENTS[@]}"
