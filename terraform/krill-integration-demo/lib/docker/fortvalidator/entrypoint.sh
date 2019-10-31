#!/bin/sh
BANNER="Fort Validator setup for Krill"
if [ ! -f /tmp/fort.initialized ]; then
    echo "${BANNER}: First time setup"

   echo "${BANNER}: Fetching Krill TA TAL.."
   while true; do
       wget https://${KRILL_FQDN}/ta/ta.tal -O /tmp/ta.tal && break
	sleep 5s
   done

    echo "${BANNER}: Finished"
    touch /tmp/fort.initialized
fi

cd /tmp/
fort --mode standalone --output.roa test.roa --tal /tmp/ta.tal --local-repository cache "$@"
cat /tmp/test.roa