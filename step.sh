#!/bin/bash

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# load bash utils
source "${THIS_SCRIPT_DIR}/bash_utils/utils.sh"
source "${THIS_SCRIPT_DIR}/bash_utils/formatted_output.sh"

# init / cleanup the formatted output
echo "" > "${formatted_output_file_path}"


# ------------------------------
# --- Utils - CleanUp

is_build_action_success=0
function finalcleanup {
  echo "-> finalcleanup"
  fail_msg="$1"

  # unset UUID
  # rm "${CONFIG_provisioning_profiles_dir}/${PROFILE_UUID}.mobileprovision"
  bash "${THIS_SCRIPT_DIR}/keychain.sh" remove

  # # Remove downloaded files
  # rm ${PROVISION_PATH}
  # rm ${CERTIFICATE_PATH}

  if [ ${is_build_action_success} -eq 1 ] ; then
    # success
    write_section_to_formatted_output "# Success"

    if [[ "${XCODE_BUILDER_ACTION}" == "build" ]] ; then
      echo "export BITRISE_BUILD_STATUS=succeeded" >> ~/.bash_profile
    elif [[ "${XCODE_BUILDER_ACTION}" == "analyze" ]] ; then
      echo "export BITRISE_ANALYZE_STATUS=succeeded" >> ~/.bash_profile
    elif [[ "${XCODE_BUILDER_ACTION}" == "archive" ]] ; then
      echo "export BITRISE_ARCHIVE_STATUS=succeeded" >> ~/.bash_profile
    elif [[ "${XCODE_BUILDER_ACTION}" == "unittest" ]] ; then
      echo "export BITRISE_UNITTEST_STATUS=succeeded" >> ~/.bash_profile
    fi
  else
    # failed
    write_section_to_formatted_output "# Error"
    if [ ! -z "${fail_msg}" ] ; then
      write_section_to_formatted_output "**Error Description**:"
      write_section_to_formatted_output "${fail_msg}"
    fi
    write_section_to_formatted_output "*See the logs for more information*"

    if [[ "${XCODE_BUILDER_ACTION}" == "build" ]] ; then
      echo "export BITRISE_BUILD_STATUS=failed" >> ~/.bash_profile
    elif [[ "${XCODE_BUILDER_ACTION}" == "analyze" ]] ; then
      echo "export BITRISE_ANALYZE_STATUS=failed" >> ~/.bash_profile
    elif [[ "${XCODE_BUILDER_ACTION}" == "archive" ]] ; then
      echo "export BITRISE_ARCHIVE_STATUS=failed" >> ~/.bash_profile
    elif [[ "${XCODE_BUILDER_ACTION}" == "unittest" ]] ; then
      echo "export BITRISE_UNITTEST_STATUS=failed" >> ~/.bash_profile
    fi
  fi
}

function CLEANUP_ON_ERROR_FN {
  finalcleanup
}
set_error_cleanup_function CLEANUP_ON_ERROR_FN


# ------------------------------
# --- Configs

CONFIG_provisioning_profiles_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
CONFIG_tmp_profile_dir="$HOME/tmp_profiles"


# ------------------------------
# --- Inputs

write_section_to_formatted_output "# Configuration"

# Xcode Action - for backward compatibility
if [ -n "$BITRISE_ACTION_BUILD" ]; then
  XCODE_BUILDER_ACTION="build"
elif [ -n "$BITRISE_ACTION_ANALYZE" ]; then
  XCODE_BUILDER_ACTION="analyze"
elif [ -n "$BITRISE_ACTION_ARCHIVE" ]; then
  XCODE_BUILDER_ACTION="archive"
elif [ -n "$BITRISE_ACTION_UNITTEST" ]; then
  XCODE_BUILDER_ACTION="unittest"
fi
echo_string_to_formatted_output "* Action: ${XCODE_BUILDER_ACTION}"

# Project-or-Workspace
if [[ "${XCODE_BUILDER_PROJECT_PATH}" == *".xcodeproj" ]]; then
  export CONFIG_xcode_project_action="-project"
