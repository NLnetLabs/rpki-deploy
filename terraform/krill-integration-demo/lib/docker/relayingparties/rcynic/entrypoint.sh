#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/rcynic
TAL_DIR=${DATA_DIR}/tals
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="Rcynic setup for Krill"
source /opt/my_funcs.sh

install_tal_from_remote https://${KRILL_FQDN}/ta/ta.tal ${TAL_DIR}/ta.tal

my_log "Waiting for Krill TA certificate to become available via RSYNC"
my_retry 12 5 rsync -4 rsync://${KRILL_FQDN}/repo/ta/ta.cer >/dev/null

my_log "Launching Rcynic"
cd ${DATA_DIR}
rcynic \
    --config /opt/rcynic.conf \
    --unauthenticated ${DATA_DIR}/unauthenticated \
    --xml-file ${DATA_DIR}/validator.log.xml \
    --tals ${TAL_DIR} \
    --no-prefer-rsync

my_log "Dumping received ROAs"
my_log >&2 "NOT IMPLEMENTED YET" 
rcynic-text ${DATA_DIR}/validator.log.xml