#!/bin/bash
curl -s https://codecov.io/bash >codecov
VERSION=$(grep 'VERSION=\".*\"' codecov | cut -d'"' -f2)
for i in 1 256 512; do
  shasum -a $i -c --ignore-missing <(curl -s https://raw.githubusercontent.com/codecov/codecov-bash/${VERSION}/SHA${i}SUM)
done
