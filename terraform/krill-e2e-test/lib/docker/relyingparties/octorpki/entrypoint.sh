#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/octorpki
TAL_DIR=${DATA_DIR}/tals
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="OctoRPKI setup for Krill"
source /opt/my_funcs.sh

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal --rewrite

my_log "Launching OctoRPKI"
cd / # needed by OctoRPKI to find file /private.pem
/octorpki -tal.name ta -tal.root ${TAL_DIR}/ta.tal -refresh 5s -output.sign=false