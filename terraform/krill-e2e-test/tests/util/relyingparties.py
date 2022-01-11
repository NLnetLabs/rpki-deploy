import requests

from tests.util.docker import get_docker_host_fqdn, register_version_cmd


class RelyingParty:
    def __init__(self, name, rtr_port, rtr_timeout_seconds, version_cmd):
        self.name = name

        # Which port is the RP listening on for RTR connections? Note: there is
        # no host because the port is exposed on the Docker host, which is
        # either localhost or a remote VM (e.g. a Digital Ocean Droplet).
        self.rtr_port = rtr_port

        # Different RPs have different performance profiles, e.g. the RIPE NCC
        # RPKI Validator 3 takes considerably longer than the other RPs to
        # fetch an RTR snapshot from Krill.
        self.rtr_timeout_seconds = rtr_timeout_seconds

        # Some Relying Party software can be interrogated for its version. It
        # might be nicer to interrogate the running application but only
        # Routinator and RPKI Validator 3 expose HTTP APIs and only Routinator
        # makes it easy to get the version via that API. So instead issue
        # commands in the RP Docker containers.
        register_version_cmd(self.name, version_cmd)

    def __str__(self):
        return self.name

    def is_ready(self):
        raise NotImplementedError(f"RP {self.name} does not have an is_ready() implementation")


class RPKIValidator3(RelyingParty):
    def __init__(self, name, rtr_port, rtr_timeout_seconds, version_cmd):
        super().__init__(name, rtr_port, rtr_timeout_seconds, version_cmd)

    def is_ready(self):
        # Check to see if the RIPE NCC RPKI validator has processed the TAL yet.
        # 
        # curl -X GET --header 'Accept: application/json' 'http://localhost:8080/api/trust-anchors/1'
        # {
        # "data": {
        #     "type": "trust-anchor",
        #     "id": 1,
        #     "name": "ta.tal",
        #     "locations": [
        #     "rsync://rsyncd.krill.test/repo/ta/ta.cer"
        #     ],
        #     "subjectPublicKeyInfo": "MIIB....AQAB",
        #     "preconfigured": true,
        #     "initialCertificateTreeValidationRunCompleted": true,
        #                                                     ^^^^
        #
        # See: https://rpki-validator.ripe.net/swagger-ui.html#!/trust45anchor45controller/getUsingGET_3
        return (requests.get(f'http://{get_docker_host_fqdn()}:8080/api/trust-anchors/1').
            json()['data']['initialCertificateTreeValidationRunCompleted'])


# Define helper objects for each Relying Party that we can use in the tests.

# Routinator responds very quickly to a direct RTR connection, we could lower the 20 second timeout that
# we use here but sometimes there's a lot of variability in the GitHub Actions runner performance so we
# leave it higher than necessary to cope with any such slower than usual system performance.
Routinator = RelyingParty('routinator', 3323, 20, "routinator --version")
RoutinatorUnstable = RelyingParty('routinator_unstable', 3323, 20, "routinator --version")

# Fort also serves RTR directly. In testing it typically responds in a few seconds but like for Routinator
# we use a higher timeout just in case host or RP performance varies a bit.
FortValidator = RelyingParty('fortvalidator', 323, 20, "fort --version")

# OctoRPKI doesn't serve RTR itself, instead it produces JSON output which we then serve to RTRTR via
# Lighttpd. The test suite RTR client then connects to RTRTR. RTRTR exposes ROAs obtained from OctoRPKI
# JSON-over-HTTP on RTRTR port 8083.
OctoRPKI = RelyingParty('octorpki', 8083, 20, "/octorpki -version")

# Some RPs cannot be interrogated for their version, so instead when building a Docker image for them I
# included a version.txt file whose content was set to the version of the RP software being built in the
# image. Hence the use of 'cat' here.
#
# The RIPE NCC RPKI Validator 3 serves RTR itself, but for rpki-client we use Lighttpd and RTRTR as a
# bridge just as with OctoRPKI. RTRTR exposes VRPs obtained from rpki-client JSON-over-HTTP on RTRTR port
# 8085.
RPKIValidator3 = RPKIValidator3('rpkivalidator3', 8323, 240, "cat /opt/version.txt")
RPKIClient = RelyingParty('rpkiclient', 8085, 20, "cat /opt/version.txt")

# For Rcynic, we have no way of interrogating the service to determine what
# version it is, and an attempt to add an /opt/version.txt file to the Docker
# image failed as the image was unable to rebuild rcynic. So for now just quote
# the GitHub release tag that I believe I used to create the rcynic Docker
# image that we are currently using.
#
# Like OctoRPKI and rpki-client, rcynic doesn't serve RTR itself and so we use Lighttpd and RTRTR as a
# bridge. RTRTR exposes VRPs obtained from rcynic JSON-over-HTTP on RTRTR port 8084.
#
# In the Rcynic case our librtr Python based client has trouble talking to RTRTR (and in fact rtrclient
# from the librtr project has the same problem) when it fetches VRPs from Rcynic, via Lighthttpd. For
# some reason the initial connection attempt fails, but librtr doesn't retry, it just hangs and in the
# case of the Python client throws a SyncTimeout exception after the configured timeout period. As such
# we use a low timeout and rely on the test suite retrying a couple of times to successfully fetch the
# VRPs on a subsequent connection attempt.
Rcynic = RelyingParty('rcynic', 8084, 5, "echo 'Believed to be buildbot-1.0.1544679302'")

RPKIProver = RelyingParty('rpki-prover', 8086, 20, "echo 'Unknown'")