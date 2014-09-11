#!/bin/bash

#
# The Bitrise VMs have the preinstalled Xcode's in the /Applications/Xcodes folder
#	Xcode apps contain the major version of the Xcode app.
#	For example: Xcode5.app is the (latest) Xcode version 5
#

select_xcode_version="$1"

sudo xcode-select --switch "/Applications/Xcodes/Xcode${select_xcode_version}.app/Contents/Developer"
exit $?