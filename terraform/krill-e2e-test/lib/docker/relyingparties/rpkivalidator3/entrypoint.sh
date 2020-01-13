#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/rpki-validator-3
TAL_DIR=/var/lib/rpki-validator-3/preconfigured-tals
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="RIPE NCC RPKI Validator 3 setup for Krill"
source /opt/my_funcs.sh

my_log "Removing existing TALs"
rm ${TAL_DIR}/*.tal

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal --rewrite

my_log "Launching RIPE NCC RPKI Validator 3 RTR server"
cd /tmp/
nohup java -Dspring.config.location=file:/opt/rtrserver.properties -jar /opt/rpki-rtr-server.jar &
tail -F -n 9999 nohup.out &

my_log "Launching RIPE NCC RPKI Validator 3"
cd ${DATA_DIR}
sed -i -e 's/jvm.mem.maximum=.\+/jvm.mem.maximum=512m/g' $CONFIG_DIR/application-defaults.properties
cd /var/lib/rpki-validator-3
exec ./rpki-validator-3.sh
