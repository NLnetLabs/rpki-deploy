#!/bin/sh
mkdir $HOME/secrets
# --batch to prevent interactive command --yes to assume "yes" for questions
gpg --quiet --batch --yes --decrypt --passphrase="$DECRYPT_PW" \
    --output $HOME/secrets/ssh_key ssh_key.gpg