variable "domain" {}
variable "docker_compose_dir" {}
variable "hostname" {}
variable "docker_url" {}
variable "docker_cert_path" {}
variable "docker_ready" {}
variable "ssh_key_path" {}
variable "ssh_user" {}
variable "krill_version" {}
variable "krill_auth_token" {}
variable "krill_build_path" {}
variable "krill_fqdn" {}
variable "krill_use_ta" {}
variable "src_tal" {}
variable "run_tests" {
    type = bool
}
variable "docker_is_local" {
    type = bool
    default = false
}
variable "test_suite_path" {}
variable "tmp_dir" {}


resource "random_id" "tmp_dir" {
    prefix      = "/tmp/krill-"
    byte_length = 4
}

# locals {
#     tmp_dir = var.tmp_dir == null ? random_id.tmp_dir.hex : var.tmp_dir
# }

locals {
    docker_env_vars = {
        DOCKER_TLS_VERIFY   = var.docker_is_local ? null : "1"
        DOCKER_HOST         = var.docker_is_local ? null : var.docker_url
        DOCKER_CERT_PATH    = var.docker_is_local ? null : var.docker_cert_path
        DOCKER_MACHINE_NAME = var.docker_is_local ? null : var.hostname
    }
    app_vars = {
        KRILL_FQDN          = var.krill_fqdn
        KRILL_FQDN_FOR_TEST = var.docker_is_local ? "localhost" : var.krill_fqdn
        KRILL_USE_TA        = var.krill_use_ta
        KRILL_VERSION       = var.krill_version
        KRILL_AUTH_TOKEN    = var.krill_auth_token
        SRC_TAL             = var.src_tal
    }
    tmp_dir = var.tmp_dir == null ? random_id.tmp_dir.hex : var.tmp_dir
    tmp_dir_vars = {
        # VENVDIR             = "${random_id.tmp_dir.hex}/venv"
        # GENDIR              = "${random_id.tmp_dir.hex}/gen"
        # TMPDIR              = "${random_id.tmp_dir.hex}/"
        VENVDIR             = "${local.tmp_dir}/venv"
        GENDIR              = "${local.tmp_dir}/gen"
        TMPDIR              = "${local.tmp_dir}/"
    }
    test_suite_path         = var.test_suite_path != "" ? var.test_suite_path : join("/", [var.krill_build_path, "tests"])
}

resource "null_resource" "setup" {
    triggers = {
        docker_ready = "${var.docker_ready}"
    }

    provisioner "local-exec" {
        interpreter = ["/bin/bash", "-c"]
        environment = local.tmp_dir_vars
        working_dir = var.docker_compose_dir
        command = <<-EOT
            set -eu
            python3 -m venv $VENVDIR
            . $VENVDIR/bin/activate
            pip3 install "wheel==0.33.6"
            pip3 install -r ../../tests/requirements.txt

            cd $TMPDIR
            [ -d python-binding ] && rm -R python-binding
            git clone --branch master https://github.com/rtrlib/python-binding && \
                cd python-binding && \
                git checkout 2ade90ed && \
                pip3 install -r requirements.txt && \
                python3 setup.py build && \
                python3 setup.py install
        EOT
    }

    provisioner "local-exec" {
        interpreter = ["/bin/bash", "-c"]
        environment = local.tmp_dir_vars
        command = <<-EOT
            set -eu
            [ -d $GENDIR ] && rm -R $GENDIR
            mkdir -p $GENDIR

            # cp /home/ximon/src/krill/krill-master/doc/openapi.yaml $GENDIR
            if [ "${var.krill_build_path}" != "" ]; then
                cp ${var.krill_build_path}/doc/openapi.yaml $GENDIR/
                cp ${var.krill_build_path}/doc/openapi-pubd.yaml $GENDIR/
            else
                wget -O $GENDIR/openapi.yaml https://raw.githubusercontent.com/NLnetLabs/krill/${var.krill_version}/doc/openapi.yaml
                wget -O $GENDIR/openapi.yaml https://raw.githubusercontent.com/NLnetLabs/krill/${var.krill_version}/doc/openapi-pubd.yaml
            fi

            # An alternate approach to generating two client libraries, one for the CA daemon and one for the publisher
            # daemon, could be to use https://www.npmjs.com/package/openapi-merge-cli to merge the OpenAPI
            # specifications into one. We don't do that here at the moment because it's preferable to work the same way
            # that customers are expected to work, and as customers are advised to deploy the CA daemon and publisher
            # daemon separately they would need to speak to them separately using separate client libraries. Currently
            # in this test we still run a combined CA and publisher daemon, we might change that at some point.

            docker run --name openapi-generator --rm -v $GENDIR:/local \
                openapitools/openapi-generator-cli:v4.2.2 generate \
                -i /local/openapi.yaml \
                -g python \
                -o /local/outca \
                --skip-validate-spec \
                --additional-properties=packageName=krill_ca_api

            docker run --name openapi-generator --rm -v $GENDIR:/local \
                openapitools/openapi-generator-cli:v4.2.2 generate \
                -i /local/openapi-pubd.yaml \
                -g python \
                -o /local/outpub \
                --skip-validate-spec \
                --additional-properties=packageName=krill_pub_api

            . $VENVDIR/bin/activate

            cd $GENDIR
            pip3 install $GENDIR/outca/
            pip3 install $GENDIR/outpub/
        EOT
    }

    provisioner "local-exec" {
        when = destroy
        interpreter = ["/bin/bash", "-c"]
        environment = local.tmp_dir_vars
        working_dir = var.docker_compose_dir
        command = <<-EOT
            set -eu

            docker-compose kill
            docker-compose down -v

            echo "Cleaning up $TMPDIR"
            if [ -d $TMPDIR ]; then
                sudo rm -R $TMPDIR
            fi

            echo "Finished"
        EOT
    }
}

