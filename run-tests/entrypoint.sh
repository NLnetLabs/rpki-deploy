#!/bin/bash
set -euxo pipefail

TF_STATE_PATH=${GITHUB_WORKSPACE}/tf.state
REPORT_PATH=/tmp/report.html

export TF_VAR_krill_build_path="${GITHUB_WORKSPACE}/krill"
export TF_VAR_ssh_key_path="${INPUT_SSH-KEY-PATH}"
export TF_VAR_do_token="${INPUT_DO-TOKEN}"
export TF_VAR_size='s-4vcpu-8gb'
export TF_VAR_domain='krill.cloud'
export TF_VAR_tags='["rpki-deploy"]'
export TF_VAR_run_tests="false"

echo "::add-mask::${TF_VAR_do_token}"

cd "${TF_DIR}"

case ${INPUT_MODE} in
    run-tests)
        export TF_VAR_run_tests="true"
        # deliberate fall through
        ;&

    deploy)
        mkdir -p $HOME/.terraform.d/plugins/
        cp /opt/run-tests/terraform/plugins/terraform-provider-dockermachine $HOME/.terraform.d/plugins/
        terraform init -lock=false
        terraform apply -state ${TF_STATE_PATH} -lock=false -auto-approve
        [ -f ${REPORT_PATH} ] && mv ${REPORT_PATH} ${GITHUB_WORKSPACE}/
        ;;

    undeploy)
        terraform destroy -state ${TF_STATE_PATH} -auto-approve
        ;;

    *)
        echo "::error::Unrecognized mode '$MODE'."
        exit 1
        ;;
esac