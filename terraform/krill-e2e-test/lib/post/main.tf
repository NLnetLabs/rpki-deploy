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
variable "rsync_base" {}
variable "run_tests" {
    type = bool
}
variable "docker_is_local" {
    type = bool
    default = false
}


resource "random_id" "tmp_dir" {
    prefix      = "/tmp/krill-"
    byte_length = 4
}

locals {
    docker_env_vars = {
        DOCKER_TLS_VERIFY   = var.docker_is_local ? null : "1"
        DOCKER_HOST         = var.docker_is_local ? null : var.hostname
        DOCKER_CERT_PATH    = var.docker_is_local ? null : var.docker_cert_path
        DOCKER_MACHINE_NAME = var.docker_is_local ? null : var.hostname
    }
    app_vars = {
        KRILL_FQDN          = var.docker_is_local ? "localhost" : var.krill_fqdn
        KRILL_USE_TA        = var.krill_use_ta
        KRILL_VERSION       = var.krill_version
        KRILL_AUTH_TOKEN    = var.krill_auth_token
        SRC_TAL             = var.docker_is_local ? "https://localhost/ta/ta.tal" : var.src_tal
        RSYNC_BASE          = var.rsync_base
    }
    tmp_dir_vars = {
        VENVDIR             = "${random_id.tmp_dir.hex}/venv"
        GENDIR              = "${random_id.tmp_dir.hex}/gen"
        TMPDIR              = "${random_id.tmp_dir.hex}/"
    }
}

resource "null_resource" "setup_remote" {
    count = var.docker_is_local ? 0 : 1

    triggers = {
        docker_ready = "${var.docker_ready}"
    }
}

resource "null_resource" "setup_local" {
    count = var.docker_is_local ? 1 : 0

    provisioner "local-exec" {
        environment = local.tmp_dir_vars
        working_dir = var.docker_compose_dir
        command = <<-EOT
            python3 -m venv $VENVDIR
            . $VENVDIR/bin/activate
            pip3 install wheel
            pip3 install -r requirements.txt
        EOT
    }

    provisioner "local-exec" {
        environment = local.tmp_dir_vars
        command = <<-EOT
            mkdir -p $GENDIR

            # cp /home/ximon/src/krill/krill-master/doc/openapi.yaml $GENDIR
            if [ "${var.krill_build_path}" != "" ]; then
                cp ${var.krill_build_path}/doc/openapi.yaml $GENDIR/
            else
                wget -O $GENDIR/openapi.yaml https://raw.githubusercontent.com/NLnetLabs/krill/${var.krill_version}/doc/openapi.yaml
            fi

            docker run --rm -v $GENDIR:/local \
                openapitools/openapi-generator-cli generate \
                -i /local/openapi.yaml \
                -g python \
                -o /local/out \
                --skip-validate-spec \
                --additional-properties=packageName=krill_api

            . $VENVDIR/bin/activate

            cd $GENDIR
            pip3 install $GENDIR/out/
        EOT
    }

    provisioner "local-exec" {
        when = destroy
        environment = local.tmp_dir_vars
        command = <<-EOT
            echo "Cleaning up"
            if [ -d $TMPDIR ]; then
                rm -R $TMPDIR
            fi
            echo "Finished"
        EOT
    }
}

resource "null_resource" "run_tests" {
    count = var.run_tests ? 1 : 0

    triggers = {
        docker_ready = "${var.docker_ready}"
        setup_done = "${var.docker_is_local ? null_resource.setup_local[0].id : null_resource.setup_remote[0].id}"
    }

    provisioner "local-exec" {
        environment = merge(local.docker_env_vars, local.app_vars, local.tmp_dir_vars)
        working_dir = var.docker_compose_dir
        command = <<-EOT
            . $VENVDIR/bin/activate

            # Disable DeprecationWarning due to:
            #   python3.7/site-packages/yaml/constructor.py:126: DeprecationWarning:
            #   Using or importing the ABCs from 'collections' instead of from#
            #   'collections.abc' is deprecated since Python 3.3,and in 3.9 it
            #   will stop working.
            # PyYaml 5.2 fixes this but Docker-Compose requires PyYaml < 5.
            PYTHONWARNINGS=ignore::DeprecationWarning pytest -s
EOT
    }

    # provisioner "local-exec" {
    #     environment = local.env_vars
    #     interpreter = ["/bin/bash"]
    #     working_dir = "../scripts"
    #     command = "./configure_krill.sh"
    # }

    # provisioner "local-exec" {
    #     environment = local.env_vars
    #     interpreter = ["/bin/bash"]
    #     working_dir = "../lib/docker"
    #     command = "../../scripts/test_krill.sh"
    # }

    # provisioner "local-exec" {
    #     environment = local.env_vars
    #     interpreter = ["/bin/bash"]
    #     working_dir = "../lib/docker"
    #     command = "../../scripts/test_python_client.sh"
    # }
}
