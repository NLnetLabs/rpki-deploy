#!/bin/bash
set -e -u -o pipefail

TMP_DIR=$(mktemp -d)
KRILL_ROAS="${TMP_DIR}/krill.roas"
ROUTINATOR_ROAS="${TMP_DIR}/routinator.roas"
OCTORPKI_ROAS="${TMP_DIR}/octorpki.roas"
KRILL_CONTAINER="krill"
KRILL_AUTH_TOKEN=$(docker logs ${KRILL_CONTAINER} 2>&1 | tac | grep -Eom 1 'token [a-z0-9-]+' | cut -d ' ' -f 2)

BAD_LOG_FILTER='(ERR|Bad)'
TEST_COUNT=0
PASS_COUNT=0

cleanup() {
    rm -R ${TMP_DIR}
}

krillc() {
    docker exec -e KRILL_CLI_SERVER=https://localhost:3000/ -e KRILL_CLI_TOKEN=${KRILL_AUTH_TOKEN} ${KRILL_CONTAINER} krillc $@
}

my_retry() {
    MAX_TRIES=$1
    SLEEP_BETWEEN=$2
    shift 2
    TRIES=1
    while true; do
        echo "Attempt ${TRIES}/${MAX_TRIES}: " $@
        $@ && return 0
        (( TRIES=TRIES+1 ))
        [ ${TRIES} -le ${MAX_TRIES} ] || return 1
        sleep $SLEEP_BETWEEN
    done
}

test_fail() {
    echo -e >&2 "FAIL:" $@
}

test_krill_has_roas() {
    [ "$(krillc roas list --ca child --format json | jq '. | length')" -gt 0 ]
}

# pass json on STDIN
test_compare_krill_roas_to_json() {
    jq -r '.roas[] | select(.ta=="ta") |= "\(.prefix) => \(.asn | sub("AS";""))"' | sort | diff -u ${KRILL_ROAS} -
}

test_compare_krill_roas_to_logs() {
    CONTAINER_NAME="$1"
    docker logs ${CONTAINER_NAME} 2>&1 | tac | grep -Fm 1 'TEST OUT: ' | sed -e 's|TEST OUT: ||' | test_compare_krill_roas_to_json
}

test_compare_krill_roas_to_url() {
    URL="$1"
    wget -4 -qO- --header='Accept: application/json' $URL | test_compare_krill_roas_to_json
}

trap cleanup EXIT

# Ensure that Krill has ROAs in a child CA
test_krill_has_roas || test_fail "Krill doesn't appear to have the expected child ROAs."

krillc roas list --ca child --format json | jq -r '.[]' | sort >$KRILL_ROAS

for relyingparty in routinator octorpki fortvalidator rcynic; do
    (( TEST_COUNT=TEST_COUNT + 1 ))
    if ! my_retry 1 0 test_compare_krill_roas_to_logs ${relyingparty}; then
        test_fail "${relyingparty} ROAs do not match those of Krill"
    else
        (( PASS_COUNT=PASS_COUNT + 1 ))
    fi
done

my_retry 1 0 test_compare_krill_roas_to_url http://${KRILL_FQDN}:8080/api/export.json || test_fail "rpki-validator-3 ROAs do not match those of Krill"

echo "${PASS_COUNT}/${TEST_COUNT} tests passed."
echo "Dumping logs that match error filter ${BAD_LOG_FILTER} for container"
docker-compose logs | grep -E ${BAD_LOG_FILTER}

[ ${PASS_COUNT} -lt ${TEST_COUNT} ] && exit 1