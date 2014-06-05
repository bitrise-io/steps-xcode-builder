#!/bin/bash

echo "$ cd $CONCRETE_SOURCE_DIR"
cd "$CONCRETE_SOURCE_DIR"

if [[ $CONCRETE_PROJECT_PATH == *".xcodeproj" ]]; then
  export XCODE_PROJECT_ACTION="-project"
elif [[ $CONCRETE_PROJECT_PATH == *".xcworkspace" ]]; then
  export XCODE_PROJECT_ACTION="-workspace"
else
  echo "Failed to get valid project file: $CONCRETE_PROJECT_PATH"
  exit 1
fi

projectdir="$(dirname "$CONCRETE_PROJECT_PATH")"
projectfile="$(basename "$CONCRETE_PROJECT_PATH")"
echo "$ cd $projectdir"
cd "$projectdir"

build_tool="$CONCRETE_BUILD_TOOL"
echo " [i] Specified Build Tool: $build_tool"
if [ -z "$build_tool" ]; then
  build_tool="xcodebuild"
fi
if [ -n "$CONCRETE_ACTION_ARCHIVE" ]; then
  if [[ "$build_tool" != "xcodebuild" ]]; then
    build_tool="xcodebuild"
    echo " [!] Build Tool set to xcodebuild - for Archive action only xcodebuild is supported!"
  fi
fi
echo " [i] Using build tool: $build_tool"

is_build_action_success=0
function finalcleanup {
  echo "-> finalcleanup"
  unset UUID
  rm "$CONCRETE_LIBRARY_DIR/$PROFILE_UUID.mobileprovision"
  $CONCRETE_STEP_DIR/keychain.sh remove

  # Remove downloaded files
  rm $PROVISION_PATH
  rm $CERTIFICATE_PATH

  if [ $is_build_action_success -eq 1 ] ; then
    # success
    if [ -n "$CONCRETE_ACTION_BUILD" ]; then
      echo "export CONCRETE_BUILD_STATUS=succeeded" >> ~/.bash_profile
    elif [ -n "$CONCRETE_ACTION_ANALYZE" ]; then
      echo "export CONCRETE_ANALYZE_STATUS=succeeded" >> ~/.bash_profile
    elif [ -n "$CONCRETE_ACTION_ARCHIVE" ]; then
      echo "export CONCRETE_ARCHIVE_STATUS=succeeded" >> ~/.bash_profile
    elif [ -n "$CONCRETE_ACTION_UNITTEST" ]; then
      echo "export CONCRETE_UNITTEST_STATUS=succeeded" >> ~/.bash_profile
    fi
  else
    # failed
    if [ -n "$CONCRETE_ACTION_BUILD" ]; then
      echo "export CONCRETE_BUILD_STATUS=failed" >> ~/.bash_profile
    elif [ -n "$CONCRETE_ACTION_ANALYZE" ]; then
      echo "export CONCRETE_ANALYZE_STATUS=failed" >> ~/.bash_profile
    elif [ -n "$CONCRETE_ACTION_ARCHIVE" ]; then
      echo "export CONCRETE_ARCHIVE_STATUS=failed" >> ~/.bash_profile
    elif [ -n "$CONCRETE_ACTION_UNITTEST" ]; then
      echo "export CONCRETE_UNITTEST_STATUS=failed" >> ~/.bash_profile
    fi
  fi
}

echo "XCODE_PROJECT_ACTION: $XCODE_PROJECT_ACTION"

# Create directory structure
$CONCRETE_STEP_DIR/create_directory_structure.sh

if [ -n "$CONCRETE_ACTION_ARCHIVE" ]; then
  export ARCHIVE_PATH="$CONCRETE_DEPLOY_DIR/$CONCRETE_SCHEME.xcarchive"
  echo " (i) ARCHIVE_PATH=$ARCHIVE_PATH"
  export EXPORT_PATH="$CONCRETE_DEPLOY_DIR/$CONCRETE_SCHEME"
  echo " (i) EXPORT_PATH=$EXPORT_PATH"
  export DSYM_ZIP_PATH="$CONCRETE_DEPLOY_DIR/$CONCRETE_SCHEME.dSYM.zip"
  echo " (i) DSYM_ZIP_PATH=$DSYM_ZIP_PATH"
fi

if [ -n "$CONCRETE_ACTION_UNITTEST" ]; then
  unittest_simulator_name="iPad"
  if [ -n "$UNITTEST_PLATFORM_NAME" ]; then
    unittest_simulator_name="$UNITTEST_PLATFORM_NAME"
  fi
  unittest_device_destination="platform=iOS Simulator,name=$unittest_simulator_name"
  echo " (i) UnitTest Device Destination: $unittest_device_destination"
fi

# Get provisioning profile
echo "---> Downloading Provision Profile..."
export PROVISION_PATH="$CONCRETE_PROFILE_DIR/profile.mobileprovision"
curl -fso "$PROVISION_PATH" "$CONCRETE_PROVISION_URL"
prov_profile_curl_result=$?
if [ $prov_profile_curl_result -ne 0 ]; then
  echo " (i) First download attempt failed - retry..."
  sleep 5
  curl -fso "$PROVISION_PATH" "$CONCRETE_PROVISION_URL"
  prov_profile_curl_result=$?
