#!/usr/bin/env bash

set -e

if which jq >/dev/null; then
    echo "jq is installed"
else
    echo "error: jq not installed.(brew install jq)"
fi

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

echo "Start to check the version in podspec file >"
echo "Expected to release:"
echo "  - AEPTarget: ${BLUE}$1${NC}"

PODSPEC_VERSION=$(pod ipc spec AEPTarget.podspec | jq '.version' | tr -d '"')
echo "Local podspec:"
echo " - version: ${BLUE}${PODSPEC_VERSION}${NC}"

SOUCE_CODE_VERSION=$(cat ./AEPTarget/Sources/TargetConstants.swift | egrep '\s*EXTENSION_VERSION\s*=\s*\"(.*)\"' | ruby -e "puts gets.scan(/\"(.*)\"/)[0] " | tr -d '"')
echo "Souce code version - ${BLUE}${SOUCE_CODE_VERSION}${NC}"

if [[ "$1" == "$PODSPEC_VERSION" ]] && [[ "$1" == "$SOUCE_CODE_VERSION" ]]; then
    echo "${GREEN}Pass!"
    exit 0
else
    echo "${RED}[Error]${NC} Version do not match!"
    exit -1
fi
