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
  local fail_msg="$1"

  # unset UUID
  # rm "${CONFIG_provisioning_profiles_dir}/${PROFILE_UUID}.mobileprovision"
  # Keychain have to be removed - it's password protected
  #  and the password is only available in this step!
  keychain_fn "remove"

  # # Remove downloaded files
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
  local err_msg="$1"
  finalcleanup "${err_msg}"
}
set_error_cleanup_function CLEANUP_ON_ERROR_FN


# ------------------------------
# --- Utils - Keychain

function keychain_fn {
  if [[ "$1" == "add" ]] ; then
    # LC_ALL: required for tr, for more info: http://unix.stackexchange.com/questions/45404/why-cant-tr-read-from-dev-urandom-on-osx
    # export KEYCHAIN_PASSPHRASE="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"

    # Create the keychain
    print_and_do_command_exit_on_error security -v create-keychain -p "${KEYCHAIN_PASSPHRASE}" "${BITRISE_KEYCHAIN}"

    # Import to keychain
    print_and_do_command_exit_on_error security -v import "${CERTIFICATE_PATH}" -k "${BITRISE_KEYCHAIN}" -P "${XCODE_BUILDER_CERTIFICATE_PASSPHRASE}" -A

    # Unlock keychain
    print_and_do_command_exit_on_error security -v set-keychain-settings -lut 72000 "${BITRISE_KEYCHAIN}"
    print_and_do_command_exit_on_error security -v list-keychains -s "${BITRISE_KEYCHAIN}"
    print_and_do_command_exit_on_error security -v list-keychains
    print_and_do_command_exit_on_error security -v default-keychain -s "${BITRISE_KEYCHAIN}"
    print_and_do_command_exit_on_error security -v unlock-keychain -p "${KEYCHAIN_PASSPHRASE}" "${BITRISE_KEYCHAIN}"
  elif [[ "$1" == "remove" ]] ; then
    print_and_do_command_exit_on_error security -v delete-keychain "${BITRISE_KEYCHAIN}"
  fi
}


# ------------------------------
# --- Configs

CONFIG_provisioning_profiles_dir="${HOME}/Library/MobileDevice/Provisioning Profiles"
CONFIG_tmp_profile_dir="${HOME}/tmp_profiles"


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
  echo_string_to_formatted_output "* Certificate Dir Path: ${XCODE_BUILDER_CERTIFICATES_DIR}"
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
  print_and_do_command bash "${THIS_SCRIPT_DIR}/bitrise_utils/select_xcode_version.sh" "${use_xcode_version}"
  fail_if_cmd_error "Failed to select the specified Xcode version!"
fi
echo " (i) Using Xcode version:"
print_and_do_command_exit_on_error xcodebuild -version



# ------------------------------
# --- Main

# --- Create directory structure
print_and_do_command_exit_on_error mkdir -p "${CONFIG_provisioning_profiles_dir}"
print_and_do_command_exit_on_error mkdir -p "${CONFIG_tmp_profile_dir}"
print_and_do_command_exit_on_error mkdir -p "${XCODE_BUILDER_CERTIFICATES_DIR}"
if [[ "${XCODE_BUILDER_ACTION}" == "archive" ]] ; then
  print_and_do_command_exit_on_error mkdir -p "${XCODE_BUILDER_DEPLOY_DIR}"
fi

# --- Switch to project's dir
print_and_do_command cd "${XCODE_BUILDER_PROJECT_ROOT_DIR_PATH}"
fail_if_cmd_error "Failed to switch directory to the Project Root Directory"


projectdir="$(dirname "${XCODE_BUILDER_PROJECT_PATH}")"
projectfile="$(basename "${XCODE_BUILDER_PROJECT_PATH}")"
#
print_and_do_command cd "${projectdir}"
fail_if_cmd_error "Failed to switch to the Project-File's Directory"




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


# --- Get certificate
echo "---> Downloading Certificate..."
export CERTIFICATE_PATH="${XCODE_BUILDER_CERTIFICATES_DIR}/Certificate.p12"
print_and_do_command curl -Lfso "${CERTIFICATE_PATH}" "${XCODE_BUILDER_CERTIFICATE_URL}"
cert_curl_result=$?
if [ ${cert_curl_result} -ne 0 ]; then
  echo " (i) First download attempt failed - retry..."
  sleep 5
  print_and_do_command_exit_on_error curl -Lfso "${CERTIFICATE_PATH}" "${XCODE_BUILDER_CERTIFICATE_URL}"
fi
echo "CERTIFICATE_PATH: ${CERTIFICATE_PATH}"
if [[ ! -f "${CERTIFICATE_PATH}" ]]; then
  finalcleanup "CERTIFICATE_PATH: File not found - failed to download"
  exit 1
else
  echo " -> CERTIFICATE_PATH: OK"
fi

