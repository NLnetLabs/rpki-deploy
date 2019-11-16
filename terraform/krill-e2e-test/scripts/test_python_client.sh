#!/bin/bash
set -Eeuo pipefail

KRILL_OPENAPI_SPEC_PATH="${KRILL_BUILD_PATH}/doc/openapi.yaml"
KRILL_CONTAINER="krill"
KRILL_AUTH_TOKEN=$(docker logs ${KRILL_CONTAINER} 2>&1 | tac | grep -Eom 1 'token [a-z0-9-]+' | cut -d ' ' -f 2)
export BANNER="$(basename $0):"

source ../../lib/docker/relyingparties/base/my_funcs.sh

if [ ! -f "${KRILL_OPENAPI_SPEC_PATH}" ]; then
    my_log "No OpenAPI spec file found at ${KRILL_OPENAPI_SPEC_PATH}, aborting."
    exit 0
fi

# Work inside a tempory directory that we can delete afterwards
TMPDIR=$(mktemp -d)

my_log "Generating Python client library from OpenAPI spec ${KRILL_OPENAPI_SPEC_PATH} in tmp dir ${TMPDIR}"
cp ${KRILL_OPENAPI_SPEC_PATH} ${TMPDIR}/

# Unset Docker env so that we communicate with
# the local Docker daemon, not the remote one:
unset DOCKER_TLS_VERIFY
unset DOCKER_MACHINE_NAME
unset DOCKER_HOST
unset DOCKER_CERT_PATH

docker run --rm -v ${TMPDIR}:/local \
    openapitools/openapi-generator-cli generate \
    -i /local/openapi.yaml \
    -g python \
    -o /local/out \
    --skip-validate-spec

my_log "Installing generated library in a Python 3 venv"

# Create and enter Python3 venv
sudo apt-get install -y python3-venv

pushd ${TMPDIR}
set +u; python3 -m venv venv; source venv/bin/activate; set -u

# Install the generated client library inside the venv
pip3 install ${TMPDIR}/out/

# Create a Python client app that uses the generated library
my_log "Creating test client"

cat <<-EOT >${TMPDIR}/client.py
import openapi_client
from openapi_client.rest import ApiException

configuration = openapi_client.Configuration()
configuration.access_token = '${KRILL_AUTH_TOKEN}'
configuration.host = "https://${KRILL_FQDN}/api/v1"
configuration.verify_ssl = False
configuration.ssl_ca_cert = None
configuration.assert_hostname = False
configuration.cert_file = None

print(f'Connecting to {configuration.host} using token {configuration.access_token}..')

api_instance = openapi_client.CertificateAuthoritiesApi(openapi_client.ApiClient(configuration))

try:
    print('Connected. Listing CAs..')
    api_response = api_instance.cas_get()
    for ca in api_response.cas:
        print(f'  CA: {ca.name}')
except ApiException as e:
    print(f'Exception when calling CertificateAuthoritiesApi->cas_get: {e}\n')

print('Finished')
EOT

# Run the client
my_log "Running test client"
export PYTHONWARNINGS="ignore:Unverified HTTPS request"
python3 ${TMPDIR}/client.py 2>&1 | sed -e "s|^|Test Client: |"

# Leave Python3 venv
set +u; deactivate; set -u
popd

my_log "Cleaning up"
rm -Rf ${TMPDIR}

my_log "End of Python client test"
