#!/usr/bin/env bash

set -e

xcodebuild \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=Absolute \
  -IDECustomBuildProductsPath="$PWD" \
  -scheme Sample \
  -configuration Debug \
  -destination 'name=iPhone 5' \
  build-for-testing

mv Debug-iphonesimulator/* .
rmdir Debug-iphonesimulator

rm -r *.app/Frameworks
rm -r *.app/_CodeSignature
rm -r *.app/PlugIns/*.xctest/_CodeSignature

sed -i.bak 's!/Debug-iphonesimulator!!g' *.xctestrun
rm *.bak

cp -r *.app ../../../XCTestBootstrapTests/Fixtures/
cp -r *.app ../../../FBSimulatorControlTests/Fixtures/
cp *.xctestrun ../../../XCTestBootstrapTests/Fixtures/
cp *.xctestrun ../../../FBSimulatorControlTests/Fixtures/
rm -r *.app
rm *.xctestrun
