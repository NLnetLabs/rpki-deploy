#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/rcynic
TAL_DIR=${DATA_DIR}/tals
RCYNIC_DB_PATH=${DATA_DIR}/rcynic
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="Rcynic setup for Krill"
source /opt/my_funcs.sh

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal

my_log "Launching Rcynic"
cd ${DATA_DIR}
rcynic \
    --config /opt/rcynic.conf \
    --unauthenticated ${DATA_DIR}/unauthenticated \
    --xml-file ${DATA_DIR}/validator.log.xml \
    --tals ${TAL_DIR} \
    --no-prefer-rsync

rcynic-text ${DATA_DIR}/validator.log.xml

# extract each Krill ROA DER object to a file named by its database row id
# then parse them using the Rcynica 'parse_roa' CLI tool, and then use sed to
# reformat the brief ROA details into the JSON format expected by test_krill.sh
my_log "Dumping received ROAs in the format expected by test_krill.sh"
TMPDIR=$(mktemp -d)
cd ${TMPDIR}
sqlite3 ${RCYNIC_DB_PATH} "SELECT writefile(id, der) FROM rcynicdb_rpkiobject WHERE uri LIKE '%krill%.roa'" >/dev/null
echo -n 'TEST OUT: { "roas": ['
print_roa --brief * | sed -e 's|^\([0-9]\+\) \([^/]\+\)/\([0-9]\+\)|{ "asn": "AS\1", "prefix": "\2/\3", "maxLength": \3, "ta": "ta" }|' | paste -sd ',' - | sed -e 's|$|] }|'
cd /
rm -Rf ${TMPDIR}