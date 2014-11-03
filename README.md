steps-xcode-builder
===================

This Step is part of the [Open StepLib](http://www.steplib.com/), you can find its StepLib page [here](http://www.steplib.com/step/xcode-builder)

# Input Environment Variables

Check the *step.yml* descriptor file.


## UnitTest specific input note

- UNITTEST_PLATFORM_NAME: device to run the tests with, will be appended to the "platform=iOS Simulator,name=" `-destination` flag of the xcodebuild command. Default is "iPad". For iPhone devices you have to specify the full name of the simulator device, like: "iPhone Retina (4-inch)" - as it is shown in Xcode's device selection dropdown UI. You can specify the OS version too, by appending "OS=x.x" where x.x is the OS version. A few examples (for Xcode 5):
    - iPhone Retina (4-inch)
    - iPhone Retina (4-inch),OS=7.1
    - iPhone Retina (4-inch 64-bit)
    - iPad
    - iPad,OS=7.1
    - iPad Retina (64-bit)


# Output Environment Variables

(accessible for Steps running after this Step)

Check the *step.yml* descriptor file.


# Unit Tests

The iPhone/iOS Simulator is tightly integrated with OS X and it's not an easy task to run Unit Tests with it reliably, especially through SSH.

Because of this we use Bitrise's *xcodebuild-unittest-miniserver* (xcuserver) to run our Unit Tests. You can find it's code on GitHub: [https://github.com/bitrise-io/xcodebuild-unittest-miniserver](https://github.com/bitrise-io/xcodebuild-unittest-miniserver).

The xcuserver is preinstalled on Bitrise's OS X VMs and started with launchctl (in a proper GUI context required for the iPhone/iOS Simulator) automatically when the user logs in.

