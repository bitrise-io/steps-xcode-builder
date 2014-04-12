#!/bin/bash

echo "$ cd $CONCRETE_SOURCE_DIR"
cd $CONCRETE_SOURCE_DIR

if [[ $CONCRETE_PROJECT_PATH == *".xcodeproj" ]]; then
  export CONCRETE_PROJECT_ACTION="-project $CONCRETE_PROJECT_PATH"
elif [[ $CONCRETE_PROJECT_PATH == *".xcworkspace" ]]; then
  export CONCRETE_PROJECT_ACTION="-workspace $CONCRETE_PROJECT_PATH"
else
  echo "Failed to get valid project file: $CONCRETE_PROJECT_PATH"
  exit 1
fi

if [ -n "$CONCRETE_ACTION_BUILD" ]; then
  export CONCRETE_BUILD_ACTION="clean build"
fi

if [ -n "$CONCRETE_ACTION_ANALYZE" ]; then
  export CONCRETE_BUILD_ACTION="clean analyze"
fi

# if [ -n "$CONCRETE_ACTION_TEST" ]; then
#   export CONCRETE_BUILD_ACTION="clean test"
# fi

if [ -n "$CONCRETE_ACTION_ARCHIVE" ]; then
  export CONCRETE_BUILD_ACTION="clean archive"
fi

# Get provisioning profile
curl -o $CONCRETE_PROVISION_PATH $CONCRETE_PROVISION_URL
# Get certificate
curl -o $CONCRETE_CERTIFICATE_PATH $CONCRETE_CERTIFICATE_URL

# Start the build
xcodebuild \
  $CONCRETE_PROJECT_ACTION \
  -scheme $CONCRETE_SCHEME \
  $CONCRETE_BUILD_ACTION \
  OBJROOT=$CONCRETE_OBJ_ROOT \
  SYMROOT=$CONCRETE_SYM_ROOT \
  CODE_SIGN_IDENTITY="" \
  PROVISIONING_PROFILE="" \
  OTHER_CODE_SIGN_FLAGS="--keychain $CONCRETE_KEYCHAIN_PATH"