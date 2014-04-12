#!/bin/bash

echo "$ cd $CONCRETE_SOURCE_DIR"
cd $CONCRETE_SOURCE_DIR

if [[ $CONCETE_PROJECT_FILE == *".xcodeproj" ]]; then
  CONCRETE_PROJECT_ACTION = "-project $CONCRETE_PROJECT"
elif [[ $CONCETE_PROJECT_FILE == *".xcworkspace" ]]; then
  CONCRETE_PROJECT_ACTION = "-workspace $CONCRETE_PROJECT"
else
  echo "Failed to get valid project file: $CONCETE_PROJECT_FILE"
  exit 1
fi

if [[ -v CONCRETE_ACTION_BUILD ]]; then
  xcodebuild $CONCRETE_PROJECT_ACTION -scheme $CONCRETE_SCHEME
fi