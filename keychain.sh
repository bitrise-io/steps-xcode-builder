if [[ $1 == "add" ]]; then
  export SAVED_KEYCHAINS=$(security list-keychain)

  # Create the keychain
  security create-keychain -p $CONCRETE_KEYCHAIN_PASSPHRASE $CONCRETE_KEYCHAIN_PATH

  # Import to keychain
  security import $CERTIFICATE_PATH -k $CONCRETE_KEYCHAIN_PATH -P $CONCRETE_CERTIFICATE_PASSPHRASE -T /usr/bin/codesign

  # Add to the searchable keychains
  security list-keychain -s $CONCRETE_KEYCHAIN_PATH

  # Unlock keychain
  security unlock-keychain -p $CONCRETE_KEYCHAIN_PASSPHRASE $CONCRETE_KEYCHAIN_PATH
elif [[ $1 = "remove" ]]; then
  security delete-keychain $CONCRETE_KEYCHAIN_PATH

  unset SAVED_KEYCHAINS
  unset CERTIFICATE_IDENTITY
fi