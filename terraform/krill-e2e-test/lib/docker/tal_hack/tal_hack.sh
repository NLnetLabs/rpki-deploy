#!/bin/bash
# Workaround for https://github.com/NLnetLabs/krill/issues/125.
# Copy the CER file to the RSYNC repo for clients that don't support HTTPS
# URIs in the TAL file.
#
# We must:
#   1. Extract the CER file URI from the remote TAL file.
#   2. Extract the external domain name (EXT_DOM) from the CER URI.
#   3. Download the CER file to the repo/${EXT_DOM}/ directory inside the 
#      krill container.
#
# Note: Clients that don't support HTTPS URIs in TAL files must now download
# and edit the TAL file before using it such that they replace the HTTPS
# protocol with the RSYNC protocol.
#
# See also:
#   - docker-compose.yml
#   - krill.conf
#   - rsyncd.conf
#   - my_funcs.sh::install_tal()
set -euo pipefail

RSYNC_REPO_BASE_DIR="/share/current/ta/"
WGET_UNSAFE_QUIET="wget -4 --no-check-certificate -q"
WGET_UNSAFE_TO_STDOUT="${WGET_UNSAFE_QUIET}O-"

export BANNER="$(basename $0):"
source /opt/my_funcs.sh

if [[ "${SRC_TAL}" == http* ]]; then
    CER_URI=$(my_retry 12 5 ${WGET_UNSAFE_TO_STDOUT} ${SRC_TAL} | grep -F "https")
    DST_PATH="${RSYNC_REPO_BASE_DIR}/ta.cer"
    DST_DIR="$(dirname ${DST_PATH})"

    # Loop because FORT validator forces us to store the TA CER in the same
    # repo as that written to (and completely replaced periodically) by Krill.
    # Otherwise FORT complains with errors like:
    #   ERR: rsync://rsyncd.krill.test/repo/ta/0/A1ED....A802.mft:
    #   Certificate's AIA ('rsync://rsyncd.krill.test/repo/ta/ta.cer') does not
    #   match parent's URI ('rsync://rsyncd.krill.test/tal_hack/ta.cer').
    my_log "Monitoring if rewritten TA CER already exists in the RSYNC repo.."
    while true
    do
        # if ! my_try_cmd rsync -4 rsync://${EXT_DOM}/repo/${CER_REL_PATH} >/dev/null; then
        if [ ! -f ${DST_PATH} ]; then
            my_log "Cloning and rewriting Krill TA CER to the RSYNC repo.."

            mkdir -p ${DST_DIR}

            my_log "Downloading ${CER_URI} to ${DST_PATH}"
            ${WGET_UNSAFE_QUIET} -O${DST_PATH} ${CER_URI}

            my_log "(Re)Installed trust anchor certificate into rsync repo"
        fi

        sleep 1s
    done
fi
