Warning! This document is currently being updated to reflect recent changes from demo to e2e framework. These edits are currently incomplete and thus this document is somewhere between the two states at present.

----

# Krill E2E Test Framework

## Contents

* [Introduction](#introduction)
    * [Abbreviations used in this document](#abbreviations-used-in-this-document)
    * [What is tested?](#what-is-tested)
    * [Why is it based on Docker in the cloud?](#why-is-it-based-on-docker-in-the-cloud)
* [Integration with Krill @ GitHub](#integration-with-krill--github)
    * [Using GitHub Actions](#using-github-actions)
    * [Protecting secrets](#protecting-secrets)
* [Architecture](#architecture)
    * [Cloud topology](#cloud-topology)
    * [Docker topology](#docker-topology)
    * [Special configuration](#special-configuration)
* [Running](#running)
    * [Requirements](#requirements)
    * [Prepare](#prepare)
        * [Prepare for Digital Ocean](#prepare-for-digital-ocean)
        * [Prepare for Amazon Web Services](#prepare-for-amazon-web-services)
    * [Deploy](#deploy)
        * [Container startup sequence](#container-startup-sequence)
    * [Post deployment](#post-deployment)
        * [Prepare to use Krillc](#prepare-to-use-krillc)
        * [Create a CA as a child of the embedded TA](#create-a-ca-as-a-child-of-the-embedded-ta)
        * [Create some fake ROAs](#create-some-fake-roas)
    * [Inspect](#inspect)
        * [Query the state of the Routinator](#query-the-state-of-the-routinator)
        * [Display container logs](#display-container-logs)
        * [Explore the containers from within](#explore-the-containers-from-within)
    * [Undeploy](#undeploy)

Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc).

----

## Introduction

This directory contains a prototype framework for testing [Krill](https://www.nlnetlabs.nl/projects/rpki/krill/) (a free, open source Resource Public Key Infrastructure (RPKI) daemon by [NLnet Labs](https://nlnetlabs.nl/)) end-to-end (E2E) in combination with various [Relying Party implementations](https://rpki.readthedocs.io/en/latest/tools.html#relying-party-software).

This framework uses off-the-shelf containers from Docker Hub deployed in the cloud to:

* Deploy Krill behind an industry standard HTTP proxy (nginx) as advised by the [official Krill documentation](https://rpki.readthedocs.io/en/latest/krill/running.html#proxy-and-https).
* Integrate with a co-deployed [rsync server](https://hub.docker.com/r/vimagick/rsyncd) for clients that do not support the RRDP protocol.
* Serve various Relying Party implementations, such as NLnet Labs [Routinator](https://www.nlnetlabs.nl/projects/rpki/routinator/), with data from Krill.

In this environment we can then manipulate Krill and verify that the desired changes are observed at the Relying Parties (RPs) connected to it, thereby testing Krill "end-to-end" (E2E).

This framework prototype began life as a deployment demo of various NLnet Labs and 3rd party RPKI related components. Its architecture is subject to review and is likely to evolve in step with the needs of the Krill project.

----

_**WARNING!** This framework creates resources in the [Digital Ocean](https://www.digitalocean.com/) or [Amazon Web Services](https://aws.amazon.com/) public cloud. These resources are **NOT free**, they will incur a small cost. Please ensure that you have **permission** from your cloud account owner to incur costs on the account before using this framework!_

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

### Why is it based on Docker in the cloud?

The combination of [Terraform](https://www.terraform.io/), [ocker Machine](https://docs.docker.com/machine/overview/), [Docker Compose](https://docs.docker.com/compose/) and Docker supports many different deployment targets while minimizing the maintenance effort per component. The templates have been deliberately structured such that the cloud and Docker parts are separated. Deployment can be done with Docker alone or with Docker in the cloud, potentially also to targets such as the [GitHub Actions with Docker Compose](https://github.blog/2019-08-08-github-actions-now-supports-ci-cd/#fast-ci-cd-for-any-os-any-language-and-any-cloud) or Kubernetes (e.g. on [Digital Ocean](https://www.digitalocean.com/products/kubernetes/) or [AWS](https://aws.amazon.com/kubernetes/)). Only the infrastructure parts such as the VM, DNS and cloud firewall, are cloud specific, the Docker core can run anywhere. With this structure it should be relatively easily to add support for other Terraform providers too.

The beauty of Terraform is the huge number of deployment targets that it supports. 
 
The beauty of Docker is the ability to use the same core to run on those many different deployment targets, the flexibility it gives you to compose the deployment such that containers share a host or have their own hosts or something in the middle and the collection of applications that are already available as Docker containers (e.g. nginx, rsyncd, Routinator, RPKI Validator 3, etc).

By using a VM with a public IP address and associated DNS A/AAAA records the framework is able to obtain a Lets Encrypt HTTPS certificate for NGINX such that Krill clients can trust the HTTPS certificate presented to them, while using NGINX to shield Krill from the Internet. A VM also offers the potential to scale beyond the capabilities of a CI only platform such as GitHub Actions (where for example the deployment environment is currently limited to [2-core with 7 GiB RAM](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/virtual-environments-for-github-hosted-runners#supported-runners-and-hardware-resources)) which could be useful given that some RP tools require a lot of memory (e.g. [RIPE NCC RPKI Validator 3](https://github.com/RIPE-NCC/rpki-validator-3)) requires a minimum of 1 GiB RAM by default just for itself, and larger numbers of certificate authorities and ROAs will increase the resources required by Krill).

Currently all clients are deployed as containers on the same host VM as Krill itself but the architecture supports splitting the containers out across multiple hosts. However some changes would be required to actually deploy using Docker Swarm or Kubernetes (for example) for such a scenario.

Conversely, except for the real HTTPS certificate requiring routing from the Internet to NGINX by registered name, it should in theory be possible to omit the public cloud layer and use the Docker Compose layer directly with GitHub Actions, however this has not been tested.

## Integration with Krill @ GitHub

### Using GitHub Actions

The [Krill GitHub repository](https://github.com/NLnetLabs/krill) contains a [GitHub Actions Workflow](https://github.com/NLnetLabs/krill/blob/master/.github/workflows/main.yml) definition that clones this E2E framework repository and uses it to test Krill with the most recent commit to master or commits to a Pull Request.

### Protecting secrets

The Krill GitHub repository uses [GitHub Secrets](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/creating-and-using-encrypted-secrets) to:
- Protect the Digital Ocean API token or AWS credentials used to deploy in the public cloud.
- Protect the decryption passphrase used to protect the SSH key used to SSH to the cloud VM.

## Architecture

### Directory layout

Platform specific artifacts:

| Directory or File-                            | Platform | Description |
| --------------------------------------------- | -------- | ----------- |
| `terraform/plugins`                           | GHA      | Contains a copy of the Docker Machine x64 Terraform plugin, used to accelerate the GHA run. |
| `terraform/krill-e2e-test/decrypt-ssh-key.sh` | GHA      | Script to decrypt `ssh_key.gpg`. |
| `terraform/krill-e2e-test/ssh_key.gpg`        | GHA      | SSH key used to SSH into the deployed VM. |
| `terraform/krill-e2e-test/run_on_aws/`        | AWS      | Starting point for deploying on AWS. |
| `terraform/krill-e2e-test/run_on_do/`         | DO       | Starting point for deploying on DO. |

Platform independent artifacts:

| Directory or File-                     | Description |
| -------------------------------------- | ----------- |
| `terraform/krill-e2e-test/scripts/`    | Bash scripts to configure and test Krill. |
| `terraform/krill-e2e-test/lib/docker/` | E2E Docker image definitions. |
| `terraform/krill-e2e-test/lib/infra/`  | Terraform module for cloud-agnostic infrastructure deployment. |
| `terraform/krill-e2e-test/lib/pre`     | Terraform module run before deployment. |
| `terraform/krill-e2e-test/lib/post`    | Terraform module run after deployment, e.g. the `/scripts/` are invoked from here. |

### Cloud topology

The diagram below describes the Digital Ocean topology and how Terraform creates it:

In the case of Amazon Web Services the Droplet is an EC2 Compute Instance and the DO DNS is AWS Route53.

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
|                       +-V-------------+   +-V-----+  +-V---------------+          |
|                       | certificates  |   | krill |  |    rsync data   |          |
|                       +------|m|------+   +---|m|-+  +-|m|---------|m|-+          |
|                              |o|              |o|      |o|         |o|            |
|    +-S:172.18.0.0/16---------|u|--------------|u|------|u|---------|u|-------+    |
|    |                         |n|              |n|      |n|         |n|       |    |
|    |    +-C--+ +----+    +-C-|t|---+      +-C-|t|------|t|-+   +-C-|t|--+    |    |
|    |    | RP | | RP |    |  nginx  |--+   |      krill     |   | rsyncd |    |    |
|    |    +----+ +----+    +--|---|--+  |   +--------|-------+   +---|----+    |    |
|    |                        |   |     +----------> O 3000          |         |    |
|    +------------------------|---|----------------------------------|---------+    |
+---------+                   |   |                                  |              |
| dockerd |                   |   |                                  |              |
+----|------------------------|---|----------------------------------|--------------+
     |                        |   |                                  |
2376 O                     80 O   O 443                              O 873
     
     ^ Docker/TLS        HTTP ^   ^ HTTPS/RRDP                       ^ RSYNC
     |                        |   |                                  |
     |                        |   +----------------+-----------------+
     |                        |                    |
 Terraform               Lets Encrypt         Krill clients
    CLI                   Challenge          e.g. the RPs
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

### Docker images for 3rd party RP tools

Not all 3rd party RP tools offer Docker images. For those that don't I have packaged them myself into Docker images. These images work well enough for this use case and hopefully can be made generally useful, but for now they are a limited work in progress. See https://github.com/ximon18/relyingpartydockerimages for more information.

## Running

### Requirements

This framework requires:
- A Digital Ocean or Amazon Web Services account.
- A [Digital Ocean API token](https://cloud.digitalocean.com/account/api/tokens) or AWS access key and secret access key.
- A DNS domain managed by Digital Ocean or Amazon Web Services.
- The [HashiCorp Terraform](https://www.terraform.io/downloads.html) command line tool (tested with v0.12.13)
- The [Docker](https://docs.docker.com/install/#supported-platforms) command client (tested with v18.09.5).
- The [Docker Compose](https://docs.docker.com/compose/install/) (tested with v1.24.1) command line tool.

### Prepare

To run the framework you will the required tools installed, a copy of the templates and scripts, an existing parent DNS domain that you have control of, and an SSH key pair.

> _**Note:** `some.domain` should already be managed by Digital Ocean or AWS._

```bash
$ ssh-keygen -m PEM -t rsa -f /tmp/demo-ssh-key -N ""
$ git clone https://github.com/nlnetlabs/rpki-deploy.git
$ export TF_VAR_ssh_key_path=/tmp/demo-ssh-key
$ export TF_VAR_hostname=somehostname
$ export TF_VAR_domain=some.domain
```

If you want to change any of the default values in `variables.tf`, e.g. deployment region, droplet size, tags, [read this page](https://learn.hashicorp.com/terraform/getting-started/variables.html) to learn how to override them.

> _**Note:** In the case of Krill @ GitHub the GHA workflow performs a shallow Git clone of this entire repository to obtain a copy of these files and uses a GitHub Secret to decrypt the `ssh_key.gpg` file stored in this directory, and a second GitHub Secret stores the required DO API token. The [Marrocchino Terraform GitHub v2 Action](https://github.com/marocchino/setup-terraform) action is used to install the Terraform CLI. The [official Terraform GitHub v2 Action](https://github.com/hashicorp/terraform-github-actions) is NOT used because it does not support `terraform destroy`._

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

### Deploy

`init` installs any Terraform plugins required by the templates.
`apply` explains what will be created then, if you approve, executes the template.

```bash
$ cd terraform/krill-e2e-test/deploy_on_XXX (e.g. do or aws)
$ terraform init
$ terraform apply
```

Terraform will:
1. Create a Digital Ocean droplet or AWS EC2 instance.
2. Create A and AAAA DNS records pointing to the droplet/instance.
3. Install Docker on the droplet and secure the Docker daemon with TLS authentication.
4. Create "external" persistent volumes for Lets Encrypt certificates and for Krill RSYNC data.
5. Invoke Docker Compose to build images, and deploy the private network and containers on the droplet.
6. Configure Krill.
7. Run the Krill E2E tests.

> _**Note:** Even though off-the-shelf Docker images are used for the RPs, images still need to be built for them because some tooling is installed to fetch, process and install the TAL and to parse and convert the ROA output into a "standard" format expected by the test suite. Additionally the Krill image has to be built and preferably without having to build the entire Rust application and dependencies from scratch. Currently a "hack" is used to accelerate the Krill image build whereby a not-too-old copy of the Krill Docker image `builder` stage is used as the base for the new image, thereby leveraging the Cargo build cache that already exists in the (very large) image._

#### Container startup sequence

What are the containers doing? The descriptions below are based on publication via RRDP. Alternatively Krill can also [publish via rsync](https://rpki.readthedocs.io/en/latest/rpki/using-rpki-data.html?highlight=rsync#fetching-and-verifying).

```
Operator    Docker    Docker Hub    NGINX    Krill    Relying Party   Lets Encrypt
   |
   |---Up---->|
   |          |---Pull--->|
   |          |<--Image---|
   |          |
   |          |---Create & run------->|------->|--------->|
   |                                  |
   |                                  |---Request certificate------------>|
   |                                  |<--Perform HTTP challenge----------|
   |                                  |                                   |
   |                                  |---Respond to HTTP challenge------>|
   |                                  |<--Issue certificate---------------|
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
   |--Create ROAs using krillc------->|        |          |
   |                                  | Proxy->|          |
   |                                           | Publish  |
   |                                           |          |
   |                                           |<--Fetch--|
   |                                           |-via RRDP>| Parse & Verify
   |                                                      |
   |<---------------------Read ROAs-----------------------| Output ROAs to standard out / Docker console
   |
   | Compare ROAs to Krills ROAs
   ```

1. Docker:
   a. Pulls base images for the containers.
   b. Builds the configuration layers for the RPs, Krill, nginx and rsyncd containers.
   c. Creates the containers.

2. On the Nginx container:
   a. Request a certificate from Lets Encrypt.
   b. Answer the challenge from Lets Encrypt to Nginx at http://some.domain/.
   c. Receive and install the new certificate from Lets Encrypt.
   d. Proxy requests to port 443 via the private network to port 3000 of the Krill container.

3. On the Krill container:
   a. `use_ta=true` causes Krill to setup a test Trust Anchor.

3. On the RP containers:
   a. A custom `entrypoint.sh` script fetches the Trust Anchor Locator file from Krill at https://some.domain/ta/ta.tal and writes it to a directory that the RP can read it from.
   b. Start the RP tool.
   c. The RP tool validates the Krill TA by fetching the HTTPS `.cer` URL that the TAL points to and verifying it against the signature in the TAL file.
   d. The RP tool (periodically) queries the Krill RRDP server at https://some.domain/rrdp/notification.xml and follows links contained in the response.
   e. The RP tool outputs, or a helper script queries, the ROAs from the RP and outputs them to standard out / the Docker logs.

5. An operator creates [ROAs](https://rpki.readthedocs.io/en/latest/rpki/securing-bgp.html#route-origin-authorisations) in Krill.

6. Krill announces the ROAs.

7. Routinator detects them via RRDP, validates them and serves them as [VRPs](https://rpki.readthedocs.io/en/latest/rpki/securing-bgp.html?highlight=vrp#route-announcement-validity) to any connected Routers.

### Post deployment

We can use the `krillc` binary installed in the `krill` container to create a CA that is a child of the embedded TA and then create ROAs in the child.

#### Prepare to use Krillc

Before you can use docker and docker-compose commands you must first tell docker and   docker-compose to connect to the Docker daemon running on the Digital Ocean droplet/AWS EC2 instance. This is done by setting environment variables. The terraform template has been designed to so that you can run the following `eval` commands at the shell prompt to manage these environment variables:_

| Action             | Shell command                                    |
| ------------------ | ------------------------------------------------ |
| Set the env vars   | `eval $(terraform output docker_env_vars)`       |
| Unset the env vars | `eval $(terraform output unset_docker_env_vars)` |

> _**Note:** To execute `docker-compose` commands you must be in the `docker/` subdirectory so that the Docker Compose template can be found._

```bash
$ eval $(terraform output docker_env_vars)
$ pushd ../lib/docker/
$ KRILL_AUTH_TOKEN=$(docker-compose logs krill 2>&1 | grep -Eo 'token [a-z0-9-]+' | cut -d ' ' -f 2)
$ alias krillc="docker exec \
    -e KRILL_CLI_SERVER=https://localhost:3000/ \
    -e KRILL_CLI_TOKEN=${KRILL_AUTH_TOKEN} \
    krill krillc"
```

You are now ready to issue `krillc` commands.

#### Create a CA as a child of the embedded TA

```bash
$ krillc add --ca child
$ krillc children add --embedded --ca ta --child child --ipv4 "10.0.0.0/16"
$ krillc parents add --embedded --ca child --parent ta
```

#### Create some fake ROAs

For the next step the `krillc` command takes a file as input and the demo mounts `/tmp/ka` in the container from the same location in the host. However, the filesystem is that of the remote droplet, nor our host filesystem. So we have to copy the file to the droplet before we can import it into Krill:

```bash
$ cat <<EOF >/tmp/delta.1
A: 10.0.0.0/24 => 64496
A: 10.0.1.0/24 => 64496
EOF
$ scp -i ${TF_VAR_ssh_key_path} /tmp/delta.1 root@somehostname.some.domain:/tmp/ka/
$ krillc roas update --ca child --delta /tmp/ka/delta.1
```

> When [issue #129](https://github.com/NLnetLabs/krill/issues/129) is resolved this will no longer require a file upload but will instead be possible via STDIN.

### Inspect

#### Query the state of the Routinator

- http://some.domain:9556/status
- http://some.domain:9556/metrics
- http://some.domain:9556/json

The generate fake ROAs step above should have caused Routinator to fetch ROAs
from Krill which should be visible in the Routinator Prometheus monitoring
endpoints, in particular the `/json` endpoint should show:

```json
{
    "roas": [
        { "asn": "AS64496", "prefix": "10.0.1.0/24", "maxLength": 24, "ta": "ta" },
        { "asn": "AS64496", "prefix": "10.0.0.0/24", "maxLength": 24, "ta": "ta" }
    ]
}
```

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
