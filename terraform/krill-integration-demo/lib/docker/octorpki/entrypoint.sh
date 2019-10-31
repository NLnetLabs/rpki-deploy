#!/bin/sh
BANNER="OctoRPKI setup for Krill"
if [ ! -f /tmp/octorpki.initialized ]; then
    echo "${BANNER}: First time setup"

   echo "${BANNER}: Fetching Krill TA TAL.."
   while true; do
       wget https://${KRILL_FQDN}/ta/ta.tal -O /tmp/ta.tal && break
	sleep 5s
   done

    echo "${BANNER}: Finished"
    touch /tmp/octorpki.initialized
fi

./octorpki -output.roa /tmp/output.json "$@"
cat /tmp/output.json