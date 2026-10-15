#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-all}"
APP_NAME="Regions"
FIXTURE_APP_NAME="WindowFixtureApp"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
ARCHITECTURE="$(uname -m)"
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

SWIFT_TEST_ARGUMENTS=()

case "$MODE" in
    all)
        ;;
    --live-accessibility|live-accessibility)
        XCODEBUILD_ARGUMENTS+=(
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) GRIDWINDOWMANAGER_RUN_AX_TESTS'
            "-only-testing:RegionsTests/AccessibilityIntegrationTests"
        )
        SWIFT_TEST_ARGUMENTS+=(
            -Xswiftc -DGRIDWINDOWMANAGER_RUN_AX_TESTS
            --filter AccessibilityIntegrationTests
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
        SWIFT_TEST_ARGUMENTS+=(
            -Xswiftc -DGRIDWINDOWMANAGER_RUN_TERMINAL_TESTS
            --filter TerminalAccessibilityIntegrationTests
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

if command -v "$XCODEGEN" >/dev/null 2>&1 && [ "$DEVELOPMENT_SIGNING_IDENTITY" = "Apple Development" ]
then
    "$XCODEGEN" generate
    xcodebuild "${XCODEBUILD_ARGUMENTS[@]}"
else
    swift test ${SWIFT_TEST_ARGUMENTS[@]+"${SWIFT_TEST_ARGUMENTS[@]}"}
fi
