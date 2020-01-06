# Intro

This is a very simple demonstration of how to run [Routinator](https://routinator.net/) and an [RTR](https://rpki.readthedocs.io/en/latest/rpki/using-rpki-data.html#feeding-routers) capable client as Docker containers in the same Docker private network.

In this demo the client is [`rtrclient`](https://rpki.realmv6.org/) but it could just as easily be a virtual router or some other RTR client.

# Reading suggestions

- https://rpki.readthedocs.io/
- https://docs.docker.com/compose/networking/

# Prerequisites

This demo uses [Docker Compose](https://docs.docker.com/compose/).

# Usage

## Accepting or declining the ARIN TAL RPA

Before deploying the demo you must first choose whether you want to accept or decline the [Arin TAL Relying Party Agreement](https://www.arin.net/resources/manage/rpki/tal/). In this demo acceptance or rejection of the agreement is controlled by setting an envionrment variable:

```
$ export ARIN_RPA=accept
OR
$ export ARIN_RPA=decline
```

## Deploy

Once you have decided whether to accept or decline the ARIN TAL RPA you can deploy the demo like so:

```
$ docker-compose up
```

Get a ☕ while:
- Docker bullds container images.
- Routinator fetches and validate ROAs from the RIRs.
- `rtrclient` sleeps 10 minutes while Routinator is busy.
- `rtrclient` fetches data from Routinator using the RTR protocol.

You should see something like this:

```
Creating network "docker-compose-private-network_default" with the default driver
Creating docker-compose-private-network_routinator_1 ... done
Creating docker-compose-private-network_rtrclient_1  ... done
Attaching to docker-compose-private-network_rtrclient_1, docker-compose-private-network_routinator_1
routinator_1  | RTR: Listening on 0.0.0.0:3323.
routinator_1  | Starting RTR listener.
routinator_1  | rsyncing from rsync://rpki.ripe.net/ta/.
rtrclient_1   | (2020/01/06 10:51:23:400625): RTR_MGR: rtr_mgr_start()
rtrclient_1   | Prefix                                     Prefix Length         ASN
rtrclient_1   | (2020/01/06 10:51:23:400769): RTR Socket: State: RTR_CONNECTING
...
rtrclient_1   | RTR-Socket changed connection status to: RTR_CONNECTING, Mgr Status: RTR_MGR_ERROR
rtrclient_1   | (2020/01/06 10:51:23:401797): RTR Socket: Waiting 600
...
routinator_1  | Validation completed. New serial is 0.
routinator_1  | Sending out notifications.
...
rtrclient_1   | (2020/01/06 11:01:23:401906): RTR Socket: State: RTR_CONNECTING
rtrclient_1   | (2020/01/06 11:01:23:403450): TCP Transport(routinator:3323): Connection established
...
rtrclient_1   | + 5.61.147.0                                  24 -  24        58243
rtrclient_1   | + 189.249.192.0                               19 -  24         8151
rtrclient_1   | + 185.27.216.0                                24 -  24        21277
rtrclient_1   | + 43.240.108.0                                22 -  24        24158
...
```

The last rows of the sample output show the VRPs received from Routinator by `rtrclient`.

Press CTRL-C to terminate the demo.

# Understanding the demo

- The [`docker-compose.yml`](docker-compose.yml) file defines two Docker "services", one for Routinator and one for `rtrclient`, which will be deployed by Docker Compose as containers in a new private Docker network.

- Both service definitions refer to subdirectories containing `Dockerfile` files. These are used to build Docker images for the containers that will be run:
  - For Routinator the image building process performs a one-time installation of RIR TAL files.
  - For `rtrclient` the image building process installs `rtrclient` in a Debian base image.

- The Docker [embedded DBS server](https://docs.docker.com/v17.09/engine/userguide/networking/configure-dns/) resolves the `routinator` service name to the Routinator container IP address.

- The [`unbuffer`](https://linux.die.net/man/1/unbuffer) command is used to ensure that `rtrclient` output appears in the Docker Compose `up` output.