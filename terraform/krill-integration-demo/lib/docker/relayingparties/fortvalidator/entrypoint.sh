#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/fortvalidator
TAL_DIR=${DATA_DIR}/tals
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="Fort Validator setup for Krill"
source /opt/my_funcs.sh

install_tal_from_remote https://${KRILL_FQDN}/ta/ta.tal ${TAL_DIR}/ta.tal

my_log "Waiting for Krill TA certificate to become available via RSYNC"
my_retry 12 5 rsync -4 rsync://${KRILL_FQDN}/repo/ta/ta.cer >/dev/null

my_log "Launching Fort Validator"
cd ${DATA_DIR}
fort \
    --mode standalone \
    --output.roa output.roa \
    --tal ${TAL_DIR}/ta.tal \
    --local-repository cache "$@"

my_log "Dumping received ROAs"
cat output.roa