fi
echo "PROVISION_PATH: $PROVISION_PATH"
echo " (i) curl download result: $prov_profile_curl_result"
if [[ ! -f "$PROVISION_PATH" ]]; then
  echo " [!] PROVISION_PATH: File not found!"
  finalcleanup
  exit 1
else
  echo " -> PROVISION_PATH: OK"
fi

# Get certificate
echo "---> Downloading Certificate..."
export CERTIFICATE_PATH="$CONCRETE_PROFILE_DIR/Certificate.p12"
curl -fso "$CERTIFICATE_PATH" "$CONCRETE_CERTIFICATE_URL"
cert_curl_result=$?
if [ $cert_curl_result -ne 0 ]; then
  echo " (i) First download attempt failed - retry..."
  sleep 5
  curl -fso "$CERTIFICATE_PATH" "$CONCRETE_CERTIFICATE_URL"
  cert_curl_result=$?
fi
echo "CERTIFICATE_PATH: $CERTIFICATE_PATH"
echo " (i) curl download result: $cert_curl_result"
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
    $XCODE_PROJECT_ACTION "$projectfile" \
    -scheme "$CONCRETE_SCHEME" \
    clean build \
    CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    OTHER_CODE_SIGN_FLAGS="--keychain $CONCRETE_KEYCHAIN"
elif [ -n "$CONCRETE_ACTION_UNITTEST" ]; then
  $build_tool \
    $XCODE_PROJECT_ACTION "$projectfile" \
    -scheme "$CONCRETE_SCHEME" \
    clean test \
    -destination "$unittest_device_destination" \
    CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    OTHER_CODE_SIGN_FLAGS="--keychain $CONCRETE_KEYCHAIN"
elif [ -n "$CONCRETE_ACTION_ANALYZE" ]; then
  $build_tool \
    $XCODE_PROJECT_ACTION "$projectfile" \
    -scheme "$CONCRETE_SCHEME" \
    clean analyze \
    CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    OTHER_CODE_SIGN_FLAGS="--keychain $CONCRETE_KEYCHAIN"
elif [ -n "$CONCRETE_ACTION_ARCHIVE" ]; then
  $build_tool \
    $XCODE_PROJECT_ACTION "$projectfile" \
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

if [[ -n "$CONCRETE_ACTION_BUILD" && "$XCODEBUILD_STATUS" == "succeeded" ]]; then
  is_build_action_success=1
elif [[ -n "$CONCRETE_ACTION_ANALYZE" && "$XCODEBUILD_STATUS" == "succeeded" ]]; then
  is_build_action_success=1
elif [[ -n "$CONCRETE_ACTION_UNITTEST" && "$XCODEBUILD_STATUS" == "succeeded" ]]; then
  is_build_action_success=1
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
    
    xcodebuild \
      -exportArchive \
      -exportFormat ipa \
      -archivePath "$ARCHIVE_PATH" \
      -exportPath "$EXPORT_PATH" \
      -exportWithOriginalSigningIdentity

    if [[ $? != 0 ]]; then
      ecode=$?
      finalcleanup
      exit $ecode
    else
      echo " (i) Archive build success"
    fi
    echo "export CONCRETE_IPA_PATH='$EXPORT_PATH.ipa'" >> ~/.bash_profile

    # get the .app.dSYM folders from the dSYMs archive folder
    archive_dsyms_folder="${ARCHIVE_PATH}/dSYMs"
    echo "$ ls $archive_dsyms_folder"
    ls "$archive_dsyms_folder"
    app_dsym_count=0
    app_dsym_path=""

    IFS=$'\n'
    for a_app_dsym in $(find "$archive_dsyms_folder" -type d -name "*.app.dSYM"); do 
      echo " (i) .app.dSYM found: $a_app_dsym"
      app_dsym_count=$[app_dsym_count + 1]
      app_dsym_path="$a_app_dsym"
      echo " (i) app_dsym_count: $app_dsym_count"
    done
    unset IFS

    echo " (i) Found dSYM count: $app_dsym_count"
    if [ $app_dsym_count -eq 1 ]; then
      echo " (i) dSYM found - OK -> $app_dsym_path"
    else
      echo " [!] More than one or no dSYM found!"
      finalcleanup
      exit 1
    fi

    # Generate dSym zip
    export DSYM_PATH="$app_dsym_path"
    if [ -d "$DSYM_PATH" ]; then
      echo "Generating zip for dSym"

      /usr/bin/zip -rTy \
        "$DSYM_ZIP_PATH" \
        "$DSYM_PATH"

      if [[ $? != 0 ]]; then
        ecode=$?
        finalcleanup
        exit $ecode
      fi
      echo "export CONCRETE_DSYM_PATH='$DSYM_ZIP_PATH'" >> ~/.bash_profile
      is_build_action_success=1
    else
      echo " [!] Error: No dSYM file found in ${DSYM_PATH}"
      finalcleanup
      exit 1
    fi
  fi
fi

finalcleanup
