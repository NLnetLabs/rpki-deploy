#!/bin/bash
COLOUR_DEFAULT="\e[39m"
COLOUR_RED="\e[91m"
COLOUR_GREEN="\e[92m"
COLOUR_DARK_GRAY="\e[90m"
COLOUR_LIGHT_YELLOW="\e[93m"

DEF_FAIL_STR="${COLOUR_RED}FAIL${COLOUR_DEFAULT}"
DEF_OKAY_TO_FAIL_STR="${COLOUR_LIGHT_YELLOW}OKAY${COLOUR_DEFAULT}"
DEF_WARN_UNTIL_FAIL_STR="${COLOUR_DARK_GRAY}WARN${COLOUR_DEFAULT}"
DEF_OKAY_STR="${COLOUR_GREEN}OKAY${COLOUR_DEFAULT}"

# Usage: <LOG MESSAGE>...
my_log() {
    OPTS="${BANNER:-}: "
    [[ $# -ge 2 && "$1" == "--no-eol" ]] && OPTS="-n $OPTS" && shift 1
    [[ $# -ge 2 && "$1" == "--cont" ]] && OPTS="" && shift 1
    echo -e ${OPTS} "$@" >&2
}

my_log_cmd() {
    my_retry 1 0 $*
}

my_try_cmd() {
    my_retry --okay-to-fail 1 0 $*
}

# Usage: [--okay-to-fail|--retry-is-unexpected] <MAX_TRIES> <SLEEP_TIME_BETWEEN_TRIES> <COMMAND> [<ARG>...]
# Retry a command up to N times with a sleep of M seconds between retries
# If --okay-to-fail the result will not be logged as OKAY or FAIL nor will
# failure stdout/stderr be logged.
my_retry() {
    FAIL_STR="${DEF_WARN_UNTIL_FAIL_STR}"
    OKAY_TO_FAIL=0
    WARN_UNTIL_FAIL=1
    if [[ $# -ge 1 && "$1" == "--okay-to-fail" ]]; then
        shift 1
        OKAY_TO_FAIL=1
        FAIL_STR="${DEF_OKAY_TO_FAIL_STR}"
    elif [[ $# -ge 1 && "$1" == "--retry-is-unexpected" ]]; then
        shift 1
        WARN_UNTIL_FAIL=0
        FAIL_STR="${DEF_FAIL_STR}"
    fi
    MAX_TRIES=$1
    SLEEP_BETWEEN=$2
    shift 2
    CMD_TO_RUN=$@

    TRIES=0
    while true; do
        (( TRIES=TRIES+1 ))
        my_log --no-eol "Try ${TRIES}/${MAX_TRIES}: ${CMD_TO_RUN}: "

        # capture (and thus suppress) and merge STDOUT and STDERR
        SAVED_BASH_SET_FLAGS=$-
        [[ ${SAVED_BASH_SET_FLAGS} =~ e ]] && set +e
        OUTPUT=$(${CMD_TO_RUN} 2>&1)
        RC=$?
        set -${SAVED_BASH_SET_FLAGS}

        if [ ${RC} -eq 0 ]; then
            my_log --cont "${DEF_OKAY_STR}"
            echo "$OUTPUT"
            return 0
        else
            MSG="${FAIL_STR}"
            MSG="${MSG} (EXIT CODE ${RC})"
            if [ ${TRIES} -ge ${MAX_TRIES} ]; then
                [[ ${OKAY_TO_FAIL} -eq 0 && ${WARN_UNTIL_FAIL} -eq 1 ]] && MSG="${DEF_FAIL_STR}"
                my_log --cont "${MSG}"
                if [ ${OKAY_TO_FAIL} -eq 0 ]; then
                    my_log --no-eol "${COLOUR_DARK_GRAY}"
                    my_log --cont "${OUTPUT}" | sed -e "s|^|Failed command output: |"
                    my_log "${COLOUR_DEFAULT}"
                fi
                return ${RC}
            else
                my_log --cont "${MSG} (next try in ${SLEEP_BETWEEN} seconds)"
            fi
        fi

        sleep ${SLEEP_BETWEEN}
    done
}

# Usage: <SRC.TAL> </PATH/TO/DST.TAL>
# Where: <SRC_TAL> is either a TAL filename or a remote URI
install_tal() {
    if [[ "$1" == http* ]]; then
        my_log "Installing remote TAL $1 to $2"
        my_retry 12 5 wget --no-check-certificate -qO- $1 > $2
    else
        my_log "Installing local TAL /opt/$1 in $2"
        cp /opt/$1 $2
    fi

    # Wait for the ta.cer file to be copied into place by the tal_hack container running in the background
    RSYNC_URI=$(grep -F 'rsync://' $2 || echo "")
    if [ "${RSYNC_URI}" != "" ]; then
        my_log "Waiting for TA certificate to appear at ${RSYNC_URI}.."
        my_retry 12 5 rsync -4 ${RSYNC_URI} >/dev/null
    fi
}