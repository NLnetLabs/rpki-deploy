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

DB_TABLE="rcynicdb_rpkiobject"
DB_URI_FIELD="uri"
DB_ROA_PATTERN="%.roa"
DB_INCLUDE_SUB_QUERY="${DB_URI_FIELD} LIKE '${DB_ROA_PATTERN}'"
DB_EXCLUDE_SUB_QUERY=""
if [ "${KRILL_USE_TA}" != "true" ]; then
    # Exclude ROAs attributed to the "parent"
    # I'm sure this is not really the right way to do this but it will do for
    # now.
    CER_URI=$(grep -F .cer ${TAL_DIR}/ta.tal)
    EXT_DOM=$(echo $CER_URI | cut -d '/' -f 3)
    DB_EXCLUDE_SUB_QUERY=" AND ${DB_URI_FIELD} NOT LIKE '%${EXT_DOM}%'"
fi

DB_MATCH_CRITERIA="${DB_INCLUDE_SUB_QUERY}${DB_EXCLUDE_SUB_QUERY}"
DB_SELECT_COUNT="SELECT count(*) FROM ${DB_TABLE} WHERE ${DB_MATCH_CRITERIA}"
ROA_COUNT=$(sqlite3 ${RCYNIC_DB_PATH} "${DB_SELECT_COUNT}")
if [ ${ROA_COUNT} -le 0 ]; then
    my_log "ERROR: Zero ROAs found in Rcynic DB with query: ${DB_SELECT_COUNT}"
    echo 'TEST OUT: { "roas": []}'
else
    my_log "Found ${ROA_COUNT} ROAs in Rcynic DB with query: ${DB_SELECT_COUNT}"
    TMPDIR=$(mktemp -d)
    cd ${TMPDIR}
    sqlite3 ${RCYNIC_DB_PATH} "SELECT writefile(id, der) FROM ${DB_TABLE} WHERE ${DB_MATCH_CRITERIA}" >/dev/null
    echo -n 'TEST OUT: { "roas": ['
    print_roa --brief * | sed -e 's|^\([0-9]\+\) \([^/]\+\)/\([0-9]\+\)\(-[0-9]\+\)\?|{ "asn": "AS\1", "prefix": "\2/\3", "maxLength": \3, "ta": "ta" }|' | paste -sd ',' - | sed -e 's|$|] }|'
    cd /
    #rm -Rf ${TMPDIR}
fi
