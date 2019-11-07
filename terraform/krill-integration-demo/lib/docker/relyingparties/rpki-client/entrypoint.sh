#!/bin/bash
set -e -u -o pipefail

DATA_DIR=/var/cache/rpki-client
TAL_DIR=/tals-krill
TMP_FILE=$(mktemp)
mkdir -p ${DATA_DIR}
mkdir -p ${TAL_DIR}

export BANNER="rpki-client setup for Krill"
source /opt/my_funcs.sh

install_tal ${SRC_TAL} ${TAL_DIR}/ta.tal
# Add a line break at the end ... at least with the embedded Krill TAL it
# complains without this about "RFC 7730 section 2.1: failed to parse public key"
echo >> ${TAL_DIR}/ta.tal

my_log "Launching rpki-client"
cd /tmp
rpki-client \
    -e /usr/bin/rsync \
    -v ${TAL_DIR}/*.tal >${TMP_FILE}

# Extract and convert the bgpd.conf format data from the output
my_log "Dumping received ROAs in the format expected by test_krill.sh"
FIRST_LINE_OF_ROA_SET=$(fgrep -n roa-set ${TMP_FILE} | cut -d ':' -f 1)
LAST_LINE_OF_ROA_SET=$(grep -En '^}' ${TMP_FILE} | cut -d ':' -f 1)
M=$((FIRST_LINE_OF_ROA_SET+1))
N=$((LAST_LINE_OF_ROA_SET-1))

# Each line has the form:
#         109.104.64.0/19 maxlen 24 source-as 20738
echo -n 'TEST OUT: { "roas": ['
sed -n "$M,$N p" ${TMP_FILE} | sed -e 's|\s*\([^/]+\)/\([0-9]+\) maxlen \([0-9]+\) source-as \([0-9]+\)|{ "asn": "AS\4", "prefix": "\1/\2", "maxLength": \3, "ta": "ta" }|' | paste -sd ',' - | sed -e 's|$|] }|'
rm ${TMP_FILE}