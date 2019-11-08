#!/bin/bash
set -euo pipefail

export BANNER="$(basename $0):"

KRILL_CONTAINER="krill"
KRILL_AUTH_TOKEN=$(docker logs ${KRILL_CONTAINER} 2>&1 | tac | grep -Eom 1 'token [a-z0-9-]+' | cut -d ' ' -f 2)
WGET_UNSAFE_QUIET="wget -4 --no-check-certificate -q"
WGET_UNSAFE_TO_STDOUT="${WGET_UNSAFE_QUIET}O-"

source ../lib/docker/relyingparties/base/my_funcs.sh

krillc() {
    docker exec \
        -e KRILL_CLI_SERVER=https://localhost:3000/ \
        -e KRILL_CLI_TOKEN=${KRILL_AUTH_TOKEN} \
        ${KRILL_CONTAINER} \
        krillc $@
}

my_log "Use embedded trust anchor? ${KRILL_USE_TA}"
my_log "TAL to be used by clients: ${SRC_TAL}"

my_log "Waiting for Krill to become healthy via NGINX"
my_retry 12 5 ${WGET_UNSAFE_TO_STDOUT} -S https://${KRILL_FQDN}/health

if [[ "${KRILL_USE_TA}" == "true" ]]; then
    my_log "Using Krill embedded TA"

    my_log "Checking to see if the child CA exists"
    if ! my_try_cmd krillc show --ca child --format none; then
        my_retry 5 2 krillc add --ca child
    fi

    my_log "Checking to see if the parent CA -> child CA relationship exists"
    NUM_CHILDREN=$(my_log_cmd krillc show --ca ta --format json | jq '.children | length')
    if [ ${NUM_CHILDREN} -eq 0 ]; then
        my_retry 5 5 krillc children add --embedded --ca ta --child child --ipv4 "10.0.0.0/16" --ipv6 "2001:3200:3200::66" --asn 1
    fi

    my_log "Checking to see if the child CA -> parent CA relationship exists"
    NUM_PARENTS=$(my_log_cmd krillc show --ca child --format json | jq '.parents | length')
    if [ ${NUM_PARENTS} -eq 0 ]; then
        my_retry 5 5 krillc parents add --embedded --ca child --parent ta
    fi

    my_log "Checking to see if the child CA ROAs exist"
    NUM_CHILD_ROAS=$(my_log_cmd krillc roas list --ca child --format json | jq '. | length')
    if [ ${NUM_CHILD_ROAS} -eq 0 ]; then
        my_retry 5 5 krillc roas update --ca child --delta /tmp/ka/delta.1
    fi
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

if [[ "${SRC_TAL}" == http* ]]; then
    if [[ "${KRILL_USE_TA}" == "true" ]]; then
        # 1.Extract the CER file URI from the remote TAL file.
        CER_URI=$(my_retry 12 5 ${WGET_UNSAFE_TO_STDOUT} ${SRC_TAL} | grep -F "https")

        # Now CER_URI should be something like https://${EXT_DOM}/ta/ta.cer
        # 2. Extract the external domain name (EXT_DOM) from the CER URI.
        EXT_DOM=$(echo $CER_URI | cut -d '/' -f 3)

        # 3. Download the CER file to the repo/${EXT_DOM}/ directory inside the 
        #    krill container.
        # The Bash ## operator "removes the largest possible matching string from the
        # beginning of the variable's contents", leaving us with something like
        # ta/ta.cer.
        CER_REL_PATH=${CER_URI##*$EXT_DOM/}

        my_log "Checking if rewritten TA CER already exists in the RSYNC repo.."
        if ! my_try_cmd rsync -4 rsync://${EXT_DOM}/repo/${CER_REL_PATH} >/dev/null; then
            my_log "Cloning and rewriting Krill TA CER to the RSYNC repo.."

            DST_PATH="repo/rsync/current/${CER_REL_PATH}"
            # We use docker exec instead of docker cp because docker cp doesn't support
            # piping from stdin unless stdin is a tar archive. That didn't work so this
            # goes even further installing Wget on the Krill container because piping
            # via docker exec caused the written CER file to be corrupted...
            docker exec -i ${KRILL_CONTAINER} sh -c "apt-get update && apt-get -y install wget && ${WGET_UNSAFE_QUIET} -O${DST_PATH} ${CER_URI}"

            my_log "Installed Krill trust anchor certificate into rsync repo at:"
            my_log_cmd docker exec ${KRILL_CONTAINER} ls -la ${DST_PATH}
        fi
    fi
fi

my_log "Done"