#!/bin/bash
set -Eeuo pipefail

export BANNER="$(basename $0):"

TMP_DIR=$(mktemp -d)
EXPECTED_ROAS_FILE="${TMP_DIR}/expected.roas"
KRILL_CONTAINER="krill"
KRILL_AUTH_TOKEN=$(docker logs ${KRILL_CONTAINER} 2>&1 | tac | grep -Eom 1 'token [a-z0-9-]+' | cut -d ' ' -f 2)

BAD_LOG_FILTER='(ERR|Bad|Fail|WARN)'
TEST_COUNT=0
PASS_COUNT=0
XFAIL_COUNT=0
TEST_FAILURES=()
TEST_XFAILURES=()

source ../../lib/docker/relyingparties/base/my_funcs.sh

cleanup() {
    rm -R ${TMP_DIR}
}

krillc() {
    # Run a Krillc command against the Dockerized Krill instance
    # Since we are communicating with the Docker daemon whether local or remote
    # the Krill server is running localhost from the perspective of the Docker
    # Daemon.
    docker exec \
        -e KRILL_CLI_SERVER=https://localhost:3000/ \
        -e KRILL_CLI_TOKEN=${KRILL_AUTH_TOKEN} \
        ${KRILL_CONTAINER} \
        krillc $@
}

log_test_failure() {
    echo -e >&2 "${COLOUR_RED}TEST FAIL:${COLOUR_DEFAULT} $@"
    TEST_FAILURES+=("$@")
}

log_expected_test_failure() {
    (( XFAIL_COUNT=XFAIL_COUNT + 1 ))
    echo -e >&2 "${COLOUR_LIGHT_YELLOW}TEST XFAIL:${COLOUR_DEFAULT} $@"
    TEST_XFAILURES+=("$@")
}

# Count the number of child CA ROAs reported by the Dockerized Krill instance:
test_krill_has_roas() {
    [ "$(krillc roas list --ca child --format json | jq '. | length')" -gt 0 ]
}

# Given ROAs in JSON format on STDIN filter, sort and compare them to a 
# previously defined set of expected ROAs.
test_compare_krill_roas_to_json() {
    jq -r '.roas[] | '$JQ_SELECT \
        | jq -r '"\(.prefix) => \(.asn | sub("AS";""))"' \
        | sort \
        | diff -u ${EXPECTED_ROAS_FILE} -
}

# Given the Docker container name of a Relying Party instance extract JSON ROAs
# from the Docker logs output for the container. The ROAs JSON should all be on
# one line and prefixed by 'TEST OUT: '. If more than one such line exists only
# the most recent is used.
test_compare_krill_roas_to_logs() {
    CONTAINER_NAME="$1"

    # Use tac to reverse the logs so that we can take the last (most recent)
    # match.
    TEST_OUT=$(docker logs ${CONTAINER_NAME} 2>&1 | tac | grep -Fm 1 'TEST OUT: ')
    RC=$? MYPS="${PIPESTATUS[*]}"

    # Handle the case where tac exits with code 141 due to receiving a SIGPIPE
    # signal when grep closes the pipe before reading all of tacs output,
    # because grep found the 1 match it was looking for.
    if [ ${RC} -ne 0 ]; then
        if [ ${RC} -eq 1 ]; then
            echo "ROAS not available yet"
        else
            echo "Unable to examine container logs"
        fi
        return ${RC}
    elif [ "${MYPS}" == "0 141 0" ]; then
        # We got ROAs, compare them to our expectations!
        echo ${TEST_OUT} | sed -e 's|TEST OUT: ||' \
            | test_compare_krill_roas_to_json
    else
        return $RC
    fi
}

# Given a URL at which an RP offers ROAs in JSON format download them and
# compare them to the set of expected ROAs defined earlier.
test_compare_krill_roas_to_url() {
    RP_NAME="$1" # unused, but logged by passing it to us which helps read the error logs
    URL="$2"
    wget -4 -qO- --header="Accept: text/json" $URL \
        | test_compare_krill_roas_to_json
}

# Increment total and passing test counters (the latter is increased only if
# the given command succeeds).
incr_test_counters() {
    (( TEST_COUNT=TEST_COUNT + 1 ))
    $@ && (( PASS_COUNT=PASS_COUNT + 1 )) && return 0
    return $?
}

# Delete temporary files on exit.
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Determine the ROAs we expected to see from the various Relying Parties:
# -----------------------------------------------------------------------------
if [ "$KRILL_USE_TA" == "true" ]; then
    # Ensure that Krill has ROAs in a child CA
    test_krill_has_roas || log_test_failure "Krill should have a child CA with at least one ROA."

    # Obtain the child CA ROAs
    krillc roas list --ca child --format json | jq -r '.[]' | sort >$EXPECTED_ROAS_FILE

    # We're only interested in ROAs for our TA
    JQ_SELECT='select(.ta=="ta")'
else
    # Not using the Krill testing embedded TA, instead using some other TA
    # Expect ROAs for the NLnet Labs network to be advertised by the TA and
    # seen by the RPs.
    cat << EOT >${EXPECTED_ROAS_FILE}
185.49.140.0/22 => 199664
185.49.140.0/22 => 8587
2a04:b900::/29 => 199664
2a04:b900::/29 => 8587
EOT

    # We're only interested in ROAs for NLnet Labs ASNs
    JQ_SELECT='select(.asn==["AS8587","AS199664"][])'
fi

# -----------------------------------------------------------------------------
# Fetch and compare ROAs from the various RPs against the expected ROAs:
# -----------------------------------------------------------------------------
for relyingparty in routinator octorpki fortvalidator rcynic rpkiclient; do
    if ! incr_test_counters my_retry 12 10 test_compare_krill_roas_to_logs ${relyingparty}; then
        log_test_failure "${relyingparty} ROAs do not match those of Krill"
    fi
done

if ! incr_test_counters my_retry 3 10 test_compare_krill_roas_to_url rpki-validator-3 http://${KRILL_FQDN}:8080/api/export.json; then
    log_expected_test_failure "rpki-validator-3 ROAs do not match those of Krill"
else
    log_test_failure "rpki-validator-3 unexpectedly passed the test???"
fi

# -----------------------------------------------------------------------------
# Output diagnostic logs:
# -----------------------------------------------------------------------------
echo "Dumping container logs that match error filter ${BAD_LOG_FILTER}"
docker-compose logs | grep -Eiw ${BAD_LOG_FILTER}

# -----------------------------------------------------------------------------
# Summarize the test results:
# -----------------------------------------------------------------------------
echo "TEST REPORT: ${PASS_COUNT}/${TEST_COUNT} tests passed with ${XFAIL_COUNT} expected failures."
echo "TEST FAILURES:"
for TEST_FAILURE in "${TEST_FAILURES[@]}"; do
    echo "  - ${TEST_FAILURE}"
done
echo "TEST XFAILURES:"
for TEST_XFAILURE in "${TEST_XFAILURES[@]}"; do
    echo "  - ${TEST_XFAILURE}"
done
echo "TEST END"

# THE END
[ $(( PASS_COUNT + XFAIL_COUNT )) -eq ${TEST_COUNT} ]
