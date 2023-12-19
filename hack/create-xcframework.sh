#!/bin/bash

function create_xcframework() {
  # ios
  xcodebuild archive -project Bucketeer.xcodeproj -scheme Bucketeer -archivePath FrameworkBuild/iphoneos.xcarchive -destination 'generic/platform=iOS' SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES
  # ios for simulator
  xcodebuild archive -project Bucketeer.xcodeproj -scheme Bucketeer -archivePath FrameworkBuild/iphoneosSimulator.xcarchive -destination 'generic/platform=iOS Simulator' SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES
  # tvos
  xcodebuild archive -project Bucketeer.xcodeproj -scheme Bucketeer -archivePath FrameworkBuild/tvos.xcarchive -destination 'generic/platform=tvOS' SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES
  # tvos for simulator
  xcodebuild archive -project Bucketeer.xcodeproj -scheme Bucketeer -archivePath FrameworkBuild/tvosSimulator.xcarchive -destination 'generic/platform=tvOS Simulator' SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES

  xcodebuild -create-xcframework -framework FrameworkBuild/iphoneos.xcarchive/Products/Library/Frameworks/Bucketeer.framework -framework FrameworkBuild/iphoneosSimulator.xcarchive/Products/Library/Frameworks/Bucketeer.framework -framework FrameworkBuild/tvos.xcarchive/Products/Library/Frameworks/Bucketeer.framework -framework FrameworkBuild/tvosSimulator.xcarchive/Products/Library/Frameworks/Bucketeer.framework -output FrameworkBuild/Bucketeer.xcframework
}

if [ ${#@} -eq 1 ]; then
  create_xcframework
  if [ "${@#"-z"}" = "" ] || [ "${@#"--zip"}" = "" ]; then
    zip FrameworkBuild/Bucketeer.xcframework.zip FrameworkBuild/Bucketeer.xcframework
  fi
fi
