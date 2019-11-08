#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/octorpki
TAL_DIR=${DATA_DIR}/tals
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="OctoRPKI setup for Krill"
source /opt/my_funcs.sh

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal

my_log "Launching OctoRPKI"
cd / # needed by OctoRPKI to find file /private.pem
/octorpki \
    -mode oneoff \
    -tal.name ta \
    -tal.root ${TAL_DIR}/ta.tal \
    -output.roa ${DATA_DIR}/output.json

my_log "Dumping received ROAs in the format expected by test_krill.sh"
echo -n "TEST OUT: "
cat ${DATA_DIR}/output.json | paste -sd ' ' -