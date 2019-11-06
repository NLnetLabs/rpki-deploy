#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/rpki-validator-3
TAL_DIR=/var/lib/rpki-validator-3/preconfigured-tals/
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="RIPE NCC RPKI Validator 3 setup for Krill"
source /opt/my_funcs.sh

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal --no-rewrite

my_log "Launching RIPE NCC RPKI Validator 3"
cd ${DATA_DIR}
sed -i -e 's/jvm.mem.maximum=256m/jvm.mem.maximum=512m/g' /etc/rpki-validator-3/application-defaults.properties
exec /opt/rpki-validator-3.sh