# LC_ALL: required for tr, for more info: http://unix.stackexchange.com/questions/45404/why-cant-tr-read-from-dev-urandom-on-osx
keychain_pass="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
export KEYCHAIN_PASSPHRASE="${keychain_pass}"
keychain_fn "add"


# Get identities from certificate
export CERTIFICATE_IDENTITY=$(security find-certificate -a ${BITRISE_KEYCHAIN} | grep -Ei '"labl"<blob>=".*"' | grep -oEi '=".*"' | grep -oEi '[^="]+' | head -n 1)
echo "CERTIFICATE_IDENTITY: $CERTIFICATE_IDENTITY"


# --- Get provisioning profile(s)
xcode_build_param_prov_profile_UUID=""
echo "---> Provisioning Profile handling..."
IFS='|' read -a prov_profile_urls <<< "${XCODE_BUILDER_PROVISION_URL}"
prov_profile_count="${#prov_profile_urls[@]}"
echo " (i) Provided Provisioning Profile count: ${prov_profile_count}"
for idx in "${!prov_profile_urls[@]}"
do
  a_profile_url="${prov_profile_urls[idx]}"
  echo " -> Downloading Provisioning Profile (${idx}): ${a_profile_url}"

  a_prov_profile_tmp_path="${CONFIG_tmp_profile_dir}/profile-${idx}.mobileprovision"
  echo " (i) a_prov_profile_tmp_path: ${a_prov_profile_tmp_path}"
  print_and_do_command curl -Lfso "${a_prov_profile_tmp_path}" "${a_profile_url}"
  prov_profile_curl_result=$?
  if [ ${prov_profile_curl_result} -ne 0 ]; then
    echo " (i) First download attempt failed - retry..."
    sleep 5
    print_and_do_command_exit_on_error curl -Lfso "${a_prov_profile_tmp_path}" "${a_profile_url}"
  fi
  if [[ ! -f "${a_prov_profile_tmp_path}" ]] ; then
    finalcleanup "a_prov_profile_tmp_path: File not found - failed to download"
    exit 1
  fi

  # Get UUID & install provisioning profile
  a_profile_uuid=$(/usr/libexec/PlistBuddy -c "Print UUID" /dev/stdin <<< $(/usr/bin/security cms -D -i "${a_prov_profile_tmp_path}"))
  fail_if_cmd_error "Failed to get UUID from Provisioning Profile: ${a_prov_profile_tmp_path} | Most likely the Certificate can't be used with this Provisioning Profile."
  echo " (i) a_profile_uuid: ${a_profile_uuid}"
  a_provisioning_profile_file_path="${CONFIG_provisioning_profiles_dir}/${a_profile_uuid}.mobileprovision"
  print_and_do_command_exit_on_error mv "${a_prov_profile_tmp_path}" "${a_provisioning_profile_file_path}"

  if [[ "${prov_profile_count}" == "1" ]] ; then
    # force use it (specify it as a build param)
    xcode_build_param_prov_profile_UUID="${a_profile_uuid}"
  fi
done
echo " (i) Available Provisioning Profiles:"
print_and_do_command_exit_on_error ls -l "${CONFIG_provisioning_profiles_dir}"


# --- Start the build
if [[ "${XCODE_BUILDER_ACTION}" == "build" ]] ; then
  print_and_do_command ${CONFIG_build_tool} \
    ${CONFIG_xcode_project_action} "${projectfile}" \
    -scheme "${XCODE_BUILDER_SCHEME}" \
    clean build \
    PROVISIONING_PROFILE="${xcode_build_param_prov_profile_UUID}" \
    CODE_SIGN_IDENTITY="${CERTIFICATE_IDENTITY}" \
    OTHER_CODE_SIGN_FLAGS="--keychain ${BITRISE_KEYCHAIN}"
elif [[ "${XCODE_BUILDER_ACTION}" == "unittest" ]] ; then
  #
  # OLD METHOD (doesn't work if it runs through SSH)
  #

  # ${CONFIG_build_tool} \
  #   ${CONFIG_xcode_project_action} "${projectfile}" \
  #   -scheme "${XCODE_BUILDER_SCHEME}" \
  #   clean test \
  #   -destination "${CONFIG_unittest_device_destination}" \
  #   -sdk iphonesimulator \
  #   CODE_SIGN_IDENTITY="${CERTIFICATE_IDENTITY}" \
  #   OTHER_CODE_SIGN_FLAGS="--keychain ${BITRISE_KEYCHAIN}"

  #
  # xcuserver based solution (works through SSH)
  #
  export KEYCHAIN_PASSWORD="${KEYCHAIN_PASSPHRASE}"
  export KEYCHAIN_NAME="${BITRISE_KEYCHAIN}"
  export CODE_SIGN_IDENTITY="${CERTIFICATE_IDENTITY}"
  if [ ! -z "${xcode_build_param_prov_profile_UUID}" ] ; then
    export PROVISIONING_PROFILE="${xcode_build_param_prov_profile_UUID}"
  fi
  export BUILD_PROJECTDIR="$(pwd)"
  export BUILD_PROJECTFILE="${projectfile}"
  export BUILD_BUILDTOOL="${CONFIG_build_tool}"
  export BUILD_SCHEME="${XCODE_BUILDER_SCHEME}"
  export BUILD_DEVICENAME="${CONFIG_unittest_simulator_name}"
  print_and_do_command bash "${THIS_SCRIPT_DIR}/xcuserver_utils/run_unit_test_with_xcuserver.sh"
