#!/bin/bash

echo "$ cd $CONCRETE_SOURCE_DIR"
cd $CONCRETE_SOURCE_DIR

build_tool="$CONCRETE_BUILD_TOOL"
echo " [i] Specified Build Tool: $build_tool"
if [ -z "$build_tool" ]; then
  build_tool="xcodebuild"
fi
echo " [i] Using build tool: $build_tool"

if [[ $CONCRETE_PROJECT_PATH == *".xcodeproj" ]]; then
  export XCODE_PROJECT_ACTION="-project"
elif [[ $CONCRETE_PROJECT_PATH == *".xcworkspace" ]]; then
  export XCODE_PROJECT_ACTION="-workspace"
else
  echo "Failed to get valid project file: $CONCRETE_PROJECT_PATH"
  exit 1
fi

function finalcleanup {
  echo "-> finalcleanup"
  unset UUID
  rm "$CONCRETE_LIBRARY_DIR/$PROFILE_UUID.mobileprovision"
  $CONCRETE_STEP_DIR/keychain.sh remove

  # Remove downloaded files
  rm $PROVISION_PATH
  rm $CERTIFICATE_PATH
}

echo "XCODE_PROJECT_ACTION: $XCODE_PROJECT_ACTION"

# Create directory structure
$CONCRETE_STEP_DIR/create_directory_structure.sh

if [ -n "$CONCRETE_ACTION_ARCHIVE" ]; then
  export ARCHIVE_PATH="$CONCRETE_DEPLOY_DIR/$CONCRETE_SCHEME.xcarchive"
  export EXPORT_PATH="$CONCRETE_DEPLOY_DIR/$CONCRETE_SCHEME"
  export DSYM_ZIP_PATH="$CONCRETE_DEPLOY_DIR/$CONCRETE_SCHEME.dSYM.zip"
fi

# Get provisioning profile
export PROVISION_PATH="$CONCRETE_PROFILE_DIR/profile.mobileprovision"
curl -fso "$PROVISION_PATH" "$CONCRETE_PROVISION_URL"
echo "PROVISION_PATH: $PROVISION_PATH"
if [[ ! -f "$PROVISION_PATH" ]]; then
  echo " [!] PROVISION_PATH: File not found!"
  finalcleanup
  exit 1
else
  echo " -> PROVISION_PATH: OK"
fi

# Get certificate
export CERTIFICATE_PATH="$CONCRETE_PROFILE_DIR/Certificate.p12"
curl -fso "$CERTIFICATE_PATH" "$CONCRETE_CERTIFICATE_URL"
echo "CERTIFICATE_PATH: $CERTIFICATE_PATH"
if [[ ! -f "$CERTIFICATE_PATH" ]]; then
  echo " [!] CERTIFICATE_PATH: File not found!"
  finalcleanup
  exit 1
else
  echo " -> CERTIFICATE_PATH: OK"
fi

echo "$ keychain.sh add"
$CONCRETE_STEP_DIR/keychain.sh add

# Get UUID & install provision profile
uuid_key=$(grep -aA1 UUID "$PROVISION_PATH")
export PROFILE_UUID=$([[ $uuid_key =~ ([-A-Z0-9]{36}) ]] && echo ${BASH_REMATCH[1]})
cp "$PROVISION_PATH" "$CONCRETE_LIBRARY_DIR/$PROFILE_UUID.mobileprovision"
if [[ ! -f "$CONCRETE_LIBRARY_DIR/$PROFILE_UUID.mobileprovision" ]]; then
  echo " [!] Mobileprovision file: File not found - probably copy failed!"
  finalcleanup
  exit 1
fi
echo "PROFILE_UUID: $PROFILE_UUID"

# Get identities from certificate
export CERTIFICATE_IDENTITY=$(security find-certificate -a $CONCRETE_KEYCHAIN | grep -Ei '"labl"<blob>=".*"' | grep -oEi '=".*"' | grep -oEi '[^="]+' | head -n 1)
echo "CERTIFICATE_IDENTITY: $CERTIFICATE_IDENTITY"

