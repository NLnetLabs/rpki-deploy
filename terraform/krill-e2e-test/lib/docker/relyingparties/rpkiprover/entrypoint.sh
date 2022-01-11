#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/rpki-prover
TAL_DIR=${DATA_DIR}/tals
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="rpki-prover setup for Krill"
source /opt/my_funcs.sh

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal

my_log "Launching rpki-prover"
cd ${DATA_DIR}
/opt/app/rpki-prover \
    --rpki-root-directory ${DATA_DIR}
    --strict-manifest-validation \
    --with-rtr \
    --rtr-address 0.0.0.0 \
    --rtr-port 8086 \
    --revalidation-interval 10