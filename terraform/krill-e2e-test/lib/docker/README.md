# Krill + nginx + rsyncd + routinator

## Introduction

[Krill](https://www.nlnetlabs.nl/projects/rpki/krill/) is a free, open source Resource Public Key Infrastructure (RPKI) daemon by [NLnet Labs](https://nlnetlabs.nl/).

This project uses off-the-shelf containers from Docker Hub to demonstrate:

* Operation of Krill behind an industry standard HTTP proxy as advised by the [official Krill documentation](https://rpki.readthedocs.io/en/latest/krill/running.html#proxy-and-https).
* Integration with an rsync server, as Krill is not capable of acting as an rsync server itself.

* NLnet Labs [Routinator](https://www.nlnetlabs.nl/projects/rpki/routinator/) as a client of Krill.

## Requirements

To run this demo you will need a host that:

* Is reachable by Lets Encrypt over the public Internet.
* Has [Docker](https://docs.docker.com/install/#supported-platforms) installed (tested with Client v18.09.5 and Engine (Community) v18.09.5 and v19.03.2).
* Has [Docker Compose](https://docs.docker.com/compose/install/) installed (tested with v1.24.0)

This demo has been tested on hosts running Ubuntu 16.04 LTS and Ubuntu 19.04.

**Tip**: See the [Terraform Digital Ocean Docker demo]() for an example of running this demo on a Digital Ocean Droplet.

## Architecture

### Topology

```
+-Host---------------------------------------------------------------------------+
|                                                                                |
|                         +-V------------+   +-V------------------------+        |
|                         | certificates |   |        rsync data        |        |
|                         +------|m|-----+   +----|m|-------------|m|---+        |
|                                |o|              |o|             |o|            |
|    +-S:172.18.0.0/16-----------|u|--------------|u|-------------|u|-------+    |
|    |                           |n|              |n|             |n|       |    |
|    |    +-C----------+     +-C-|t|---+      +-C-|t|----+    +-C-|t|--+    |    |
|    |    | routinator |     |  nginx  |----->|   krill  |    | rsyncd |    |    |
|    |    +--|-------|-+     +-|--|----+ 3000 +----------+    +----|---+    |    |
|    |       |       |         |  |                                |        |    |
|    +-------|-------v---------|--|--------------------------------|--------+    |
|            |       |         |  |                                |             |
+------------|-------v---------|--|--------------------------------|-------------+
             |       |         |  |                                |
             |       v         |  |                                |
             o 9556  |      80 o  o 443                            o 873
                     v
                     |            ^                                ^
                     v            |                                |
                     |            ^                                ^
                     v            |                                |
Wild Internet         -->-->-->-->-->-->-->-->-->-->-->-->-->-->-->
```

**Key:**
- C: Docker container
- V: Docker persistent named volume
- S: Docker private subnet
- mount: Docker volume mounted inside a container
- NNN: TCP/IP port numbers

### Special configuration

- The krill container is configured via environment variables to know its public FQDN and with `use_ta = true` which causes it to create an embedded Trust Anchor (TA).
- The routinator container image is extended via a `Dockerfile` to download and install the Krill Trust Anchor Locator (TAL) file before starting the Routinator.
- The nginx container image is extended via a `Dockerfile` with a config file directing nginx to proxy HTTPS connections via the internal Docker private network to port 3000 on the krill container.
- The rsyncd container image is extended via a `Dockerfile` with a config file telling rsyncd how to share the files mounted into the container from the krill rsync data Docker volume.

## Running

### Prepare

To run the demo you will need a copy of the demo templates:

```
$ git clone https://github.com/nlnetlabs/rpki-deploy.git
$ cd rpki-deploy.git/terraform/krill-integration-demo
```

### Create
```
export KRILL_FQDN=some.domain
docker volume create krill_letsencrypt_certs
docker-compose up --build -d
```

### What are the containers doing?

The descriptions below are based on publication via RRDP. Alternatively Krill can also [publish via rsync](https://rpki.readthedocs.io/en/latest/rpki/using-rpki-data.html?highlight=rsync#fetching-and-verifying).


```
Operator    Docker    Docker Hub    NGINX    Krill    Routinator   Lets Encrypt
   |
   |---Up---->|
   |          |---Pull--->|
   |          |<--Image---|
   |          |
   |          |---Create & Run------->|------->|--------->|
   |                                  |
   |                                  |---Request certificate------------>|
   |                                  |<--Perform HTTP challenge----------|
   |                                  |                                   |
   |                                  |---Respond to HTTP challenge------>|
   |                                  |<--Issue certificate---------------|
   |                                  |                                   |
   |                                           | Make TA
   |                                           |
   |                                           |<-Get TAL-|
   |                                           |----TAL-->|
   |                                                      | Install TAL
   |                                                      | Startup
   |                                           |<-Get CER-|
   |                                           | .CER     |
   |                                           |--------->| Verify CER
   .                                           .          .
   .                                           .          .
   .                                           .          .
   |--Create ROAs using krill_admin-->|
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

```
$ KRILL_ADMIN_TOKEN=$(docker-compose logs krill 2>&1 | grep -Eo 'token [a-z0-9-]+' | cut -d ' ' -f 2)
$ alias ka="docker-compose exec krill krill_admin -s https://localhost:3000/ -t ${KRILL_ADMIN_TOKEN}"
$ cat <<EOF >/tmp/delta.1
A: 10.0.0.0/24 => 64496
A: 10.0.1.0/24 => 64496
EOF
$ ka cas add -h child -c secret2
$ ka cas children -h ta add -4 10.0.0.0/16 embedded -h child 
$ ka cas update -h child add-parent -p ta embedded
$ ka cas roas -h child update -d /tmp/delta.1
```

### Inspect

Query the state of the Routinator:
- http://some.domain:9556/status
- http://some.domain:9556/metrics
- http://some.domain:9556/json

_**Note:** In this demo the Routinator Prometheus endpoint is only available via plain HTTP, not via HTTPS. Please make sure that you do not use HTTPS URLs when querying the Routinator Prometheus endpoints._

The generate fake ROAs step above should have caused these Routinator Prometheus outputs to show the use of the Krill TAL and the `json` output should show two ROAs like so:

```
{
  "roas": [
    { "asn": "AS64496", "prefix": "10.0.1.0/24", "maxLength": 24, "ta": "ta" },
    { "asn": "AS64496", "prefix": "10.0.0.0/24", "maxLength": 24, "ta": "ta" }
  ]
}
```

You can also display the logs from the containers to see what they have been doing:

```
$ docker-compose logs -f
```

And you can open a shell prompt in any or all of the containers to explore them from the inside:

_The shell that has to be invoked varies depending on the base image used to create the container._

```
$ docker-compose exec nginx /bin/bash
$ docker-compose exec routinator /bin/sh
$ docker-compose exec krill /bin/bash
$ docker-compose exec rsyncd /bin/bash
```

### Cleanup

```
$ docker-compose down -v
```