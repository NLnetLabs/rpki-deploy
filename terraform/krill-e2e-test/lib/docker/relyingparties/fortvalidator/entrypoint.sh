#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/fortvalidator
TAL_DIR=${DATA_DIR}/tals
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="Fort Validator setup for Krill"
source /opt/my_funcs.sh

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal ${RSYNC_BASE}

my_log "Querying Fort Validator version"
FORT_VER=$(fort -V)

my_log "Launching Fort Validator version ${FORT_VER}"
cd ${DATA_DIR}
/opt/entrypoint.sh \
    --mode standalone \
    --output.roa output.roa \
    --tal ${TAL_DIR}/ta.tal

my_log "Dumping received ROAs in the format expected by test_krill.sh"
echo -n 'TEST OUT: { "roas": ['
tail -n +2 output.roa | sed -e 's|^\(AS[0-9]\+\),\([^/]\+/[0-9]\+\),\([0-9]\+\)|{ "asn": "\1", "prefix": "\2", "maxLength": \3, "ta": "ta" }|' | paste -sd ',' - | sed -e 's|$|] }|'