resource "null_resource" "run_tests" {
    count = var.run_tests ? 1 : 0

    triggers = {
        setup_done = "${null_resource.setup.id}"
    }

    provisioner "local-exec" {
        interpreter = ["/bin/bash", "-c"]
        working_dir = "${var.docker_compose_dir}/../../tests"

        # Copy external tests into our tests package so that the pytest
        # conftest.py works properly for tests defined in the external files.
        # There's probably a better way to do this...
        command = <<-EOT
            set -eu
            if [ "${local.test_suite_path}" != "" ]; then
                local_dir=$(basename ${local.test_suite_path})
                if [ -d $local_dir ]; then
                    rm -R $local_dir
                fi
                cp -a ${local.test_suite_path} .
            fi
        EOT
    }

    provisioner "local-exec" {
        when = destroy
        interpreter = ["/bin/bash", "-c"]
        working_dir = "${var.docker_compose_dir}/../../tests"
        command = <<-EOT
            set -eu
            if [ "${local.test_suite_path}" != "" ]; then
                local_dir=$(basename ${local.test_suite_path})
                if [ -d $local_dir ]; then
                    rm -R $local_dir
                fi
            fi
        EOT
    }

    provisioner "local-exec" {
        interpreter = ["/bin/bash", "-c"]
        environment = merge(local.docker_env_vars, local.app_vars, local.tmp_dir_vars)
        working_dir = var.docker_compose_dir

        # Invoke PyTest to run the Krill test suites.
        # 
        # Disable DeprecationWarning due to:
        #   python3.7/site-packages/yaml/constructor.py:126: DeprecationWarning:
        #   Using or importing the ABCs from 'collections' instead of from#
        #   'collections.abc' is deprecated since Python 3.3,and in 3.9 it
        #   will stop working.
        # PyYaml 5.2 fixes this but Docker-Compose requires PyYaml < 5.
        #
        # PYTHONDONTWRITEBYTECODE=1 disables creation of __pycache__
        # directories which make no sense for our use case (single run then
        # destroy everything).
        #
        # PyTest arguments used:
        #   -ra          - report at the end all tests that did not pass
        #   --tb         - use shorter tracebacks than the default
        #   --verbose    - enable pytest-progress plugin printing of the test
        #                  being executed.
        #   --log-cli-level=INFO - get real time Python INFO log level output
        #                  from the tests and frameworks rather than waiting until
        #                  all tests have finished to see anything.
        #   --html       - produce a nice HTML report to read at a glance instead
        #                  of wading through console/log output.
        #   --color      - make it easier to read console/log output.
        #                  note: install ansi2html otherwise colour codes don't
        #                  render correctly in the html report.
        #   --log-format - drop the source code location from the log format.
        #   -vv          - ensure that pytest assert diffs are logged in full.
        command = <<-EOT
            set -eu
            . $VENVDIR/bin/activate

            env | sort

            PYTHONWARNINGS=ignore::DeprecationWarning \
            PYTHONDONTWRITEBYTECODE=1 \
            pytest \
                -ra --tb=short \
                --verbose \
                --log-cli-level=INFO \
                --html=/tmp/report.html --self-contained-html \
                --color=yes \
                --log-format="%(levelname)-8s %(message)s" \
                -vv \
                ../../tests
        EOT
    }
}