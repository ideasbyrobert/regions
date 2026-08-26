PROJECT := Regions.xcodeproj
SCHEME := Regions
ARCHITECTURE := $(shell uname -m)
DERIVED_DATA := .build/XcodeDerivedData
TEAM ?= X87D35HM5V
IDENTITY ?= Apple Development
XCODE_ARGUMENTS := -project $(PROJECT) -scheme $(SCHEME) \
	-configuration Debug -derivedDataPath $(DERIVED_DATA) \
	-destination platform=macOS,arch=$(ARCHITECTURE) \
	CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual \
	CODE_SIGN_IDENTITY="$(IDENTITY)" DEVELOPMENT_TEAM=$(TEAM)

.PHONY: all project style build test xcode-test ui-test check run clean

all: check

project:
	xcodegen generate

style:
	swift script/style.swift

build: project
	xcodebuild $(XCODE_ARGUMENTS) build -quiet

test: style
	swift test

xcode-test: project
	xcodebuild $(XCODE_ARGUMENTS) -only-testing:RegionsTests test -quiet

ui-test: project
	xcodebuild $(XCODE_ARGUMENTS) -only-testing:RegionsUITests test -quiet

check: style test xcode-test build

run:
	script/build_and_run.sh

clean:
	swift package clean
