import requests

from tests.util.docker import get_docker_host_fqdn


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
        self.version_cmd = version_cmd

    def is_ready(self):
        raise NotImplementedError("RP {self.name} does not have an is_ready() implementation")


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
Routinator = RelyingParty('routinator', 3323, 20, "routinator --version")
FortValidator = RelyingParty('fortvalidator', 323, 20, "fort --version")
OctoRPKI = RelyingParty('octorpki', 8083, 30, "/octorpki -version")

# Some RPs cannot be interrogated for their version, so instead when building a
# Docker image for them I included a version.txt file whose content was set to
# the version of the RP software being built in the image.
RPKIClient = RelyingParty('rpkiclient', 8085, 30, "cat /opt/version.txt")
RPKIValidator3 = RPKIValidator3('rpkivalidator3', 8323, 240, "cat /opt/version.txt")

# For Rcynic, we have no way of interrogating the service to determine what
# version it is, and an attempt to add an /opt/version.txt file to the Docker
# image failed as the image was unable to rebuild rcynic. So for now just quote
# the GitHub release tag that I believe I used to create the rcynic Docker
# image that we are currently using.
Rcynic = RelyingParty('rcynic', 8084, 30, "echo 'Believed to be buildbot-1.0.1544679302'")