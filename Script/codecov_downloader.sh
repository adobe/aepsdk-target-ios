#!/bin/bash
#
# Copyright 2021 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.

curl -s https://codecov.io/bash >codecov
VERSION=$(grep 'VERSION=\"[0-9\.]*\"' codecov | cut -d'"' -f2);
for i in 1 256 512; do
  shasum -a $i -c --ignore-missing <(curl -s "https://raw.githubusercontent.com/codecov/codecov-bash/${VERSION}/SHA${i}SUM") ||
    shasum -a $i -c <(curl -s "https://raw.githubusercontent.com/codecov/codecov-bash/${VERSION}/SHA${i}SUM" | grep -w "codecov")
done
