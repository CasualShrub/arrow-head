#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
xcrun clang -dynamiclib -fobjc-arc -O2 -Wall -Wextra -Werror -arch arm64 -arch x86_64 \
  -mmacosx-version-min=12.3 -framework Foundation -framework IOKit \
  bridge.m -o build/libdualsense.dylib
codesign --force --sign - build/libdualsense.dylib
