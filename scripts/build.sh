#!/bin/bash
set -e

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

PODSPEC_FILE="$(ls "${SCRIPTPATH}/.." | grep ".*\.podspec")"
TARGET_NAME="$(echo "${PODSPEC_FILE}" | cut -f 1 -d '.')"
PLUGIN_NAME="$(echo "${TARGET_NAME}" | sed -e "s/Plugin$//")"

echo "Install ruby dependencies"
bundle

echo "Align project files"
ruby "${SCRIPTPATH}/align_plugin_files.rb" "${TARGET_NAME}"

echo "Run pod install"
pod install --repo-update

echo "Build XCFramework"
"${SCRIPTPATH}/build_framework.sh" "--workspace" "${SCRIPTPATH}/../${PLUGIN_NAME}.xcworkspace" --target "${TARGET_NAME}" --ci

echo "Undoing File structure changes"
git checkout -- "${TARGET_NAME}/${TARGET_NAME}.xcodeproj/project.pbxproj"