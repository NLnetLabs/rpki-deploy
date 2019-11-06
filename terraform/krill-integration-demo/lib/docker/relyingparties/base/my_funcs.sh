#!/bin/bash
# Usage: <LOG MESSAGE>...
my_log() {
    echo -e "${BANNER:-my_funcs}: $@"
}

# Usage: <MAX_TRIES> <SLEEP_TIME_BETWEEN_TRIES> <COMMAND> [<ARG>...]
my_retry() {
    MAX_TRIES=$1
    SLEEP_BETWEEN=$2
    shift 2
    TRIES=1
    while true; do
        my_log "Attempt ${TRIES}/${MAX_TRIES}:  $@"
        $@ && return 0
        (( TRIES=TRIES+1 ))
        [ ${TRIES} -le ${MAX_TRIES} ] || return 1
        sleep $SLEEP_BETWEEN
    done
}

# Usage: [--no-rewrite] <TAL URL> <INSTALL PATH>
install_tal_from_remote() {
    REWRITE=1; [ "$1" == "--no-rewrite" ] && REWRITE=0 && shift
    TAL_URL="$1"
    INSTALL_PATH="$2"

    # Usage: <URL>
    # Outputs the TAL to stdout
    fetch() {
        wget --no-check-certificate -qO- $@
    }

    # Usage: <REWRITE=0|1>
    #   stdin  - TAL content to rewrite
    #   stdout - rewritten TAL content
    # When REWRITE is 1 the http(s):// URI will be rewritten to rsync://
    rewrite_https_tal_to_rsync() {
        if [ $1 -eq 1 ]; then
            sed -e 's|.\+://\([^/]\+\)/\(.\+\)|rsync://\1/repo/\2|'
        else
            cat
        fi
    }

    fetch_and_rewrite() {
        fetch $1 | rewrite_https_tal_to_rsync ${REWRITE} > $2
    }

    my_log "Installing remote TAL ${TAL_URL} to ${INSTALL_PATH}"
    my_retry 12 5 fetch_and_rewrite ${TAL_URL} ${INSTALL_PATH}
}

# Usage: <SRC.TAL> </PATH/TO/DST.TAL> [--no-rewrite]
# Where: <SRC_TAL> is either a TAL filename or a remote URI
#        --no-rewrite prevents rewriting of a HTTP(S) URI in the TAL as RSYNC
install_tal() {
    if [[ "$1" == http* ]]; then
        NO_REWRITE=
        [[ $# -eq 3 && "$3" == "--no-rewrite" ]] && NO_REWRITE="$3"
        install_tal_from_remote $NO_REWRITE $1 $2
    else
        cp /opt/$1 $2
    fi

    RSYNC_URI=$(grep -F 'rsync://' $2 || echo "")
    if [ "${RSYNC_URI}" != "" ]; then
        my_log "Waiting for TA certificate to appear at ${RSYNC_URI}.."
        my_retry 12 5 rsync -4 ${RSYNC_URI} >/dev/null
    fi
}