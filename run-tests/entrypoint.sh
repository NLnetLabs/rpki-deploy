#!/bin/bash
set -euo pipefail

if [ $# -lt 3 ]; then
    echo "::error::Insufficient inputs."
    exit 1
fi

export TF_VAR_krill_build_path="${GITHUB_WORKSPACE}/krill"
export TF_VAR_ssh_key_path="$1"
export TF_VAR_do_token="$2"
export TF_VAR_size='s-4vcpu-8gb'
export TF_VAR_domain='krill.cloud'
export TF_VAR_tags='["rpki-deploy"]'
MODE="$3"

echo "::add-mask::${TF_VAR_do_token}"

case $MODE)
    deploy)
        export TF_VAR_run_tests="false"
        terraform init
        terraform apply -lock=false -auto-approve
        ;;

    run-tests)
        export TF_VAR_run_tests="true"
        terraform init
        terraform apply -lock=false -auto-approve
        mv /tmp/report.html ${GITHUB_WORKSPACE}/
        ;;

    undeploy)
        terraform destroy -auto-approve
        ;;

    *)
        echo "::error::Unrecognized mode '$MODE'."
        exit 1
        ;;
esac