elif [[ "${XCODE_BUILDER_PROJECT_PATH}" == *".xcworkspace" ]]; then
  export CONFIG_xcode_project_action="-workspace"
else
  finalcleanup "Failed to get valid project file (invalid project file): ${XCODE_BUILDER_PROJECT_PATH}"
  exit 1
fi
echo "CONFIG_xcode_project_action: ${CONFIG_xcode_project_action}"

# Build Tool
CONFIG_build_tool="${XCODE_BUILDER_BUILD_TOOL}"
echo " [i] Specified Build Tool: ${CONFIG_build_tool}"
if [ -z "${CONFIG_build_tool}" ]; then
  CONFIG_build_tool="xcodebuild"
fi
if [[ "${XCODE_BUILDER_ACTION}" == "archive" || "${XCODE_BUILDER_ACTION}" == "unittest" ]] ; then
  if [[ "${CONFIG_build_tool}" != "xcodebuild" ]]; then
    CONFIG_build_tool="xcodebuild"
    echo " [!] Build Tool set to xcodebuild - for Archive and UnitTest actions only xcodebuild is supported!"
  fi
fi
echo_string_to_formatted_output "* Build Tool: ${CONFIG_build_tool}"

# Required inputs testing
if [ -z "${XCODE_BUILDER_SCHEME}" ] ; then
  finalcleanup "Missing required input: No Scheme defined."
  exit 1
else
  echo_string_to_formatted_output "* Scheme: ${XCODE_BUILDER_SCHEME}"
fi

if [ -z "${XCODE_BUILDER_PROJECT_ROOT_DIR_PATH}" ] ; then
  finalcleanup "Missing required input: No Project-Root-Dir-Path defined."
  exit 1
else
  echo_string_to_formatted_output "* Project Root Dir Path: ${XCODE_BUILDER_PROJECT_ROOT_DIR_PATH}"
fi

if [ -z "${XCODE_BUILDER_PROJECT_PATH}" ] ; then
  finalcleanup "Missing required input: No Project-File-Path defined."
  exit 1
else
  echo_string_to_formatted_output "* Project File Path (relative to Project Root Dir): ${XCODE_BUILDER_PROJECT_PATH}"
fi

if [ -z "${XCODE_BUILDER_CERTIFICATE_URL}" ] ; then
  finalcleanup "Missing required input: No Certificate-URL defined."
  exit 1
fi

if [ -z "${XCODE_BUILDER_CERTIFICATES_DIR}" ] ; then
  finalcleanup "Missing required input: No Certificate-Directory-Path defined."
  exit 1
else
  echo_string_to_formatted_output "* Certificated Dir Path: ${XCODE_BUILDER_CERTIFICATES_DIR}"
fi

if [[ "${XCODE_BUILDER_ACTION}" == "archive" ]] ; then
  if [ -z "${XCODE_BUILDER_DEPLOY_DIR}" ] ; then
    finalcleanup "Missing required input: No Deploy-Directory-Path defined."
    exit 1
  else
    echo_string_to_formatted_output "* Deploy Dir Path: ${XCODE_BUILDER_DEPLOY_DIR}"
  fi
fi


#
# Xcode Version Selection
if [ -n "${XCODE_BUILDER_USE_XCODE_VERSION}" ]; then
  use_xcode_version="${XCODE_BUILDER_USE_XCODE_VERSION}"
fi
if [ -z "${use_xcode_version}" ] ; then
  echo_string_to_formatted_output "* No Xcode Version specified - will use the default."
else
  echo_string_to_formatted_output "* Specified Xcode Version to use: ${use_xcode_version}"
  bash "${THIS_SCRIPT_DIR}/bitrise_utils/select_xcode_version.sh" "${use_xcode_version}"
  if [ $? -ne 0 ] ; then
    finalcleanup "Failed to select the specified Xcode version!"
    exit 1
  fi
fi
echo " (i) Using Xcode version:"
xcodebuild -version



# ------------------------------
# --- Main