# Start the build
if [ -n "$CONCRETE_ACTION_BUILD" ]; then
  $build_tool \
    $XCODE_PROJECT_ACTION "$CONCRETE_PROJECT_PATH" \
    -scheme "$CONCRETE_SCHEME" \
    clean build \
    CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    OTHER_CODE_SIGN_FLAGS="--keychain $CONCRETE_KEYCHAIN"
elif [ -n "$CONCRETE_ACTION_ANALYZE" ]; then
  $build_tool \
    $XCODE_PROJECT_ACTION "$CONCRETE_PROJECT_PATH" \
    -scheme "$CONCRETE_SCHEME" \
    clean analyze \
    CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    OTHER_CODE_SIGN_FLAGS="--keychain $CONCRETE_KEYCHAIN"
elif [ -n "$CONCRETE_ACTION_ARCHIVE" ]; then
  $build_tool \
    $XCODE_PROJECT_ACTION "$CONCRETE_PROJECT_PATH" \
    -scheme "$CONCRETE_SCHEME" \
    clean archive -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    OTHER_CODE_SIGN_FLAGS="--keychain $CONCRETE_KEYCHAIN"
fi

if [ $? -eq 0 ]; then
  export XCODEBUILD_STATUS="succeeded"
else
  export XCODEBUILD_STATUS="failed"
fi
echo "XCODEBUILD_STATUS: $XCODEBUILD_STATUS"
export CONCRETE_BUILD_STATUS=$XCODEBUILD_STATUS
if [ -n "$CONCRETE_ACTION_BUILD" ]; then
  echo "export CONCRETE_BUILD_STATUS=$XCODEBUILD_STATUS" >> ~/.bash_profile
elif [ -n "$CONCRETE_ACTION_ANALYZE" ]; then
  export CONCRETE_ANALYZE_STATUS=$XCODEBUILD_STATUS
  echo "export CONCRETE_ANALYZE_STATUS=$XCODEBUILD_STATUS" >> ~/.bash_profile
fi

if [ "$XCODEBUILD_STATUS" != "succeeded" ]; then
  finalcleanup
  exit 1
fi

# Export ipa if everyting succeeded
if [ -n "$CONCRETE_ACTION_ARCHIVE" ]; then
  if [[ "$XCODEBUILD_STATUS" == "succeeded" ]]; then
    # Export ipa
    echo "Generating signed IPA"
    
    $build_tool \
      -exportArchive \
      -exportFormat ipa \
      -archivePath "$ARCHIVE_PATH" \
      -exportPath "$EXPORT_PATH" \
      -exportWithOriginalSigningIdentity

    if [[ $? != 0 ]]; then
      export CONCRETE_ARCHIVE_STATUS="failed"
      echo "export CONCRETE_ARCHIVE_STATUS=failed" >> ~/.bash_profile
      finalcleanup
      exit $?
    else
      export CONCRETE_ARCHIVE_STATUS="succeeded"
      echo "export CONCRETE_ARCHIVE_STATUS=succeeded" >> ~/.bash_profile
    fi
    echo "export CONCRETE_IPA_PATH='$EXPORT_PATH.ipa'" >> ~/.bash_profile

    # Generate dSym zip
    export DSYM_PATH="${ARCHIVE_PATH}/dSYMs/${CONCRETE_SCHEME}.app.dSYM"
    if [ -d "$DSYM_PATH" ]; then
      echo "Generating zip for dSym"

      /usr/bin/zip -rTy \
        "$DSYM_ZIP_PATH" \
        "$DSYM_PATH"

      if [[ $? != 0 ]]; then
        finalcleanup
        exit $?
      fi
      echo "export CONCRETE_DSYM_PATH='$DSYM_ZIP_PATH'" >> ~/.bash_profile
    else
      echo "No dSYM file found in ${ARCHIVE_PATH}"
    fi
  else
    export CONCRETE_ARCHIVE_STATUS="failed"
    echo "export CONCRETE_ARCHIVE_STATUS=failed" >> ~/.bash_profile
  fi
fi

finalcleanup
