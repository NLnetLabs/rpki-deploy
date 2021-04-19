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
    --strict \
    --rrdp-root-cert=/opt/rootCA.crt \
    server \
    --rtr 0.0.0.0:3323 --http 0.0.0.0:9556 \
    --refresh 10