# --- Create directory structure
mkdir -p "${CONFIG_provisioning_profiles_dir}"
mkdir -p "${CONFIG_tmp_profile_dir}"
mkdir -p "${XCODE_BUILDER_CERTIFICATES_DIR}"
mkdir -p "${XCODE_BUILDER_DEPLOY_DIR}"

# --- Switch to project's dir
echo "$ cd ${XCODE_BUILDER_PROJECT_ROOT_DIR_PATH}"
cd "${XCODE_BUILDER_PROJECT_ROOT_DIR_PATH}"
if [ $? -ne 0 ] ; then
  finalcleanup "Failed to switch directory to the Project Root Directory"
  exit 1
fi

projectdir="$(dirname "${XCODE_BUILDER_PROJECT_PATH}")"
projectfile="$(basename "${XCODE_BUILDER_PROJECT_PATH}")"
echo "$ cd ${projectdir}"
cd "${projectdir}"
if [ $? -ne 0 ] ; then
  finalcleanup "Failed to switch to the Project-File's Directory"
  exit 1
fi




if [[ "${XCODE_BUILDER_ACTION}" == "archive" ]] ; then
  export ARCHIVE_PATH="${XCODE_BUILDER_DEPLOY_DIR}/${XCODE_BUILDER_SCHEME}.xcarchive"
  echo " (i) ARCHIVE_PATH=$ARCHIVE_PATH"
  export EXPORT_PATH="${XCODE_BUILDER_DEPLOY_DIR}/${XCODE_BUILDER_SCHEME}"
  echo " (i) EXPORT_PATH=$EXPORT_PATH"
  export DSYM_ZIP_PATH="${XCODE_BUILDER_DEPLOY_DIR}/${XCODE_BUILDER_SCHEME}.dSYM.zip"
  echo " (i) DSYM_ZIP_PATH=$DSYM_ZIP_PATH"
fi

if [[ "${XCODE_BUILDER_ACTION}" == "unittest" ]] ; then
  CONFIG_unittest_simulator_name="iPad"
  if [ -n "$XCODE_BUILDER_UNITTEST_PLATFORM_NAME" ]; then
    CONFIG_unittest_simulator_name="$XCODE_BUILDER_UNITTEST_PLATFORM_NAME"
  fi
  CONFIG_unittest_device_destination="platform=iOS Simulator,name=${CONFIG_unittest_simulator_name}"
  echo " (i) UnitTest Device Destination: ${CONFIG_unittest_device_destination}"
fi

# Get provisioning profile
echo "---> Downloading Provision Profile..."
export PROVISION_PATH="${CONFIG_tmp_profile_dir}/profile.mobileprovision"
curl -fso "${PROVISION_PATH}" "${XCODE_BUILDER_PROVISION_URL}"
prov_profile_curl_result=$?
if [ ${prov_profile_curl_result} -ne 0 ]; then
  echo " (i) First download attempt failed - retry..."
  sleep 5
  curl -fso "${PROVISION_PATH}" "${XCODE_BUILDER_PROVISION_URL}"
  prov_profile_curl_result=$?
fi
echo "PROVISION_PATH: ${PROVISION_PATH}"
echo " (i) curl download result: ${prov_profile_curl_result}"
if [[ ! -f "${PROVISION_PATH}" ]] ; then
  finalcleanup "PROVISION_PATH: File not found - failed to download"
  exit 1
else
  echo " -> PROVISION_PATH: OK"
fi

# Get certificate
echo "---> Downloading Certificate..."
export CERTIFICATE_PATH="${XCODE_BUILDER_CERTIFICATES_DIR}/Certificate.p12"
curl -fso "$CERTIFICATE_PATH" "${XCODE_BUILDER_CERTIFICATE_URL}"
cert_curl_result=$?
if [ ${cert_curl_result} -ne 0 ]; then
  echo " (i) First download attempt failed - retry..."
  sleep 5
  curl -fso "$CERTIFICATE_PATH" "${XCODE_BUILDER_CERTIFICATE_URL}"
  cert_curl_result=$?
