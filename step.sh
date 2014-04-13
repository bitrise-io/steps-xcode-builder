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
if [ ! -d "dirname ${CONCRETE_PROVISION_PATH}" ]; then mkdir -p $(dirname ${CONCRETE_PROVISION_PATH}); fi
curl -so $CONCRETE_PROVISION_PATH $CONCRETE_PROVISION_URL
# Get certificate
if [ ! -d "dirname ${CONCRETE_CERTIFICATE_PATH}" ]; then mkdir -p $(dirname ${CONCRETE_CERTIFICATE_PATH}); fi
curl -so $CONCRETE_CERTIFICATE_PATH $CONCRETE_CERTIFICATE_URL

$CONCRETE_STEP_DIR/keychain.sh add

# Get UUID & install provision profile
uuid_key=$(grep -aA1 UUID $CONCRETE_PROVISION_PATH)
export PROFILE_UUID=$([[ $uuid_key =~ ([-A-Z0-9]{36}) ]] && echo ${BASH_REMATCH[1]})
if [ ! -d "$CONCRETE_LIBRARY_PATH" ]; then mkdir -p "$CONCRETE_LIBRARY_PATH"; fi
cp $CONCRETE_PROVISION_PATH "$CONCRETE_LIBRARY_PATH/$PROFILE_UUID.mobileprovision"

# Get identities
$CONCRETE_STEP_DIR/keychain.sh get-identity

# Start the build
xcodebuild \
  $CONCRETE_PROJECT_ACTION \
  -scheme $CONCRETE_SCHEME \
  $CONCRETE_BUILD_ACTION \
  OBJROOT=$CONCRETE_OBJ_ROOT \
  SYMROOT=$CONCRETE_SYM_ROOT \
  CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
  PROVISIONING_PROFILE="$PROFILE_UUID" \
  OTHER_CODE_SIGN_FLAGS="--keychain $CONCRETE_KEYCHAIN_PATH"

unset UUID
rm "$CONCRETE_LIBRARY_PATH/$PROFILE_UUID.mobileprovision"
$CONCRETE_STEP_DIR/keychain.sh remove


# Remove downloaded files
rm $CONCRETE_PROVISION_PATH
rm $CONCRETE_CERTIFICATE_PATH