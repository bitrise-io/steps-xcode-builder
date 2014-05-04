steps-xcode-builder
===================

# Input Environment Variables
- CONCRETE_SOURCE_DIR

# Output Environment Variables (accessible for Steps running after this Step)
if CONCRETE_ACTION_BUILD
  - CONCRETE_BUILD_STATUS=[success/failed]
if CONCRETE_ACTION_ANALYZE
  - CONCRETE_ANALYZE_STATUS=[success/failed]
if CONCRETE_ACTION_ARCHIVE
  - CONCRETE_ARCHIVE_STATUS=[success/failed]
  - CONCRETE_IPA_PATH
  - CONCRETE_DSYM_PATH