fi
echo "CERTIFICATE_PATH: $CERTIFICATE_PATH"
echo " (i) curl download result: ${cert_curl_result}"
if [[ ! -f "$CERTIFICATE_PATH" ]]; then
  finalcleanup "CERTIFICATE_PATH: File not found - failed to download"
  exit 1
else
  echo " -> CERTIFICATE_PATH: OK"
fi

# LC_ALL: required for tr, for more info: http://unix.stackexchange.com/questions/45404/why-cant-tr-read-from-dev-urandom-on-osx
keychain_pass="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
export KEYCHAIN_PASSPHRASE="${keychain_pass}"
echo "$ keychain.sh add"
bash "${THIS_SCRIPT_DIR}/keychain.sh" add

# Get UUID & install provision profile
export PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print UUID" /dev/stdin <<< $(/usr/bin/security cms -D -i "$PROVISION_PATH"))
provisioning_profile_file_path="$CONFIG_provisioning_profiles_dir/$PROFILE_UUID.mobileprovision"
cp "$PROVISION_PATH" "${provisioning_profile_file_path}"

if [[ ! -f "${provisioning_profile_file_path}" ]] ; then
  finalcleanup "Mobileprovision File not found at path: ${provisioning_profile_file_path}"
  exit 1
fi
echo "PROFILE_UUID: $PROFILE_UUID"

# Get identities from certificate
export CERTIFICATE_IDENTITY=$(security find-certificate -a ${BITRISE_KEYCHAIN} | grep -Ei '"labl"<blob>=".*"' | grep -oEi '=".*"' | grep -oEi '[^="]+' | head -n 1)
echo "CERTIFICATE_IDENTITY: $CERTIFICATE_IDENTITY"

# Start the build
if [[ "${XCODE_BUILDER_ACTION}" == "build" ]] ; then
  print_and_do_command_exit_on_error ${CONFIG_build_tool} \
    ${CONFIG_xcode_project_action} "$projectfile" \
    -scheme "${XCODE_BUILDER_SCHEME}" \
    clean build \
    CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    OTHER_CODE_SIGN_FLAGS="--keychain ${BITRISE_KEYCHAIN}"
elif [[ "${XCODE_BUILDER_ACTION}" == "unittest" ]] ; then
  #
  # OLD METHOD (doesn't work if it runs through SSH)
  #

  # ${CONFIG_build_tool} \
  #   ${CONFIG_xcode_project_action} "$projectfile" \
  #   -scheme "${XCODE_BUILDER_SCHEME}" \
  #   clean test \
  #   -destination "${CONFIG_unittest_device_destination}" \
  #   -sdk iphonesimulator \
  #   CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
  #   PROVISIONING_PROFILE="$PROFILE_UUID" \
  #   OTHER_CODE_SIGN_FLAGS="--keychain ${BITRISE_KEYCHAIN}"

  #
  # xcuserver based solution (works through SSH)
  #
  KEYCHAIN_PASSWORD="${KEYCHAIN_PASSPHRASE}" KEYCHAIN_NAME="${BITRISE_KEYCHAIN}" PROVISIONING_PROFILE="${PROFILE_UUID}" CODE_SIGN_IDENTITY="${CERTIFICATE_IDENTITY}" BUILD_PROJECTDIR="$(pwd)" BUILD_PROJECTFILE="${projectfile}" BUILD_BUILDTOOL="${CONFIG_build_tool}" BUILD_SCHEME="${{XCODE_BUILDER_SCHEME}}" BUILD_DEVICENAME="${CONFIG_unittest_simulator_name}" bash "${THIS_SCRIPT_DIR}/xcuserver_utils/run_unit_test_with_xcuserver.sh"
elif [[ "${XCODE_BUILDER_ACTION}" == "analyze" ]] ; then
  ${CONFIG_build_tool} \
    ${CONFIG_xcode_project_action} "$projectfile" \
    -scheme "${XCODE_BUILDER_SCHEME}" \
    clean analyze \
    CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    OTHER_CODE_SIGN_FLAGS="--keychain ${BITRISE_KEYCHAIN}"
