steps-xcode-builder
===================

# Input Environment Variables
- CONCRETE_PROJECT_PATH
- CONCRETE_SCHEME
- CONCRETE_ACTION_BUILD or CONCRETE_ACTION_ANALYZE or CONCRETE_ACTION_ARCHIVE or CONCRETE_ACTION_UNITTEST
- CONCRETE_CERTIFICATE_PASSPHRASE
- CONCRETE_CERTIFICATE_URL
- CONCRETE_PROVISION_URL
- CONCRETE_BUILD_TOOL: "xcodebuild" is the default; "xctool" is supported; CONCRETE_ARCHIVE_STATUS can only use "xcodebuild"

## UnitTest specific inputs
- UNITTEST_PLATFORM_NAME: device to run the tests with, will be appended to the "platform=iOS Simulator,name=" `-destination` flag of the xcodebuild command. Default is "iPad". For iPhone devices you have to specify the full name of the simulator device, like: "iPhone Retina (4-inch)" - as it is shown in Xcode's device selection dropdown UI

# Output Environment Variables
(accessible for Steps running after this Step)

## if CONCRETE_ACTION_BUILD
- CONCRETE_BUILD_STATUS=[success/failed] 

## if CONCRETE_ACTION_ANALYZE
- CONCRETE_ANALYZE_STATUS=[success/failed]

## if CONCRETE_ACTION_UNITTEST
- CONCRETE_UNITTEST_STATUS=[success/failed]

## if CONCRETE_ACTION_ARCHIVE
- CONCRETE_ARCHIVE_STATUS=[success/failed]
- CONCRETE_IPA_PATH
- CONCRETE_DSYM_PATH
