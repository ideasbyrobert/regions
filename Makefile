SHELL := /bin/bash
.DEFAULT_GOAL := help

APP_NAME := Regions
PROJECT := $(APP_NAME).xcodeproj
SCHEME := $(APP_NAME)
XCODEGEN ?= xcodegen
DERIVED_DATA ?= $(CURDIR)/.build/DerivedData
ARCHITECTURE ?= $(shell uname -m)
DEVELOPMENT_TEAM ?= $(if $(GRIDWINDOWMANAGER_DEVELOPMENT_TEAM),$(GRIDWINDOWMANAGER_DEVELOPMENT_TEAM),X87D35HM5V)
DEVELOPMENT_IDENTITY ?= $(if $(GRIDWINDOWMANAGER_DEVELOPMENT_IDENTITY),$(GRIDWINDOWMANAGER_DEVELOPMENT_IDENTITY),Apple Development)
APP_IDENTITY ?= Developer ID Application: ROBERT KARAPETYAN (X87D35HM5V)
NOTARY_PROFILE ?= AC_NOTARY
# Keep the legacy variable as an input alias so existing release invocations
# remain compatible while the product is renamed to Regions.
REGIONS_PUBLISH ?= $(if $(PLACES_PUBLISH),$(PLACES_PUBLISH),1)
TEST_MODE ?=

.PHONY: all help generate resolve hygiene tidy build package-build test test-live-accessibility test-live-app-accessibility test-live-terminal run debug logs telemetry verify smoke lint check release release-no-publish clean

all: build

help:
	@printf '%s\n' \
		'generate                    create Regions.xcodeproj with XCODEGEN=... (default: xcodegen)' \
		'build                       debug app build' \
		'package-build               SwiftPM release build' \
		'test                        deterministic Xcode test suite' \
		'test-live-accessibility    real-window Accessibility integration test' \
		'test-live-app-accessibility end-to-end app Accessibility test' \
		'test-live-terminal         real Terminal automation integration test' \
		'run                         build and launch Regions' \
		'debug|logs|telemetry|verify launch with the matching diagnostic mode' \
		'release                     universal signed, notarized, and published DMG' \
		'release-no-publish          release without R2 publication' \
		'REGIONS_PUBLISH=0           skip R2 publication (legacy PLACES_PUBLISH accepted)' \
		'lint                        validate manifests, plists, and shell scripts' \
		'hygiene                     verify no Markdown, empty files, or empty directories remain' \
		'tidy                        remove Markdown, empty files, and empty directories' \
		'check                       lint, build, tests, and app smoke check' \
		'clean                       remove local SwiftPM/Xcode build products' \
		'tidy                        remove empty directories'

generate:
	$(XCODEGEN) generate

resolve:
	swift package resolve

hygiene:
	@test -z "$$(find . -type f -iname '*.md' -not -path './.git/*' -not -path './.build/*' -not -path './.derived/*' -print -quit)"
	@test -z "$$(find . -type f -empty -not -path './.git/*' -not -path './.build/*' -not -path './.derived/*' -print -quit)"
	@test -z "$$(find . -type d -empty -not -path './.git/*' -not -path './.build/*' -not -path './.derived/*' -print -quit)"

build: generate
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=YES \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="$(DEVELOPMENT_IDENTITY)" \
		DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)" \
		build

package-build:
	swift build -c release

test:
	./script/test.sh $(TEST_MODE)

test-live-accessibility:
	./script/test.sh --live-accessibility

test-live-app-accessibility:
	./script/test.sh --live-app-accessibility

test-live-terminal:
	./script/test.sh --live-terminal

run:
	./script/build_and_run.sh run

debug:
	./script/build_and_run.sh --debug

logs:
	./script/build_and_run.sh --logs

telemetry:
	./script/build_and_run.sh --telemetry

verify:
	./script/build_and_run.sh --verify

smoke: build
	@set -euo pipefail; bundle="$(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app"; test -x "$$bundle/Contents/MacOS/$(APP_NAME)"; plutil -p "$$bundle/Contents/Info.plist" >/dev/null; echo "smoke: $$bundle"

lint:
	@set -euo pipefail; swift package dump-package >/dev/null; plutil -lint Resources/Info.plist Resources/FixtureInfo.plist Resources/Regions.entitlements; bash -n release.sh script/*.sh tools/*.sh

check: hygiene lint build test smoke

release:
	APP_IDENTITY="$(APP_IDENTITY)" NOTARY_PROFILE="$(NOTARY_PROFILE)" REGIONS_PUBLISH="$(REGIONS_PUBLISH)" ./script/package_release.sh

release-no-publish:
	APP_IDENTITY="$(APP_IDENTITY)" NOTARY_PROFILE="$(NOTARY_PROFILE)" REGIONS_PUBLISH=0 ./script/package_release.sh

clean:
	swift package clean
	rm -rf "$(DERIVED_DATA)" "$(PROJECT)"

tidy:
	find . -type f -iname '*.md' -not -path './.git/*' -not -path './.build/*' -not -path './.derived/*' -delete
	find . -type f -empty -not -path './.git/*' -not -path './.build/*' -not -path './.derived/*' -delete
	find . -depth -type d -empty -not -path './.git/*' -not -path './.build/*' -not -path './.derived/*' -delete
