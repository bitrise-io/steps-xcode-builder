#!/bin/bash

echo "$ cd $CONCRETE_SOURCE_DIR"
cd $CONCRETE_SOURCE_DIR

if [[ $CONCRETE_PROJECT_PATH == *".xcodeproj" ]]; then
  CONCRETE_PROJECT_ACTION = "-project $CONCRETE_PROJECT_PATH"
elif [[ $CONCRETE_PROJECT_PATH == *".xcworkspace" ]]; then
  CONCRETE_PROJECT_ACTION = "-workspace $CONCRETE_PROJECT_PATH"
else
  echo "Failed to get valid project file: $CONCRETE_PROJECT_PATH"
  exit 1
fi

if [ -n "$CONCRETE_ACTION_BUILD" ]; then
  xcodebuild $CONCRETE_PROJECT_ACTION -scheme $CONCRETE_SCHEME
fi