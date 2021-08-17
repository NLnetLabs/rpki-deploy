# Krill E2E Test Framework

## Contents

<!-- @import "[TOC]" {cmd="toc" depthFrom=1 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [Krill E2E Test Framework](#krill-e2e-test-framework)
  - [Contents](#contents)
  - [Introduction](#introduction)
    - [Abbreviations used in this document](#abbreviations-used-in-this-document)
    - [What is tested?](#what-is-tested)
    - [Why is it based on Docker in the cloud?](#why-is-it-based-on-docker-in-the-cloud)
  - [Integration with Krill @ GitHub](#integration-with-krill-github)
    - [Using GitHub Actions](#using-github-actions)
    - [Protecting secrets](#protecting-secrets)
  - [Architecture](#architecture)
    - [Directory layout](#directory-layout)
    - [Cloud topology](#cloud-topology)
    - [Docker topology](#docker-topology)
    - [Special configuration](#special-configuration)
    - [Docker images for 3rd party RP tools](#docker-images-for-3rd-party-rp-tools)
  - [Running](#running)
    - [Requirements](#requirements)
    - [Prepare (optional)](#prepare-optional)
    - [Prepare to run in the cloud](#prepare-to-run-in-the-cloud)
      - [Prepare for Digital Ocean](#prepare-for-digital-ocean)
      - [Prepare for Amazon Web Services](#prepare-for-amazon-web-services)
    - [Fetch the test suite](#fetch-the-test-suite)
    - [Deploy](#deploy)
      - [Container startup sequence](#container-startup-sequence)
  - [Diagnosing issues](#diagnosing-issues)

<!-- /code_chunk_output -->

----

## Introduction

This directory contains a prototype framework for testing [Krill](https://www.nlnetlabs.nl/projects/rpki/krill/) (a free, open source Resource Public Key Infrastructure (RPKI) daemon by [NLnet Labs](https://nlnetlabs.nl/)) end-to-end (E2E) in combination with various [Relying Party implementations](https://rpki.readthedocs.io/en/latest/tools.html#relying-party-software).

This framework uses off-the-shelf containers from Docker Hub deployed locally or in the cloud to:

* Deploy Krill behind an industry standard HTTP proxy (nginx) as advised by the [official Krill documentation](https://rpki.readthedocs.io/en/latest/krill/running.html#proxy-and-https).
* Integrate with a co-deployed [rsync server](https://hub.docker.com/r/vimagick/rsyncd) for clients that do not support the RRDP protocol.
* Serve various Relying Party implementations, such as NLnet Labs [Routinator](https://www.nlnetlabs.nl/projects/rpki/routinator/), with data from Krill.

In this environment we can then manipulate Krill and verify that the desired changes are observed at the Relying Parties (RPs) connected to it, thereby testing Krill "end-to-end" (E2E).

This framework prototype began life as a deployment demo of various NLnet Labs and 3rd party RPKI related components. Its architecture is subject to review and is likely to evolve in step with the needs of the Krill project.

----

_**WARNING!** This framework may create resources in the [Digital Ocean](https://www.digitalocean.com/) or [Amazon Web Services](https://aws.amazon.com/) public cloud. These resources are **NOT free**, they will incur a small cost. Please ensure that you have **permission** from your cloud account owner to incur costs on the account before using this framework!_

----

### Abbreviations used in this document

- AWS - [Amazon Web Services](https://aws.amazon.com/)
- CA - Certificate Authority
- DO - [Digital Ocean](https://www.digitalocean.com/)
- E2E - End-to-end
- GHA - [GitHub Actions](https://github.com/features/actions)
- ROA - [Route Origin Authorisation](https://rpki.readthedocs.io/en/latest/rpki/securing-bgp.html#route-origin-validation)
- RP - [Relying Party](https://rpki.readthedocs.io/en/latest/tools.html#relying-party-software)
- TA - [Trust Anchor](https://rpki.readthedocs.io/en/latest/krill/running.html#embedded-trust-anchor)
- VM - Virtual Machine, e.g. a [DO Droplet](https://www.digitalocean.com/products/droplets/) or [AWS EC2](https://aws.amazon.com/ec2/) Instance.

### What is tested?

Currently the tests are limited to a proof of concept in which Krill is configured as both a CA and TA and then we test that ROAs output by various RP tools connected to Krill are the same as those reported by Krill itself. The intention is to build out a set of useful end-to-end tests using this framework as a base.

View [E2E Test Framework logs for recent Krill commits](https://github.com/nlnetlabs/krill/actions).

For details on which RPs are tested against Krill see the [RP details](#rp-details) section below.

### Why is it based on Docker in the cloud?

The combination of [Terraform](https://www.terraform.io/), [Docker Machine](https://docs.docker.com/machine/overview/), [Docker Compose](https://docs.docker.com/compose/) and [Docker](https://www.docker.com/) supports many different deployment targets while minimizing the maintenance effort per component. The templates have been deliberately structured such that the cloud and Docker parts are separated. Deployment can be done with Docker locally or with Docker in the cloud, potentially also to targets such as [GitHub Actions with Docker Compose](https://github.blog/2019-08-08-github-actions-now-supports-ci-cd/#fast-ci-cd-for-any-os-any-language-and-any-cloud) or Kubernetes (e.g. on [Digital Ocean](https://www.digitalocean.com/products/kubernetes/) or [AWS](https://aws.amazon.com/kubernetes/)). Only the infrastructure parts such as the VM, DNS and cloud firewall, are cloud specific, the Docker core can run anywhere. With this structure it should be relatively easily to add support for other Terraform providers too.

The beauty of Terraform is the huge number of deployment targets that it supports, its declarative plain text templates which can be version controlled and easily diffed, the "one click" deployment and the readable preview of what will be deployed.
 
The beauty of Docker is the ability to use the same core to run on those many different deployment targets, the flexibility it gives you to compose the deployment such that containers share a host or have their own hosts or something in the middle and the collection of applications that are already available as Docker containers (e.g. nginx, rsyncd, Routinator, RPKI Validator 3, etc).

To avoid the need for a public IP address and associated DNS A/AAAA records in order to obtain a real HTTPS certificate (e.g. from Lets Encrypt) for NGINX such that Krill clients can trust the HTTPS certificate presented to them, we instead use our own Certificate Authority to issue a TLS certificate and install the CA root cert in the certificate trust store of each Docker container.  We can optionally run in a cloud VM thereby supporting the potential to scale beyond the capabilities of a CI only platform such as GitHub Actions (where for example the deployment environment is currently limited to [2-core with 7 GiB RAM](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/virtual-environments-for-github-hosted-runners#supported-runners-and-hardware-resources)) which could be useful given that some RP tools require a lot of memory (e.g. [RIPE NCC RPKI Validator 3](https://github.com/RIPE-NCC/rpki-validator-3) requires a minimum of 1 GiB RAM by default just for itself, and larger numbers of certificate authorities and ROAs will increase the resources required by Krill).

Currently all clients are deployed as containers on the same host VM as Krill itself but the architecture supports splitting the containers out across multiple hosts. However some changes would be required to actually deploy using Docker Swarm or Kubernetes (for example) for such a scenario.

## Integration with Krill @ GitHub

### Using GitHub Actions

The [Krill GitHub repository](https://github.com/NLnetLabs/krill) contains a [GitHub Actions Workflow](https://github.com/NLnetLabs/krill/blob/master/.github/workflows/main.yml) definition that clones this E2E framework repository and uses it to test Krill with the most recent commit to master or commits to a Pull Request.

### Protecting secrets

The Krill GitHub repository uses [GitHub Secrets](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/creating-and-using-encrypted-secrets) to:
- Protect the Digital Ocean API token or AWS credentials used to deploy in the public cloud.
- Protect the SSH key decryption passphrase for the key that grants remote shell access to the deployed cloud VM.

## Architecture

### Directory layout

```
$ tree -d                                    Type
==============================================================
.
└── terraform
    ├── krill-e2e-test
    │   ├── lib
    │   │   ├── docker
    │   │   │   ├── krill                    Docker image
    │   │   │   ├── nginx                    Docker image
    │   │   │   ├── relyingparties
    │   │   │   │   ├── base                 Docker image
    │   │   │   │   ├── fortvalidator        Docker image
    │   │   │   │   ├── octorpki             Docker image
    │   │   │   │   ├── rcynic               Docker image
    │   │   │   │   ├── routinator           Docker image
    │   │   │   │   ├── rpki-client          Docker image
    │   │   │   │   └── rpkivalidator3       Docker image
    │   │   │   └── rsyncd                   Docker image
    │   │   ├── infra
    │   │   │   ├── aws                      Terraform module
    │   │   │   └── do                       Terraform module
    │   │   ├── post                         Terraform module
    │   │   └── pre                          Terraform module
    │   ├── run_on_aws                       Terraform module
    │   ├── run_on_do                        Terraform module
    │   ├── run_on_localhost                 Terraform module
    │   └── scripts                          Bash scripts
    └── plugins                              Terraform plugins
```

Platform specific artifacts:

| Directory or File-                  | Platform | Description |
| ----------------------------------- | -------- | ----------- |
| `plugins`                           | GHA      | Contains a copy of the Docker Machine x64 Terraform plugin, used to accelerate the GHA run. |
| `krill-e2e-test/decrypt-ssh-key.sh` | GHA      | Script to decrypt `ssh_key.gpg`. |
| `krill-e2e-test/ssh_key.gpg`        | GHA      | SSH key used to SSH into the deployed VM. |
| `krill-e2e-test/run_on_aws/`        | AWS      | Starting point for deploying on AWS. |
| `krill-e2e-test/run_on_do/`         | DO       | Starting point for deploying on DO. |
| `krill-e2e-test/lib/infra/aws/`     | AWS      | Terraform module for AWS infrastructure deployment. |
| `krill-e2e-test/lib/infra/do/ `     | DO       | Terraform module for DO infrastructure deployment. |
| `krill-e2e-test/lib/infra/do/ `     | DO       | Terraform module for DO infrastructure deployment. |

Platform independent artifacts:

| Directory or File-           | Description |
| ---------------------------- | ----------- |
| `krill-e2e-test/scripts/`    | Bash scripts to configure and test Krill. |
| `krill-e2e-test/lib/docker/` | E2E Docker image definitions. |
| `krill-e2e-test/lib/pre`     | Terraform module run before deployment. |
| `krill-e2e-test/lib/post`    | Terraform module run after deployment, e.g. the `/scripts/` are invoked from here. |

### Cloud topology

The diagram below describes the Digital Ocean topology and how Terraform creates it:

In the case of Amazon Web Services the Droplet is an EC2 Compute Instance and the DO DNS is AWS Route53.

When running locally only the Host block is required.

```
+- Digital Ocean Public Cloud ----------------------------------+
|                                                               |
|    +-DO DNS-+               +-DO Firewall-------------+       |
|    | A      |               |                         |       |
|    | AAAA   |               |    +-DO Droplet----+    |       |
|    +--------+               |    |    dockerd    |<---|---+   |
|                             |    +----^--------^-+    |   |   |
|                             |         |        |      |   |   |
+-----------------------+     +---------|--------|------+   |   |
|   Digital Ocean API   |               |        |          |   |
+---------^-------------+---------------|--------|----------|---+
          |                             |        |          |
        create                        docker   docker    install
        droplet,                      compose  volume    docker
        dns & fw                      up       create    via ssh
          |                             |        |          |  
         (1)                           (4)      (3)        (2)
          |    +- Host (e.g. GHA) ------|---+    |          |
          |    |      Docker (Compose)      |    |          |
          |    |----------------------------+    |          |
          |    |   Local-Exec Provisioner   |----+          |
          |    +----------------------------+               |
          |    |   Docker Machine Provider  |---------------+
          |    +----------------------------+
          +----|   Digital Ocean Provider   |
               +----------------------------+
               |     HashiCorp Terraform    |
               +----------------------------+
```

### Docker topology

In the diagram below we "zoom in" to the DO Droplet in the diagram above:
```
+-DO Droplet------------------------------------------------------------------------+
| Ubuntu 16.04 LTS                                                                  |
|                                           +-V-----+  +-V---------------+          |
|                                           | krill |  |    rsync data   |          |
|                                           +---|m|-+  +-|m|---------|m|-+          |
|                                               |o|      |o|         |o|            |
|    +-S:172.18.0.0/16--------------------------|u|------|u|---------|u|-------+    |
|    |                                          |n|      |n|         |n|       |    |
|    |    +-C--+ +-C--+    +-C-------+      +-C-|t|------|t|-+   +-C-|t|--+    |    |
|    |    | RP | | RP |    |  nginx  |--+   |      krill     |   | rsyncd |    |    |
|    |    +----+ +-|--+    +--|---|--+  |   +--------|-------+   +---|----+    |    |
|    |             |          |   |     +----------> O 3000          |         |    |
|    +-------------|----------|---|----------------------------------|---------+    |
+---------+        |          |   |                                  |              |
| dockerd |        |          |   |                                  |              |
+----|-------------|----------|---|----------------------------------|--------------+
     |             |          |   |                                  |
2376 O        NNNN O    80 O   O 443                              O 873
     
     ^ Docker/TLS  ^ RTR          ^ HTTPS/RRDP                       ^ RSYNC
     |             |              |                                  |
     +-----------+ +              +----------------+-----------------+
     |           | |                               |
 Terraform    Python Test                    Krill clients
    CLI         Suite                        e.g. the RPs
```

**Key:**
- C: Docker container
- V: Docker persistent named volume
- S: Docker private subnet
- mount: Docker volume mounted inside a container
- NNN: TCP/IP port numbers, e.g.:
  - 323:  Routinator RTR port, not used in this demo
  - 3000: Krill HTTPS/RRDP port, only exposed to nginx
  
### Special configuration

- The krill container is configured via environment variables to know its public FQDN and with `use_ta = true` which causes it to create an embedded Trust Anchor (TA).
- The RP container images are extended via `Dockerfile`s to download and install the Krill Trust Anchor Locator (TAL) file before starting the RP tool.
- The nginx container image is extended via a `Dockerfile` with a config file directing nginx to proxy HTTPS connections via the internal Docker private network to port 3000 on the krill container.
- The rsyncd container image is extended via a `Dockerfile` with a config file telling rsyncd how to share the files mounted into the container from the krill rsync data Docker volume.
- The Krill and rsyncd containers both mount the same Docker volume with Krill writing to it and rsyncd reading from it.
- The custom CA root certificate is added into the operating system certificate trust store of each RP container.

### Docker images for 3rd party RP tools

Not all 3rd party RP tools offer Docker images. For those that don't I have packaged them myself into Docker images. These images work well enough for this use case and hopefully can be made generally useful, but for now they are a limited work in progress. See https://github.com/ximon18/relyingpartydockerimages for more information.

## Running

### Requirements

This framework requires:
- The [HashiCorp Terraform](https://www.terraform.io/downloads.html) command line tool (tested with v0.12.19) **(NOTE: does NOT work with Terraform >= v0.13.x due to `Error: Invalid reference from destroy provisioner`)**
- The [Docker](https://docs.docker.com/install/#supported-platforms) command client (tested with v18.09.5).
- The [Docker Compose](https://docs.docker.com/compose/install/) (tested with v1.24.1) command line tool.
- RTRLib (tested with 0.6.3 and 0.7.0), preferably built with NDEBUG defined to disable noisy log output.

When running in the cloud you also need:
- A Digital Ocean or Amazon Web Services account.
- A [Digital Ocean API token](https://cloud.digitalocean.com/account/api/tokens) or AWS access key and secret access key.
- A DNS domain managed by Digital Ocean or Amazon Web Services.

### Prepare (optional)

To install RTRLib with noisy log output disabled:

```bash
$ git clone https://github.com/rtrlib/rtrlib.git
$ cd rtrlib
$ git checkout v0.7.0
$ cmake -D CMAKE_C_FLAGS='-DNDEBUG' -D CMAKE_BUILD_TYPE=Release -D RTRLIB_TRANSPORT_SSH=No .
$ make
$ sudo make install
$ sudo ldconfig
```

### Prepare to run in the cloud

_**Tip:** This step can be skipped if running locally._

To run the framework you will need the required tools, a copy of the templates and scripts, an existing parent DNS domain that you have control of, and an SSH key pair.

> _**Note:** `some.domain` should already be managed by Digital Ocean or AWS._
> _**Note:** The SSH key public half should already be registered with Digital Ocean._

```bash
$ ssh-keygen -m PEM -t rsa -E md5 -f /tmp/demo-ssh-key -N ""
$ git clone https://github.com/nlnetlabs/rpki-deploy.git
$ export TF_VAR_ssh_key_path=/tmp/demo-ssh-key
$ export TF_VAR_hostname=somehostname
$ export TF_VAR_domain=some.domain
```

If you want to change any of the default values in `variables.tf`, e.g. deployment region, droplet size, tags, [read this page](https://learn.hashicorp.com/terraform/getting-started/variables.html) to learn how to override them.

> _**Note:** In the case of Krill @ GitHub the GHA workflow performs a shallow Git clone of this entire repository to obtain a copy of these files and uses a GitHub Secret to decrypt the `ssh_key.gpg` file stored in this directory, and a second GitHub Secret stores the required DO API token. The [Marrocchino Terraform GitHub v2 Action](https://github.com/marocchino/setup-terraform) action is used to install the Terraform CLI. The [official Terraform GitHub v2 Action](https://github.com/hashicorp/terraform-github-actions) is NOT used because it does not support `terraform destroy`._

Possible errors and resolutions:
- `Error: Unsupported attribute` `public_key_fingerprint_md5`: recreate the SSH key using `-E md5`.
- `Error: failed to decode PEM block containing private key of type "OPENSSH PRIVATE KEY"`: recreate the SSH key using `-m PEM -t rsa`.
- `Error: Error creating droplet: POST https://api.digitalocean.com/v2/droplets: 422 xx:xx:...:xx:xx are invalid key identifiers for Droplet creation.`: paste the SSH public key into the Digital Ocean Account -> Security -> SSH keys page.

#### Prepare for Digital Ocean

```bash
$ cd rpki-deploy/terraform/krill-integration-demo/demo_on_do
$ export TF_VAR_do_token=xxxxxx
```

> _**Note:** You must copy the contents of `/tmp/demo-ssh-key.pub` into the Digital Ocean portal (see Account -> Security -> SSH Keys -> Add SSH Key) before you can deploy using this SSH key._

#### Prepare for Amazon Web Services

```bash
$ cd rpki-deploy/terraform/krill-integration-demo/demo_on_aws
$ export AWS_ACCESS_KEY=xxx
$ export AWS_SECRET_ACCESS_KEY=xxx
```

### Fetch the test suite

The actual tests to run are not defined in the framework repository but instead live in the Krill repository so that they can be updated in sync with changes to Krill. Before running the tests you must first fetch them from Git:

```bash
$ cd /tmp
$ git clone https://github.com/nlnetlabs/krill.git
```

### Deploy

`init` installs any Terraform plugins required by the templates.
`apply` explains what will be created then, if you approve, executes the template.

```bash
$ cd terraform/krill-e2e-test/run_on_XXX (e.g. aws, do or localhost)
$ terraform init
$ terraform apply -var test_suite_path=/tmp/krill/tests/e2e
```

**Optional:** You may also pass one (not both) of the following:
  - `-var krill_build_path=/tmp/krill` - this will build Krill from sources
  - `-var krill_version=vX.Y.Z` - this will install a specific Krill Docker image

Terraform will:
1. _(if not run_on_localhost)_ Create a Digital Ocean droplet or AWS E2C2 instance.
2. _(if not run_on_localhost)_ Create A and AAAA DNS records pointing to the droplet/instance.
3. _(if not run_on_localhost)_ Install Docker on the droplet and secure the Docker daemon with TLS authentication.
4. Create "external" persistent volumes for Lets Encrypt certificates and for Krill RSYNC data.
5. Invoke Docker Compose to build images, and deploy the private network and containers locally or on the droplet.
6. Setup a Python virtual environment, install `rtrlib/python-binding` into it and any Krill E2E test Python dependencies (see `requirements.txt`).
7. Downloads `doc/openapi.yaml` from GitHub for the Krill version under test and invoke the OpenAPI generator to generate a Python client library in the Python venv.
8. Copies the Krill `tests/e2e` test suite directory into `krill-e2e-test/tests/e2e`.
9. Runs [pytest](https://docs.pytest.org/en/latest/) in the `krill-e2e-test/tests` directory.

> _**Tip:** If you see `WARNING  Host is already in use by another container` in the output it may mean that something is already bound to port 443. The test currently always tries to bind to the host interface, even when running locally even though it is not needed locally. If you have something else running on port 443, try stopping it and re-running apply._

> _**Tip:** If you see unexpected errors it might be worth re-running apply while running `tail -F /var/log/syslog | grep -i docker` in another terminal. For example the above port 443 issue shows up in the Docker syslog entries as `Failed to allocate and map port 443-443: Error starting userland proxy: listen tcp 0.0.0.0:443: bind: address already in use`._

> _**Note:** Even though off-the-shelf Docker images are used for the RPs, images still need to be built for them because some tooling is installed to fetch, process and install the TAL and to parse and convert the ROA output into a "standard" format expected by the test suite. Additionally the Krill image has to be built and preferably without having to build the entire Rust application and dependencies from scratch. Currently a "hack" is used to accelerate the Krill image build whereby a not-too-old copy of the Krill Docker image `builder` stage is used as the base for the new image, thereby leveraging the Cargo build cache that already exists in the (very large) image._

#### Container startup sequence

What are the containers doing? The descriptions below are based on publication via RRDP. Alternatively Krill can also [publish via rsync](https://rpki.readthedocs.io/en/latest/rpki/using-rpki-data.html?highlight=rsync#fetching-and-verifying).

```
Operator    Docker    Docker Hub    NGINX    Krill    Relying Party
   |
   |---Up---->|
   |          |---Pull--->|
   |          |<--Image---|
   |          |
   |          |---Create & run------->|------->|--------->|
   |                                  |
   |                                  |        | Make TA
   |                                  |        |
   |                                  |        |<-Get TAL-|
   |                                  |        |---TAL--->| Install TAL
   |                                  |        |          |
   |                                  |        |          | Start RP
   |                                  |        |<-Get CER-|
   |                                  |        |---CER--->| Verify CER
   .                                  .        .          .
   .                                  .        .          .
   .                                  .        .          .
   |---Run test suite---------------->|        |          |
   |                                  | Proxy->|          |
   |                                           | Publish  |
   |                                           |          |
   |                                           |<--Fetch--|
   |                                           |-via RRDP>| Parse & Verify
   |                                                      
   | ... (fetch ROAs from the RPs via RTR and compare them to those fetched from Krill)
   ```

1. Docker:
   a. Pulls base images for the containers.
   b. Builds the configuration layers for the RPs, Krill, nginx and rsyncd containers.
   c. Creates the containers.

2. On the Nginx container:
   a. Proxy requests to port 443 via the private network to port 3000 of the Krill container.

3. On the Krill container:
   a. `use_ta=true` causes Krill to setup a test Trust Anchor.

3. On the RP containers:
   a. A custom `entrypoint.sh` script fetches the Trust Anchor Locator file from Krill at https://some.domain/ta/ta.tal and writes it to a directory that the RP can read it from.
   b. Start the RP tool.
   c. The RP tool validates the Krill TA by fetching the HTTPS `.cer` URL that the TAL points to and verifying it against the signature in the TAL file.
   d. The RP tool (periodically) queries the Krill RRDP server at https://some.domain/rrdp/notification.xml and follows links contained in the response.
   e. The RP tool outputs, or a helper script queries, the ROAs from the RP and outputs them to standard out / the Docker logs.

5. Terraform runs the test suite.

6. If the test suite creates ROAs in Krill, the RPs detect them via RRDP or Rsync, validate and serve them as [VRPs](https://rpki.readthedocs.io/en/latest/rpki/securing-bgp.html?highlight=vrp#route-announcement-validity) via the RTR protocol. In a real deployment these VRPs would be consumed by Routers connected to the RPs. The test suite is able to run an RTR client to consume the VRPs and compare them to the ROAs created in Krill.

### Post deployment

Terraform executes the Python based end-to-end test suite.

### Inspect

#### Prepare to use Docker and Docker Compose

Before you can use docker and docker-compose commands you must first tell docker and   docker-compose to connect to the Docker daemon running on the Digital Ocean droplet/AWS EC2 instance. This is done by setting environment variables. The terraform template has been designed to so that you can run the following `eval` commands at the shell prompt to manage these environment variables:_

| Action             | Shell command                                    |
| ------------------ | ------------------------------------------------ |
| Set the env vars   | `eval $(terraform output docker_env_vars)`       |
| Unset the env vars | `eval $(terraform output unset_docker_env_vars)` |

> _**Note:** To execute `docker-compose` commands you must be in the `docker/` subdirectory so that the Docker Compose template can be found._

#### Prepare to use Krillc

```bash
$ eval $(terraform output docker_env_vars)
$ pushd ../lib/docker/
$ KRILL_ADMIN_TOKEN=$(docker-compose logs krill 2>&1 | grep -Eo 'token [a-z0-9-]+' | cut -d ' ' -f 2)
$ alias krillc="docker exec \
    -e KRILL_CLI_SERVER=https://localhost:3000/ \
    -e KRILL_CLI_TOKEN=${KRILL_ADMIN_TOKEN} \
    krill krillc"
```

You are now ready to issue `krillc` commands.

#### Display container logs

```bash
$ docker-compose logs -f
```

#### Explore the containers from within

_Note: The shell that has to be invoked varies depending on the base image used to create the container._

```bash
$ docker-compose exec nginx /bin/bash
$ docker-compose exec routinator /bin/sh
$ docker-compose exec krill /bin/bash
$ docker-compose exec rsyncd /bin/bash
```

### Undeploy

```bash
$ popd
$ terraform destroy
```

## Testing

### Results

```
module.post.null_resource.run_tests[0] (local-exec): ----------------- generated html file: file:///tmp/report.html -----------------
```

## RP details

This section details which Relying Party tools are configured for testing with Krill. The information below is correct at the time of writing.

### FORT Validator

| Property | Value |
|----------|-------|
| Vendor   | FORT Project by [LACNIC](https://www.lacnic.net/) and [NIC.MX](https://www.nicmexico.mx/) |
| Version  | 1.1.1 |
| Image    | [`ximoneigteen/fortvalidator`](https://hub.docker.com/r/ximoneighteen/fortvalidator) |

Notes:
- Invoked with `--log.level info
    --local-repository /repo
    --tal /tals
    --tal ${TAL_DIR}/ta.tal
    --server.interval.refresh 5
    --server.interval.retry 5
    --server.interval.validation 60`

### OctoRPKI

| Property | Value |
|----------|-------|
| Vendor   | [CloudFlare](https://blog.cloudflare.com/cloudflares-rpki-toolkit/) |
| Version  | Latest |
| Image    | [`cloudflare/octorpki`](https://hub.docker.com/r/cloudflare/octorpki) |

Notes:
- Invoked with `-tal.name ta -tal.root ${TAL_DIR}/ta.tal -refresh 5s -output.sign=false`

### Routinator

| Property | Value |
|----------|-------|
| Vendor   | [NLNet Labs](https://nlnetlabs.nl/projects/rpki/routinator/) |
| Version  | Latest |
| Image    | [`nlnetlabs/routinator`](https://hub.docker.com/r/nlnetlabs/routinator) |

Notes:
- Invoked with `-vvv
    server
    --rtr 0.0.0.0:3323 --http 0.0.0.0:9556`

### Rcynic

| Property | Value |
|----------|-------|
| Vendor   | [Dragon Research Labs](https://github.com/dragonresearch/rpki.net/tree/master/rp/rcynic) |
| Version  | buildbot-1.0.1544679302 |
| Image    | [`ximoneighteen/rcynic`](https://hub.docker.com/r/ximoneighteen/rcynic) |

Notes:
- Invoked with `--config /opt/rcynic.conf
    --unauthenticated ${DATA_DIR}/unauthenticated
    --xml-file ${DATA_DIR}/validator.log.xml
    --tals ${TAL_DIR}
    --no-prefer-rsync`.
- Configured to log at debug level to stderr and to use sqlite3 as the db engine.
- Binary DER ROA objects are retrieved via SQLite query from DB table `rcynicdb_rpkiobject`.
- When not using the Krill embedded TA, ROA objects who `uri` field is `LIKE` the FQDN in the TAL are excluded.
- `SELECT writefiled(id, der)` output is converted to text using `print_roa`.
- The text is converted to [GoRTR](https://github.com/cloudflare/gortr) compatible JSON and served from [lighttpd](https://www.lighttpd.net/) for GoRTR to fetch.

### rpki-client

| Property | Value |
|----------|-------|
| Vendor   | [kristapsdz](https://github.com/kristapsdz/rpki-client) |
| Version  | commit 5b09ea2 (Aug 24 2019) |
| Image    | [`ximoneighteen/rpki-client:latest`](https://hub.docker.com/r/ximoneighteen/rpki-client) |

Notes:
- Invoked with `-e /usr/bin/rsync -t ${TAL_DIR}/*.tal ${DATA_DIR}`.
- The v0.2.0 release (Jun 16 2019) is not used because it causes error `tal.c:109: tal_parse_stream: Assertion ``line[linelen - 1] == '\n'' failed`.
- The `kristapsdz` version is used (as opposed to the OpenBSD version) because it supports Linux and OpenBSD cannot run inside a Docker container.
- The text is converted to [GoRTR](https://github.com/cloudflare/gortr) compatible JSON and served from [lighttpd](https://www.lighttpd.net/) for GoRTR to fetch.

### RPKI Validator 3

| Property | Value |
|----------|-------|
| Vendor   | [RIPE NCC](https://www.ripe.net/) |
| Version  | alpine latest |
| Image    | [`ripencc/rpki-validator-3-docker:alpine`](https://hub.docker.com/r/ripencc/rpki-validator-3-docker) |

Notes:
- Strict validation mode is enabled.

### GoRTR

Several GoRTR instances are configured for making VRPs from OctoRPKI, rcynic and rpki-client available to the test suite via the RTR protocol.

# Diagnosing issues

- Increase the Krill log level via Terraform command line argument `-var krill_log_level=trace`.
- During the test inspect the deployed Docker containers and their logs, e.g. `docker logs krill`.
- During the test query the deployed services directly via Docker port proxying, e.g.
```
Fetch from the Krill RRDP endpoint:
$ curl --cacert ../lib/docker/relyingparties/base/rootCA.crt --resolve nginx.krill.test:443:127.0.0.1 https://nginx.krill.test/rrdp/notification.xml

Fetch from the Rsync endpoint:
$ rsync --list-only rsync://127.0.0.1/repo/

Query Routinator metrics:
$ curl http://127.0.0.1:9556/metric 
```
- You can see which ports are proxied with `sudo netstat -ntlp` which should show clearly the Docker proxy ports.
