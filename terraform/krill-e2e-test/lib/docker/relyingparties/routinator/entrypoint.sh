#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/routinator
TAL_DIR=~/.rpki-cache/tals
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="Routinator setup for Krill"
source /opt/my_funcs.sh

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal

my_log "Launching Routinator"
cd ${DATA_DIR}
routinator \
    -vvv \
    vrps \
    -o output.json \
    -f json \
    --complete

my_log "Checking that at least one ROA was output"
NUM_ROAS=$(cat ${DATA_DIR}/output.json | jq '.roas | length')
if [ ${NUM_ROAS} -le 1 ]; then
    my_log "ERROR: Output does not contain any ROAs"
    exit 1
fi

my_log "Dumping received ROAs in the format expected by test_krill.sh"
echo -n "TEST OUT: "
cat ${DATA_DIR}/output.json | paste -sd ' ' -
