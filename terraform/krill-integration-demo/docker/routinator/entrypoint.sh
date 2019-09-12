#!/bin/sh
BANNER="Routinator setup for Krill"
if [ ! -f ~/routinator.initialized ]; then
    echo "${BANNER}: First time setup"

    echo "${BANNER}: Creating TALs directory.."
    mkdir -p ~/.rpki-cache/tals

    echo "${BANNER}: Fetching Krill TA TAL.."
    while true; do
        wget https://${KRILL_FQDN}/ta/ta.tal -O ~/.rpki-cache/tals/ta.tal && break
    done

    echo "${BANNER}: Finished"
    touch ~/routinator.initialized
fi

exec routinator "$@"
