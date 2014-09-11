#!/bin/bash

#
# The Bitrise VMs have the preinstalled Xcode's in the /Applications/Xcodes folder
#

select_xcode_version="$1"

sudo xcode-select --switch "/Applications/Xcodes/Xcode${select_xcode_version}.app/Contents/Developer"
exit $?