elif [[ "${XCODE_BUILDER_ACTION}" == "archive" ]] ; then
  ${CONFIG_build_tool} \
    ${CONFIG_xcode_project_action} "$projectfile" \
    -scheme "${XCODE_BUILDER_SCHEME}" \
    clean archive -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="$CERTIFICATE_IDENTITY" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    OTHER_CODE_SIGN_FLAGS="--keychain ${BITRISE_KEYCHAIN}"
fi
build_res_code=$?

if [ ${build_res_code} -eq 0 ]; then
  export XCODEBUILD_STATUS="succeeded"
else
  export XCODEBUILD_STATUS="failed"
fi
echo "XCODEBUILD_STATUS: $XCODEBUILD_STATUS"

if [[ "${XCODEBUILD_STATUS}" == "succeeded" ]] ; then
  if [[ "${XCODE_BUILDER_ACTION}" == "build" || "${XCODE_BUILDER_ACTION}" == "analyze" || "${XCODE_BUILDER_ACTION}" == "unittest" ]] ; then
    # done
    is_build_action_success=1
    finalcleanup
    exit 0
  fi
else
  finalcleanup "Xcode '${XCODE_BUILDER_ACTION}' Action Failed"
  exit 1
fi

#
# ARCHIVE

# Export ipa if everyting succeeded
if [[ "${XCODE_BUILDER_ACTION}" == "archive" ]] ; then
  if [[ "$XCODEBUILD_STATUS" == "succeeded" ]] ; then
    # Export ipa
    write_section_to_formatted_output "## Generating signed IPA"

    xcodebuild \
      -exportArchive \
      -exportFormat ipa \
      -archivePath "${ARCHIVE_PATH}" \
      -exportPath "${EXPORT_PATH}" \
      -exportWithOriginalSigningIdentity
    ecode=$?
    
    if [[ ${ecode} != 0 ]] ; then
      echo " (!) Exit code was: ${ecode}"
      finalcleanup "Xcode Export Archive action failed!"
      exit ${ecode}
    else
      echo_string_to_formatted_output "* (i) Archive build success"
    fi
    echo "export BITRISE_IPA_PATH='${EXPORT_PATH}.ipa'" >> ~/.bash_profile
    echo_string_to_formatted_output "* (i) .IPA path: ${EXPORT_PATH}.ipa"

    # get the .app.dSYM folders from the dSYMs archive folder
    archive_dsyms_folder="${ARCHIVE_PATH}/dSYMs"
    echo "$ ls ${archive_dsyms_folder}"
    ls "${archive_dsyms_folder}"
    app_dsym_count=0
    app_dsym_path=""

    IFS=$'\n'
    for a_app_dsym in $(find "${archive_dsyms_folder}" -type d -name "*.app.dSYM") ; do
      echo " (i) .app.dSYM found: ${a_app_dsym}"
      app_dsym_count=$[app_dsym_count + 1]
      app_dsym_path="${a_app_dsym}"
      echo " (i) app_dsym_count: $app_dsym_count"
    done
    unset IFS

    echo " (i) Found dSYM count: ${app_dsym_count}"
    if [ ${app_dsym_count} -eq 1 ] ; then
      echo_string_to_formatted_output "* (i) dSYM found at: ${app_dsym_path}"
    else
      finalcleanup "More than one or no dSYM found!"
      exit 1
    fi

    # Generate dSym zip
    export DSYM_PATH="${app_dsym_path}"
    if [ -d "${DSYM_PATH}" ]; then
      echo "Generating zip for dSym"

      /usr/bin/zip -rTy \
        "${DSYM_ZIP_PATH}" \
        "${DSYM_PATH}"
      ecode=$?

      if [[ ${ecode} != 0 ]] ; then  
        echo " (!) Exit code was: ${ecode}"
        finalcleanup "Failed to create dSYM ZIP"
        exit ${ecode}
      fi
      echo "export BITRISE_DSYM_PATH='${DSYM_ZIP_PATH}'" >> ~/.bash_profile
      is_build_action_success=1
    else
      finalcleanup "No dSYM file found in ${DSYM_PATH}"
      exit 1
    fi
  fi
fi

finalcleanup
