#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/fortvalidator
TAL_DIR=${DATA_DIR}/tals
REPO_DIR=${DATA_DIR}/repo
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}
mkdir -p ${REPO_DIR}

export BANNER="Fort Validator setup for Krill"
source /opt/my_funcs.sh

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal

my_log "Querying Fort Validator version"
FORT_VER=$(fort -V)

my_log "Launching Fort Validator version ${FORT_VER}"
cd ${DATA_DIR}
/usr/local/bin/fort \
    --log.level info \
    --local-repository ${REPO_DIR} \
    --tal ${TAL_DIR}/ta.tal \
    --server.interval.refresh 5 \
    --server.interval.retry 5 \
    --server.interval.validation 60 # cannot be lower than this