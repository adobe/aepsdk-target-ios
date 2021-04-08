#!/usr/bin/env bash

#Copyright 2021 Adobe. All rights reserved.
#This file is licensed to you under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License. You may obtain a copy
#of the License at http://www.apache.org/licenses/LICENSE-2.0

#Unless required by applicable law or agreed to in writing, software distributed under
#the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
#OF ANY KIND, either express or implied. See the License for the specific language
#governing permissions and limitations under the License.

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
