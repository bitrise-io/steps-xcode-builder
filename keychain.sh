export CONCRETE_KEYCHAIN="login.keychain"

if [[ $1 == "add" ]]; then
  export KEYCHAIN_PASSPHRASE="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"

  # Create the keychain
  security create-keychain -p $KEYCHAIN_PASSPHRASE $CONCRETE_KEYCHAIN
  security default-keychain -d user -s $CONCRETE_KEYCHAIN

  # Import to keychain
  security import $CERTIFICATE_PATH -k $CONCRETE_KEYCHAIN -P $CONCRETE_CERTIFICATE_PASSPHRASE -T /usr/bin/codesign

  # Unlock keychain
  security unlock-keychain -p $KEYCHAIN_PASSPHRASE $CONCRETE_KEYCHAIN
  security set-keychain-settings -lut 7200 $CONCRETE_KEYCHAIN
elif [[ $1 = "remove" ]]; then
  security delete-keychain $CONCRETE_KEYCHAIN
fi