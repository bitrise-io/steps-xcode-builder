if [[ $1 == "add" ]]; then
  export SAVED_KEYCHAINS=$(security list-keychain)
  export KEYCHAIN_PASSPHRASE=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

  # Create the keychain
  security create-keychain -p $KEYCHAIN_PASSPHRASE $CONCRETE_KEYCHAIN_PATH

  # Import to keychain
  security import $CERTIFICATE_PATH -k $CONCRETE_KEYCHAIN_PATH -P $CONCRETE_CERTIFICATE_PASSPHRASE -T /usr/bin/codesign

  # Add to the searchable keychains
  security list-keychain -s $CONCRETE_KEYCHAIN_PATH

  # Unlock keychain
  security unlock-keychain -p $KEYCHAIN_PASSPHRASE $CONCRETE_KEYCHAIN_PATH
  security set-keychain-settings -lut 7200 $CONCRETE_KEYCHAIN_PATH
elif [[ $1 = "remove" ]]; then
  security delete-keychain $CONCRETE_KEYCHAIN_PATH

  unset SAVED_KEYCHAINS
  unset CERTIFICATE_IDENTITY
fi