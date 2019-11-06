#!/bin/bash
set -e -u -o pipefail

TAL_DIR=/var/lib/rpki-validator-3/preconfigured-tals/
mkdir -p ${TAL_DIR}

export BANNER="RIPE NCC RPKI Validator 3 setup for Krill"
source /opt/my_funcs.sh

install_tal_from_remote --no-rewrite https://${KRILL_FQDN}/ta/ta.tal ${TAL_DIR}/ta.tal

my_log "Waiting for Krill TA certificate to become available via RSYNC"
my_retry 12 5 rsync -4 rsync://${KRILL_FQDN}/repo/ta/ta.cer >/dev/null

my_log "Launching RIPE NCC RPKI Validator 3"
cd ${DATA_DIR}
sed -i -e 's/jvm.mem.maximum=.\+/jvm.mem.maximum=512m/g' /etc/rpki-validator-3/application-defaults.properties
/usr/bin/rpki-validator-3.sh

sleep infinity