# Krill + nginx + rsyncd + routinator in the Digital Ocean cloud

## Introduction

[Krill](https://www.nlnetlabs.nl/projects/rpki/krill/) is a free, open source Resource Public Key Infrastructure (RPKI) daemon by [NLnet Labs](https://nlnetlabs.nl/).

This project uses off-the-shelf containers from Docker Hub to demonstrate:

* Deployment of Krill behind an industry standard HTTP proxy (nginx) as advised by the [official Krill documentation](https://rpki.readthedocs.io/en/latest/krill/running.html#proxy-and-https).
* Integration with an rsync server for clients that do not support the RRDP protocol.
* NLnet Labs [Routinator](https://www.nlnetlabs.nl/projects/rpki/routinator/) as a client of Krill.

----

_**WARNING!** Executing this demo will create resources in the [Digital Ocean cloud](https://www.digitalocean.com/). These resources are **NOT free**, they will incur a small cost. Please ensure that you have **permission** from your Digital Ocean account owner to incur costs on the account!_

----

## Requirements

For this demo you will need:
- A Digital Ocean account.
- A [Digital Ocean API token](https://cloud.digitalocean.com/account/api/tokens).
- A DNS domain managed by Digital Ocean.
- The [HashiCorp Terraform](https://www.terraform.io/downloads.html) command line tool (tested with v0.12.7)
- The [Docker](https://docs.docker.com/install/#supported-platforms) command client (tested with v18.09.5).
- The [Docker Compose](https://docs.docker.com/compose/install/) (tested with v1.24.0) command line tool.

## Architecture

### Digital Ocean topology

The diagram below describes the Digital Ocean topology and how Terraform creates it:

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
+---^------^------------+---------------|--------|----------|---+
    |      |                            |        |          |
create   create                       docker   docker    install
droplet  dns & fw                     compose  volume    docker
    |      |                          up       create    via ssh
    |      |                            |        |          |  
   (1)    (2)                          (5)      (4)        (3)
    |      |   +- Host Computer --------|---+    |          |
    |      |   |      Docker (Compose)      |    |          |
    |      |   |----------------------------+    |          |
    |      |   |   Local-Exec Provisioner   |----+          |
    |      |   +----------------------------+               |
    |      +---|   Digital Ocean Provider   |               |
    |          +----------------------------+               |
    +----------|   Docker Machine Provider  |---------------+
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
|    |    +-C----------+   +-C-|t|---+      +-C-|t|------|t|-+   +-C-|t|--+    |    |
|    |    | routinator |   |  nginx  |--+   |      krill     |   | rsyncd |    |    |
|    |    +--|-------|-+   +--|---|--+  |   +--------|-------+   +---|----+    |    |
|    |       |       O 323    |   |     +----------> O 3000          |         |    |
|    +-------|----------------|---|----------------------------------|---------+    |
+---------+  |                |   |                                  |              |
| dockerd |  |                |   |                                  |              |
+----|-------|----------------|---|----------------------------------|--------------+
     |       |                |   |                                  |
2376 O       O 9556        80 O   O 443                              O 873
     
     ^ Docker/TLS        HTTP ^   ^ HTTPS/RRDP                       ^ RSYNC
     |                        |   |                                  |
     |                        |   +----------------+-----------------+
     |                        |                    |
 Terraform               Lets Encrypt         Krill clients
    CLI                   Challenge          e.g. Routinator
```

**Key:**
- C: Docker container
- V: Docker persistent named volume
- S: Docker private subnet
- mount: Docker volume mounted inside a container
- NNN: TCP/IP port numbers, e.g.:
  - 323:  Routinator RTR port, not used in this demo
  - 3000: Krill HTTPS/RRDP port, only exposed to nginx
  - 9556: Routinator Prometheus port, for monitoring the connection to Krill

### Special configuration

- The krill container is configured via environment variables to know its public FQDN and with `use_ta = true` which causes it to create an embedded Trust Anchor (TA).
- The routinator container image is extended via a `Dockerfile` to download and install the Krill Trust Anchor Locator (TAL) file before starting the Routinator.
- The nginx container image is extended via a `Dockerfile` with a config file directing nginx to proxy HTTPS connections via the internal Docker private network to port 3000 on the krill container.
- The rsyncd container image is extended via a `Dockerfile` with a config file telling rsyncd how to share the files mounted into the container from the krill rsync data Docker volume.

## Running

### Prepare

To run the demo you will need a copy of the demo templates and an SSH key pair.
**Note:** `some.domain` should already be managed by Digital Ocean.

```
$ ssh-keygen -t rsa -f /tmp/demo-ssh-key -N ""
$ git clone https://github.com/nlnetlabs/rpki-deploy.git
$ cd rpki-deploy/terraform/krill-integration-demo
$ export TF_VAR_do_token=xxxxxx
$ export TF_VAR_ssh_key_path=/tmp/demo-ssh-key
$ export TF_VAR_hostname=somehostname
$ export TF_VAR_domain=some.domain
```

If you want to change any of the default values in `variables.tf`, e.g. deployment region, droplet size, tags, [read this page](https://learn.hashicorp.com/terraform/getting-started/variables.html) to learn how to override them.

### Deploy

`init` installs any Terraform plugins required by the templates.
`apply` explains what will be created then, if you approve, executes the template.

```
$ terraform init
$ terraform apply
```

Terraform will:
1. Create a Digital Ocean droplet via the Docker Machine provider.
2. Create A and AAAA DNS records pointing to the droplet.
3. Install Docker on the droplet and secure the Docker daemon with TLS authentication.
4. Create an "external" persistent volume for Lets Encrypt certificates on the droplet.
5. Invoke Docker Compose to deploy the private network and containers on the droplet.

### What are the containers doing?

The descriptions below are based on publication via RRDP. Alternatively Krill can also [publish via rsync](https://rpki.readthedocs.io/en/latest/rpki/using-rpki-data.html?highlight=rsync#fetching-and-verifying).


```
Operator    Docker    Docker Hub    NGINX    Krill    Routinator   Lets Encrypt
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
   |                                  |        |          | Start Routinator
   |                                  |        |<-Get CER-|
   |                                  |        |---CER--->| Verify CER
   .                                  .        .          .
   .                                  .        .          .
   .                                  .        .          .
   |--Create ROAs using krill_admin-->|        |          |
                                      | Proxy->|          |
                                               | Publish  |
                                               |          |
                                               |<--Fetch--|
                                               |-via RRDP>| Parse & Verify

   ```

1. Docker:
   a. Pulls base images for the containers.
   b. Builds the configuration layers for the routinator, nginx and rsyncd containers.
   c. Creates the containers.

2. On the Nginx container:
   a. Request a certificate from Lets Encrypt.
   b. Answer the challenge from Lets Encrypt to Nginx at http://some.domain/.
   c. Receive and install the new certificate from Lets Encrypt.
   d. Proxy requests to port 443 via the private network to port 3000 of the Krill container.

3. On the Krill container:
   a. `use_ta=true` causes Krill to setup a test Trust Anchor.

3. On the Routinator container:
   a. A custom `entrypoint.sh` script fetches the Trust Anchor Locator file from Krill at https://some.domain/ta/ta.tal and writes it to the `/home/.rpki-cache/tals/` directory inside the Routinator container.
   b. Routinator starts up.
   c. Routinator validates the Krill TA by fetching the HTTPS `.cer` URL that the TAL points to and verifying it against the signature in the TAL file.
   d. Routinator periodically queries the Krill RRDP server at https://some.domain/rrdp/notification.xml and follows links contained in the response.

5. An operator creates [ROAs](https://rpki.readthedocs.io/en/latest/rpki/securing-bgp.html#route-origin-authorisations) in Krill.

6. Krill announces the ROAs.

7. Routinator detects them via RRDP, validates them and serves them as [VRPs](https://rpki.readthedocs.io/en/latest/rpki/securing-bgp.html?highlight=vrp#route-announcement-validity) to any connected Routers.

### Generate some fake ROAs

Use the `krill_admin` binary installed in the `krill` container to create a
CA that is a child of the embedded TA and then create ROAs in the child.

----

_**Note:** Before you can use docker and docker-compose commands you must first
tell docker and docker-compose to connect to the Docker daemon running on the
Digital Ocean droplet. This is done by setting environment variables. The
terraform template has been designed to so that you can run the following
`eval` commands at the shell prompt to manage these environment variables:_

    Set the env vars:    eval $(terraform output docker_env_vars)
    Unset the env vars:  eval $(terraform output unset_docker_env_vars)

_**NOTE**: To execute `docker-compose` commands you must be in the `docker/`
subdirectory so that the Docker Compose template can be found._

----

    $ eval $(terraform output docker_env_vars)
    $ cd docker/
    $ KRILL_AUTH_TOKEN=$(docker-compose logs krill 2>&1 | grep -Eo 'token [a-z0-9-]+$' | cut -d ' ' -f 2)
    $ alias ka="docker-compose exec krill krill_admin -s https://localhost:3000/ -t ${KRILL_AUTH_TOKEN}"
    $ ka cas add -h child -c secret2
    $ ka cas children -h ta add -4 10.0.0.0/16 embedded -h child 
    $ ka cas update -h child add-parent -p ta embedded

For the next step the `krill_admin` command takes a file as input and the demo
mounts `/tmp/ka` in the container from the same location in the host, but the
filesystem is that of the remote droplet, nor our host filesystem. So we have
to copy the file to the droplet before we can import it into Krill:

    $ cat <<EOF >/tmp/delta.1
    A: 10.0.0.0/24 => 64496
    A: 10.0.1.0/24 => 64496
    EOF
    $ scp /tmp/delta.1 root@somehostname.some.domain:/tmp/ka/
    $ ka cas roas -h child update -d /tmp/ka/delta.1

### Inspect

#### Query the state of the Routinator

- http://some.domain:9556/status
- http://some.domain:9556/metrics
- http://some.domain:9556/json

The generate fake ROAs step above should have caused Routinator to fetch ROAs
from Krill which should be visible in the Routinator Prometheus monitoring
endpoints, in particular the `/json` endpoint should show:

    {
    "roas": [
        { "asn": "AS64496", "prefix": "10.0.1.0/24", "maxLength": 24, "ta": "ta" },
        { "asn": "AS64496", "prefix": "10.0.0.0/24", "maxLength": 24, "ta": "ta" }
    ]
    }

#### Display container logs

    $ docker-compose logs -f

#### Explore the containers from within

_Note: The shell that has to be invoked varies depending on the base image used to create the container._

    $ docker-compose exec nginx /bin/bash
    $ docker-compose exec routinator /bin/sh
    $ docker-compose exec krill /bin/bash
    $ docker-compose exec rsyncd /bin/bash

### Undeploy

    $ cd ../
    $ terraform destroy
