#!/bin/bash
set -euxo pipefail

export TF_VAR_krill_build_path="${GITHUB_WORKSPACE}/krill"
export TF_VAR_ssh_key_path="${INPUT_SSH-KEY-PATH}"
export TF_VAR_do_token="${INPUT_DO-TOKEN}"
export TF_VAR_size='s-4vcpu-8gb'
export TF_VAR_domain='krill.cloud'
export TF_VAR_tags='["rpki-deploy"]'
MODE="${INPUT_MODE}"

echo "::add-mask::${TF_VAR_do_token}"

cd /opt/run-tests

case $MODE in
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