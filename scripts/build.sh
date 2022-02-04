#!/bin/bash
set -e

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

PLUGIN_NAME="MWAppAuth"

echo "Install ruby dependencies"
bundle

echo "Align project files"
ruby "${SCRIPTPATH}/align_plugin_files.rb"

echo "Run pod install"
pod install --repo-update

echo "Build XCFramework"
"${SCRIPTPATH}/build_framework.sh" "--workspace" "${SCRIPTPATH}/../${PLUGIN_NAME}.xcworkspace" --target "${PLUGIN_NAME}Plugin" --ci

echo "Undoing File structure changes"
git checkout -- "${PLUGIN_NAME}Plugin/${PLUGIN_NAME}Plugin.xcodeproj/project.pbxproj"