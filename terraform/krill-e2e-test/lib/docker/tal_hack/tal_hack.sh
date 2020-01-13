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
set -euo pipefail

RSYNC_REPO_BASE_DIR="/share/tal_hack"
WGET_UNSAFE_QUIET="wget -4 --no-check-certificate -q"
WGET_UNSAFE_TO_STDOUT="${WGET_UNSAFE_QUIET}O-"

export BANNER="$(basename $0):"
source /opt/my_funcs.sh

if [[ "${SRC_TAL}" == http* ]]; then
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

        # assumes that the rsync data volume is mounted at /share
        DST_PATH="${RSYNC_REPO_BASE_DIR}/ta.cer"
        DST_DIR="$(dirname ${DST_PATH})"

        mkdir -p ${DST_DIR}

        my_log "Downloading ${CER_URI} to ${DST_PATH}"
        ${WGET_UNSAFE_QUIET} -O${DST_PATH} ${CER_URI}

        my_log "Installed trust anchor certificate into rsync repo"
        ls -la ${DST_PATH}
    fi
fi
