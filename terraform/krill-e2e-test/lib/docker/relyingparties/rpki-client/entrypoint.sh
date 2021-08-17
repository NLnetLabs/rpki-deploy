#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/tmp/rpki-client
TAL_DIR=/tmp/tals-krill
TMP_FILE=${DATA_DIR}/openbgpd
GORTR_OUTPUT_JSON_PATH=/var/www/html/output.json

mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}
chown _rpki-client. ${DATA_DIR}

export BANNER="rpki-client setup for Krill"
source /opt/my_funcs.sh

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal

# Add a line break at the end ... at least with the embedded Krill TAL it
# complains without this about "RFC 7730 section 2.1: failed to parse public key"
echo >> ${TAL_DIR}/ta.tal

my_log "Launching rpki-client"
rpki-client -e /usr/bin/rsync -t ${TAL_DIR}/*.tal ${DATA_DIR}

# Reformat and convert the bgpd.conf format data from the output into the JSON
# format expected by GoRTR, then host them in a webserver so that GoRTR can
# fetch them.
# See: https://github.com/cloudflare/gortr#data-sources

# Extract and convert the bgpd.conf format data from the output
FIRST_LINE_OF_ROA_SET=$(fgrep -n roa-set ${TMP_FILE} | cut -d ':' -f 1)
LAST_LINE_OF_ROA_SET=$(grep -En '^}' ${TMP_FILE} | cut -d ':' -f 1)
M=$((FIRST_LINE_OF_ROA_SET+1))
N=$((LAST_LINE_OF_ROA_SET-1))

# Each line has the form:
#         109.104.64.0/19 maxlen 24 source-as 20738
# Or:
#         109.104.64.0/19 source-as 20738
#
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

my_log "Transforming rpki-client output to GoRTR JSON format"

RE_WITH_MAXLEN='\s*\([^/]\+\)/\([0-9]\+\) maxlen \([0-9]\+\) source-as \([0-9]\+\)'
RE_WITHOUT_MAXLEN='\s*\([^/]\+\)/\([0-9]\+\) source-as \([0-9]\+\)'

echo -n '{ "roas": [' > ${GORTR_OUTPUT_JSON_PATH}
OLD_IFS=$IFS
IFS=$'\n'
for LINE in $(sed -n "$M,$N p" ${TMP_FILE}); do
    if echo ${LINE} | grep -qe ${RE_WITHOUT_MAXLEN}; then
        echo ${LINE} | sed -e 's|'${RE_WITHOUT_MAXLEN}'|{ "asn": "AS\3", "prefix": "\1/\2", "maxLength": \2, "ta": "ta" }|'
    elif echo ${LINE} | grep -qe ${RE_WITH_MAXLEN}; then
        echo ${LINE} | sed -e 's|'${RE_WITH_MAXLEN}'|{ "asn": "AS\4", "prefix": "\1/\2", "maxLength": \3, "ta": "ta" }|'
    else
        echo >&2 "ERROR: Cannot parse rpki-client roa: [ ${LINE} ]"
        rm ${TMP_FILE}
        exit 1
    fi
done | paste -sd ',' - | sed -e 's|$|] }|' >> ${GORTR_OUTPUT_JSON_PATH}
IFS=$OLD_IFS

my_log "Running Lighttpd to serve the JSON for GoRTR to fetch"
lighttpd -f /etc/lighttpd/lighttpd.conf -D