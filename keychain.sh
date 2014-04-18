if [[ $1 == "add" ]]; then
  export KEYCHAIN_PASSPHRASE="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"

  # Create the keychain
  security -v create-keychain -p $KEYCHAIN_PASSPHRASE $CONCRETE_KEYCHAIN
  security -v default-keychain -d user -s $CONCRETE_KEYCHAIN

  # Import to keychain
  security -v import $CERTIFICATE_PATH -k $CONCRETE_KEYCHAIN -P $CONCRETE_CERTIFICATE_PASSPHRASE -T /usr/bin/codesign

  # Unlock keychain
  security -v unlock-keychain -p $KEYCHAIN_PASSPHRASE $CONCRETE_KEYCHAIN
  security -v set-keychain-settings -lut 7200 $CONCRETE_KEYCHAIN
  security -v list-keychains
elif [[ $1 = "remove" ]]; then
  security -v delete-keychain $CONCRETE_KEYCHAIN
fi