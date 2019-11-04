#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/octorpki
TAL_DIR=${DATA_DIR}/tals
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="OctoRPKI setup for Krill"
source /opt/my_funcs.sh

install_tal_from_remote https://${KRILL_FQDN}/ta/ta.tal ${TAL_DIR}/ta.tal

my_log "Waiting for Krill TA certificate to become available via RSYNC"
my_retry 12 5 rsync -4 rsync://${KRILL_FQDN}/repo/ta/ta.cer >/dev/null

my_log "Launching OctoRPKI"
cd / # needed by OctoRPKI to find file /private.pem
/octorpki \
    -mode oneoff \
    -tal.name ta \
    -tal.root ${TAL_DIR}/ta.tal \
    -output.roa ${DATA_DIR}/output.json

my_log "Dumping received ROAs"
echo -n "TEST OUT: "
cat ${DATA_DIR}/output.json | paste -sd ' ' -