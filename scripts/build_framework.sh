#!/bin/bash
set -e

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
BUILD_DIR="$(pwd)/tmp"
DESTINATION_DIR="$(pwd)/Build"
CONFIGURATION="Release"
WORKSPACE=""
TARGET=""
IS_CI="false"

# This function does the common code
# $1 is the scheme to build:
# Example: build MobileWorkflowCore Release
function archive() {
    SCHEME="$1"
    BUILD_CONFIGURATION="$2"

    xcodebuild -workspace "${WORKSPACE}" \
               -scheme "${SCHEME}" \
               -configuration ${BUILD_CONFIGURATION} \
               -sdk iphoneos \
               -archivePath "${BUILD_DIR}/device/${SCHEME}" \
               archive \
               SKIP_INSTALL=NO \
               BUILD_LIBRARY_FOR_DISTRIBUTION=YES && \
    xcodebuild -workspace "${WORKSPACE}" \
               -scheme "${SCHEME}" \
               -sdk iphonesimulator \
               -configuration ${BUILD_CONFIGURATION} \
               -archivePath "${BUILD_DIR}/simulator/${SCHEME}" \
               archive \
               SKIP_INSTALL=NO \
               BUILD_LIBRARY_FOR_DISTRIBUTION=YES
}

function compose() {
  ARCHIVE_NAME="$1"
  FRAMEWORK_NAME="$2"
  FRAMEWORK_PATH="$DESTINATION_DIR/$FRAMEWORK_NAME.xcframework"
  DEVICE_FRAMEWORK="$BUILD_DIR/device/$ARCHIVE_NAME.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"
  SIMULATOR_FRAMEWORK="$BUILD_DIR/simulator/$ARCHIVE_NAME.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"

  xcodebuild -create-xcframework \
  -framework $DEVICE_FRAMEWORK \
  -framework $SIMULATOR_FRAMEWORK \
  -output $FRAMEWORK_PATH
}

while [ -n "$1" ]; do
    case "$1" in
        --ci) IS_CI="true";;
        --workspace) WORKSPACE="$2" && shift;;
        --target) TARGET="$2" && shift;;
    esac
    shift
done

rm -rf $DESTINATION_DIR
mkdir $DESTINATION_DIR

rm -rf "$BUILD_DIR"
mkdir "$BUILD_DIR"

archive $TARGET $CONFIGURATION

compose $TARGET $TARGET

if [[ "${IS_CI}" = "false" ]]; then
  open $DESTINATION_DIR
fi
