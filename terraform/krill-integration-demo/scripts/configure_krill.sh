#!/bin/bash
set -e -u -o pipefail

KRILL_CONTAINER="krill"
KRILL_AUTH_TOKEN=$(docker logs ${KRILL_CONTAINER} 2>&1 | tac | grep -Eom 1 'token [a-z0-9-]+' | cut -d ' ' -f 2)
WGET_UNSAFE_TO_STDOUT="wget -4 --no-check-certificate -qO-"
EXT_TAL_URI="https://${KRILL_FQDN}/ta/ta.tal"

krillc() {
    docker exec -e KRILL_CLI_SERVER=https://localhost:3000/ -e KRILL_CLI_TOKEN=${KRILL_AUTH_TOKEN} ${KRILL_CONTAINER} krillc $@
}

my_retry() {
    MAX_TRIES=$1
    SLEEP_BETWEEN=$2
    shift 2
    TRIES=1
    while true; do
        echo "Attempt ${TRIES}/${MAX_TRIES}: " $@
        $@ && return 0
        (( TRIES=TRIES+1 ))
        [ ${TRIES} -le ${MAX_TRIES} ] || return 1
        sleep $SLEEP_BETWEEN
    done
}

if ! krillc show --ca child --format none; then
    my_retry 5 2 krillc add --ca child
fi

if [ "$(krillc show --ca ta --format json | jq '.children | length')" -eq 0 ]; then
    my_retry 5 2 krillc children add --embedded --ca ta --child child --ipv4 "10.0.0.0/16" --ipv6 "2001:3200:3200::66" --asn 1
fi

if [ "$(krillc show --ca child --format json | jq '.parents | length')" -eq 0 ]; then
    my_retry 5 2 krillc parents add --embedded --ca child --parent ta
fi

if [ "$(krillc roas list --ca child --format json | jq '. | length')" -eq 0 ]; then
    my_retry 5 2 krillc roas update --ca child --delta /tmp/ka/delta.1
fi

# Workaround for https://github.com/NLnetLabs/krill/issues/125.
# Copy the CER file to the RSYNC repo for clients that don't support HTTPS
# URIs in the TAL file. We must:
#   1. Extract the CER file URI from the remote TAL file.
#   2. Extract the external domain name (EXT_DOM) from the CER URI.
#   3. Download the CER file to the repo/${EXT_DOM}/ directory inside the 
#      krill container.
#
# Note: Clients that don't support HTTPS URIs in TAL files must now download
# and edit the TAL file before using it such that they replace the HTTPS
# protocol with the RSYNC protocol.
#
# Note: We have to run wget commands locally as the Krill container doesn't
# have wget or curl or similar installed in it.

# 0. Wait for the TAL file to become available externally
my_retry 12 5 ${WGET_UNSAFE_TO_STDOUT} ${EXT_TAL_URI} >/dev/null

# 1.Extract the CER file URI from the remote TAL file.
CER_URI=$(${WGET_UNSAFE_TO_STDOUT} ${EXT_TAL_URI} | grep -F "https")

# Now CER_URI should be something like https://${EXT_DOM}/ta/ta.cer
# 2. Extract the external domain name (EXT_DOM) from the CER URI.
EXT_DOM=$(echo $CER_URI | cut -d '/' -f 3)

# 3. Download the CER file to the repo/${EXT_DOM}/ directory inside the 
#    krill container.
# The Bash ## operator "removes the largest possible matching string from the
# beginning of the variable's contents", leaving us with something like
# ta/ta.cer.
CER_REL_PATH=${CER_URI##*$EXT_DOM/}

echo "Checking if rewritten TA CER already exists in the RSYNC repo.."
if ! rsync -4 rsync://${EXT_DOM}/repo/${CER_REL_PATH} >/dev/null; then
    echo "Cloning and rewriting Krill TA CER to the RSYNC repo.."

    DST_PATH="repo/rsync/${EXT_DOM}/repo/${CER_REL_PATH}"
    # We use docker exec instead of docker cp because docker cp doesn't support
    # piping from stdin unless stdin is a tar archive.
    ${WGET_UNSAFE_TO_STDOUT} ${CER_URI} | docker exec -i ${KRILL_CONTAINER} sh -c "cat - > ${DST_PATH}"

    echo "Installed Krill trust anchor certificate into rsync repo at:"
    docker exec ${KRILL_CONTAINER} ls -la ${DST_PATH}
fi