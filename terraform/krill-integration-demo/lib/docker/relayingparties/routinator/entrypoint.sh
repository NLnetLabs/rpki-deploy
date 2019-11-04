#!/bin/sh
set -e -u -o pipefail

DATA_DIR=/tmp/routinator
TAL_DIR=~/.rpki-cache/tals
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="Routinator setup for Krill"
source /opt/my_funcs.sh

install_tal_from_remote --no-rewrite https://${KRILL_FQDN}/ta/ta.tal ${TAL_DIR}/ta.tal

my_log "Waiting for Krill TA certificate to become available via RSYNC"
my_retry 12 5 rsync -4 rsync://${KRILL_FQDN}/repo/ta/ta.cer >/dev/null

my_log "Launching Routinator"
cd ${DATA_DIR}
routinator \
    -vvv \
    vrps \
    -o output.json \
    -f json \
    --complete

my_log "Dumping received ROAs"
echo -n "TEST OUT: "
cat ${DATA_DIR}/output.json | paste -sd ' ' -