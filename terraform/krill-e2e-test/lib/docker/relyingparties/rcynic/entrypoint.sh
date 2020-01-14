#!/bin/bash
# TODO: replace me with stock Ubuntu RPKI client packages using rpki-rtr per:
#   https://www.securerouting.net/sbs-guide/command-reference/#man-rpki-rtr
set -e -u -o pipefail

DATA_DIR=/tmp/rcynic
TAL_DIR=${DATA_DIR}/tals
RCYNIC_DB_PATH=${DATA_DIR}/rcynic
GORTR_OUTPUT_JSON_PATH=/var/www/html/output.json

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

# Extract each Krill ROA DER object to a file named by its database row id
# then parse them using the Rcynica 'parse_roa' CLI tool, and then use sed to
# reformat the brief ROA details into the JSON format expected by GoRTR, then
# host them in a webserver so that GoRTR can fetch them.
# See: https://github.com/cloudflare/gortr#data-sources

my_log "Extracting ROAs from the Rcynic database"
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

    my_log "Writing out binary ROA DER objects to disk"
    TMPDIR=$(mktemp -d)
    cd ${TMPDIR}
    sqlite3 ${RCYNIC_DB_PATH} "SELECT writefile(id, der) FROM ${DB_TABLE} WHERE ${DB_MATCH_CRITERIA}" >/dev/null

    my_log "Transforming binary ROA DER objects to GoRTR JSON format"

    # Example output of print_roa --brief
    #     22548 200.160.0.0/20-24
    #     11752 189.76.96.0/19-24
    #     11752 2001:12fe::/32-48
    #     22548 2001:12ff::/32-48
    #     ^^^^^ ^^^^^^^^^^^^^^ ^^
    #     asn   prefix         maxLength

    # To be transformed into GoRTR JSON format:
    #     {
    #       "roas": [
    #         {
    #           "prefix": "10.0.0.0/24",
    #           "maxLength": 24,
    #           "asn": "AS65001"
    #         },
    #         ...
    #       ]
    #     }

    roa_der_to_json() {
        print_roa --brief $1 | sed -e 's|^\([0-9]\+\) \([^/]\+\)/\([0-9]\+\)-\([0-9]\+\)\?|{ "asn": "AS\1", "prefix": "\2/\3", "maxLength": \4 }|'
    }

    roa_ders_to_json() {
        for DER_FILE in $*; do
            roa_der_to_json ${DER_FILE}
        done
    }

    echo -n '{ "roas": [' > ${GORTR_OUTPUT_JSON_PATH}
    roa_ders_to_json * | paste -sd ',' >> ${GORTR_OUTPUT_JSON_PATH}
    echo '] }' >> ${GORTR_OUTPUT_JSON_PATH}

    my_log "Running Lighttpd to serve the JSON for GoRTR to fetch"
    lighttpd -f /etc/lighttpd/lighttpd.conf -D
fi