#!/bin/bash

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

param_projectdir="${BUILD_PROJECTDIR}"
param_projectfile="${BUILD_PROJECTFILE}"
param_buildtool="${BUILD_BUILDTOOL}"
param_scheme="${BUILD_SCHEME}"
param_device_name="${BUILD_DEVICENAME}"
code_sign_identity="${CODE_SIGN_IDENTITY}"
provisioning_profile="${PROVISIONING_PROFILE}"
keychain_name="${KEYCHAIN_NAME}"
keychain_password="${KEYCHAIN_PASSWORD}"

echo " (i) param_projectdir: ${param_projectdir}"
echo " (i) param_projectfile: ${param_projectfile}"
echo " (i) param_buildtool: ${param_buildtool}"
echo " (i) param_scheme: ${param_scheme}"
echo " (i) param_device_name: ${param_device_name}"

echo " (i) code_sign_identity: ${code_sign_identity}"
echo " (i) provisioning_profile: ${provisioning_profile}"
echo " (i) keychain_name: ${keychain_name}"
echo " (i) keychain_password: ${keychain_password}"

buildlogpath="${HOME}/logs/xcuserver_build.log"

endsequence="XCODEBUILDUNITTESTFINISHED:"
# clear the log
echo '' > "${buildlogpath}"

build_config_path="${HOME}/Desktop/xcuserver_build_config"



cat >"${build_config_path}" <<EOL
projectdir=${param_projectdir}
projectfile=${param_projectfile}
buildtool=${param_buildtool}
scheme=${param_scheme}
devicedestination=platform=iOS Simulator,name=${param_device_name}
outputlogpath=${buildlogpath}
code_sign_identity=${code_sign_identity}
provisioning_profile=${provisioning_profile}
keychain_name=${keychain_name}
keychain_password=${keychain_password}
EOL
if [ $? -ne 0 ]; then
	echo " [!] Failed to write the XCUServer Build Config to path: ${build_config_path}"
	exit 1
fi


(
	# Xcode 5 Simulator:
	# osascript -e 'tell application "iPhone Simulator" to quit'
	# Xcode 6 Simulator:
	# osascript -e 'tell application "iOS Simulator" to quit'
	# sleep 2
	# open -a iPhone\ Simulator
	# sleep 5

	# -> simulator reset scripts will prompt for Accessibility at the first runs!
	#  		if you decide to use it you'll have to run it a few times and accept these prompts
	# osascript "${THIS_SCRIPT_DIR}/simulator_reset_content_6.osascript"
	# sleep 10

	curlres="$(curl -s "http://localhost:8081/unittest?configfile=${build_config_path}")"

	# osascript -e 'tell application "iPhone Simulator" to quit'
	# osascript -e 'tell application "iOS Simulator" to quit'

	# echo "Result: ${curlres}"
	if [[ "${curlres}" == "" ]]; then
		# force end - no curl response
		echo "${endsequence} error" >> "${buildlogpath}"
		echo '.' >> "${buildlogpath}"
		echo '' >> "${buildlogpath}"
		echo '.' >> "${buildlogpath}"
		echo '' >> "${buildlogpath}"
	fi
) &

# tail -f "${buildlogpath}" | sed '/^XCODEBUILDUNITTESTFINISHED$/ q'
# tail -f "${buildlogpath}" | tee >( grep -qx "XCODEBUILDUNITTESTFINISHED" )
sed '/XCODEBUILDUNITTESTFINISHED:/q' <(tail -n 0 -f "${buildlogpath}")

# determin success
res_success_marker="XCODEBUILDUNITTESTFINISHED: ok"
res_lin="$(grep -m1 "${res_success_marker}" "${buildlogpath}")"
if [[ "${res_lin}" == "${res_success_marker}" ]]; then
	echo " (i) SUCCESS"
	exit 0
fi

echo " [!] FAILED"
exit 1