elif [[ "${XCODE_BUILDER_ACTION}" == "analyze" ]] ; then
  print_and_do_command ${CONFIG_build_tool} \
    ${CONFIG_xcode_project_action} "${projectfile}" \
    -scheme "${XCODE_BUILDER_SCHEME}" \
    clean analyze \
    PROVISIONING_PROFILE="${xcode_build_param_prov_profile_UUID}" \
    CODE_SIGN_IDENTITY="${CERTIFICATE_IDENTITY}" \
    OTHER_CODE_SIGN_FLAGS="--keychain ${BITRISE_KEYCHAIN}"
elif [[ "${XCODE_BUILDER_ACTION}" == "archive" ]] ; then
  print_and_do_command ${CONFIG_build_tool} \
    ${CONFIG_xcode_project_action} "${projectfile}" \
    -scheme "${XCODE_BUILDER_SCHEME}" \
    clean archive -archivePath "${ARCHIVE_PATH}" \
    PROVISIONING_PROFILE="${xcode_build_param_prov_profile_UUID}" \
    CODE_SIGN_IDENTITY="${CERTIFICATE_IDENTITY}" \
    OTHER_CODE_SIGN_FLAGS="--keychain ${BITRISE_KEYCHAIN}"
fi
build_res_code=$?
echo " (i) build_res_code: ${build_res_code}"

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
# --- ARCHIVE specific

# Export ipa if everyting succeeded
if [[ "${XCODE_BUILDER_ACTION}" == "archive" ]] ; then
  if [[ "$XCODEBUILD_STATUS" == "succeeded" ]] ; then
    # Export ipa
    write_section_to_formatted_output "## Generating signed IPA"

    # Get the name of the profile
    profile_name=`/usr/libexec/PlistBuddy -c 'Print :Name' /dev/stdin <<< $(security cms -D -i ${ARCHIVE_PATH}/Products/Applications/*.app/embedded.mobileprovision)`
    fail_if_cmd_error "Missing embedded mobileprovision in xcarchive"

    print_and_do_command xcodebuild \
      -exportArchive \
      -exportFormat ipa \
      -archivePath "${ARCHIVE_PATH}" \
      -exportPath "${EXPORT_PATH}" \
      -exportProvisioningProfile "${profile_name}"
    fail_if_cmd_error "Xcode Export Archive action failed!"

    echo_string_to_formatted_output "* Archive build success"
    echo "export BITRISE_IPA_PATH='${EXPORT_PATH}.ipa'" >> ~/.bash_profile
    echo_string_to_formatted_output "* .IPA path: ${EXPORT_PATH}.ipa"

    # get the .app.dSYM folders from the dSYMs archive folder
    archive_dsyms_folder="${ARCHIVE_PATH}/dSYMs"
    print_and_do_command ls "${archive_dsyms_folder}"
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
      echo_string_to_formatted_output "* dSYM found at: ${app_dsym_path}"
      if [ -d "${app_dsym_path}" ] ; then
        export DSYM_PATH="${app_dsym_path}"
      else
        echo_string_to_formatted_output "* (i) *Found dSYM path is not a directory!*"
      fi
    else
      if [ ${app_dsym_count} -eq 0 ] ; then
        echo_string_to_formatted_output "* (i) **No dSYM found!** To generate debug symbols (dSYM) go to your Xcode Project's Settings - *Build Settings - Debug Information Format* and set it to *DWARF with dSYM File*."
      else
        echo_string_to_formatted_output "* (i) *More than one dSYM found!*"
      fi
    fi

    # Generate dSym zip
    if [[ ! -z "${DSYM_PATH}" && -d "${DSYM_PATH}" ]] ; then
      echo "Generating zip for dSym"

      (
        dsym_parent_folder=$( dirname "${DSYM_PATH}" )
        dsym_fold_name=$( basename "${DSYM_PATH}" )
        # cd into dSYM parent to not to store full
        #  paths in the ZIP
        print_and_do_command_exit_on_error cd "${dsym_parent_folder}"
        print_and_do_command_exit_on_error /usr/bin/zip -rTy \
          "${DSYM_ZIP_PATH}" \
          "${dsym_fold_name}"
      )
      fail_if_cmd_error "Failed to create dSYM ZIP"

      echo "export BITRISE_DSYM_PATH='${DSYM_ZIP_PATH}'" >> ~/.bash_profile
      is_build_action_success=1
    else
      is_build_action_success=1
    fi
  fi
fi

finalcleanup
