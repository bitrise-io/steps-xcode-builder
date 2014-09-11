steps-xcode-builder
===================

# Input Environment Variables
- BITRISE_PROJECT_PATH
- BITRISE_SCHEME
- BITRISE_ACTION_BUILD or BITRISE_ACTION_ANALYZE or BITRISE_ACTION_ARCHIVE or BITRISE_ACTION_UNITTEST
- BITRISE_CERTIFICATE_PASSPHRASE
- BITRISE_CERTIFICATE_URL
- BITRISE_PROVISION_URL
- BITRISE_BUILD_TOOL: "xcodebuild" is the default; "xctool" is supported; BITRISE_ACTION_ARCHIVE and BITRISE_ACTION_UNITTEST can only use "xcodebuild"

## UnitTest specific inputs
- UNITTEST_PLATFORM_NAME: device to run the tests with, will be appended to the "platform=iOS Simulator,name=" `-destination` flag of the xcodebuild command. Default is "iPad". For iPhone devices you have to specify the full name of the simulator device, like: "iPhone Retina (4-inch)" - as it is shown in Xcode's device selection dropdown UI. You can specify the OS version too, by appending "OS=x.x" where x.x is the OS version. A few examples:
    - iPhone Retina (4-inch)
    - iPhone Retina (4-inch),OS=7.1
    - iPhone Retina (4-inch 64-bit)
    - iPad
    - iPad,OS=7.1
    - iPad Retina (64-bit)


# Output Environment Variables
(accessible for Steps running after this Step)

## if BITRISE_ACTION_BUILD
- BITRISE_BUILD_STATUS=[succeeded/failed] 

## if BITRISE_ACTION_ANALYZE
- BITRISE_ANALYZE_STATUS=[succeeded/failed]

## if BITRISE_ACTION_UNITTEST
- BITRISE_UNITTEST_STATUS=[succeeded/failed]

## if BITRISE_ACTION_ARCHIVE
- BITRISE_ARCHIVE_STATUS=[succeeded/failed]
- BITRISE_IPA_PATH
- BITRISE_DSYM_PATH

# Unit Tests

The iPhone/iOS Simulator is tightly integrated with OS X and it's not an easy task to run Unit Tests with it reliably, especially through SSH.

Because of this we use Bitrise's *xcodebuild-unittest-miniserver* (xcuserver) to run our Unit Tests. You can find it's code on GitHub: [https://github.com/bitrise-io/xcodebuild-unittest-miniserver](https://github.com/bitrise-io/xcodebuild-unittest-miniserver).

The xcuserver is preinstalled on Bitrise's OS X VMs and started with launchctl (in a proper GUI context required for the iPhone/iOS Simulator) automatically when the user logs in.

