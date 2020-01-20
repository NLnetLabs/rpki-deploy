import logging
import os
import pytest
import rtrlib

from retrying import retry
from time import time

from compose.project import Project
from compose.service import BuildAction, ImageType
from compose.cli.docker_client import docker_client
from compose.config import config
from krill_api import *

from tests.data.data import *

import tests.util.rpkivalidator3
from tests.util import krill
from tests.util.docker import class_service_manager, function_service_manager, run_command
from tests.util.krill import krill_api_config, krill_fqdn
from tests.util.rtr import rtr_fetch_one, roa_to_roa_string


@pytest.fixture(scope="module")
def docker_project():
    client = docker_client(config.Environment(os.environ))

    config_file = config.ConfigFile.from_filename('docker-compose.yml')
    details = config.ConfigDetails('.', [config_file])
    ready_config = config.load(details)

    # 'docker' is the COMPOSE_PROJECT_NAME. It affects the image names used and
    # so must match the COMPOSE_PROJECT_NAME value used at image build time. As
    # images were built by Terraform invoking the docker-compose command the
    # docker_project name it used, the default which is the directory name containing
    # the docker-compose.yml file, is the one we must use.
    docker_project = Project.from_config('docker', ready_config, client)

    yield docker_project

    docker_project.kill()
    docker_project.down(ImageType.none, True)
    docker_project.remove_stopped()


# Class scope means this fixture will be torn down at the end of each test
# class that uses it and created again for the next class that uses it. If you
# want many test classes to use it then module scope might be more appropriate.
@pytest.fixture(scope="class")
def krill_with_roas(docker_project, krill_api_config, class_service_manager):
    #
    # Define some retry helpers for situations where the API call to Krill
    # can succeed but Krill may not yet be in the expected state.
    #
    def no_retry_if_forbidden(e):
        """Return True if we should retry, False otherwise"""
        return not (isinstance(e, ApiException) and e.status == 403)

    def retry_if_zero(result):
        """Return True if we should retry, False otherwise"""
        return result == 0

    @retry(
        stop_max_attempt_number=10,
        wait_fixed=2000,
        retry_on_exception=no_retry_if_forbidden)
    def wait_until_ready():
        return krill_other_api.is_authorized()

    @retry(
        stop_max_attempt_number=3,
        wait_exponential_multiplier=1000,
        wait_exponential_max=10000,
        retry_on_exception=retry_if_zero)
    def wait_until_ca_has_at_least_one(ca_handle, property):
        ca = krill_ca_api.get_ca(ca_handle)
        return getattr(ca, property) is not None

    #
    # Go!
    #

    # Bring up Krill, rsyncd and nginx
    krill.select_krill_config_file(docker_project, 'krill.conf')
    class_service_manager.start_services_with_dependencies(
        docker_project, ['krill', 'rsyncd', 'tal_hack', 'nginx'])

    # Strategy: Test then add, don't add then handle failure because that will
    # cause errors to appear in the Krill server log which can be confusing
    # when investigating problems.

    # Get the API helper objects we need
    krill_api_client = ApiClient(krill_api_config)
    krill_ca_api = CertificateAuthoritiesApi(krill_api_client)
    krill_roa_api = RouteAuthorizationsApi(krill_api_client)
    krill_other_api = OtherApi(krill_api_client)

    # Define the CA handles that we will work with
    ta_handle = 'ta'
    parent_handle = 'parent'
    child_handle = 'child'

    # Ensure that Krill is ready for our attempts to communicate with it
    logging.info('Wait till we can connect to Krill...')
    wait_until_ready()

    #
    # Create the desired state inside Krill
    #

    logging.info('Checking if Krill has an embedded TA')
    ca_handles = [ca.handle for ca in krill_ca_api.list_cas().cas]

    if ta_handle in ca_handles:
        logging.info('Configuring Krill for use with embedded TA')

        logging.info('Adding CA if not already present')
        if not parent_handle in ca_handles:
            logging.debug('No CA, adding...')
            krill_ca_api.add_ca(AddCARequest(parent_handle))
            krill_ca_api.update_ca_repository(parent_handle, 'embedded')
            logging.debug('Added')

        logging.info('Creating TA -> CA relationship if not already present')
        if len(krill_ca_api.get_ca(ta_handle).children) == 0:
            logging.debug('No children, adding...')
            req = AddCAChildRequest(
                parent_handle,
                Resources(
                    asn=KRILL_PARENT_ASNS,
                    v4=KRILL_PARENT_IPV4S,
                    v6=KRILL_PARENT_IPV6S),
                'embedded')
            krill_ca_api.add_child_ca(ta_handle, req)
            logging.debug('Added')

            logging.debug('Waiting for children to be registered')
            wait_until_ca_has_at_least_one(ta_handle, 'children')

        logging.info('Creating TA <- CA relationship if not already present')
        if len(krill_ca_api.get_ca(parent_handle).parents) == 0:
            logging.debug('No parents, adding...')
            req = AddParentCARequest(ta_handle, 'embedded')
            krill_ca_api.add_ca_parent(parent_handle, req)
            logging.debug('Added')

            logging.debug('Waiting for parents to be registered')
            wait_until_ca_has_at_least_one(parent_handle, 'parents')

        logging.info('Adding child CA if not already present')
        if not child_handle in ca_handles:
            logging.debug('No CA, adding...')
            krill_ca_api.add_ca(AddCARequest(child_handle))
            krill_ca_api.update_ca_repository(child_handle, 'embedded')
            logging.debug('Added')

        logging.info('Creating CA -> CA relationship if not already present')
        if len(krill_ca_api.get_ca(parent_handle).children) == 0:
            logging.debug('No children, adding...')
            req = AddCAChildRequest(
                child_handle,
                Resources(
                    asn=KRILL_CHILD_ASNS,
                    v4=KRILL_CHILD_IPV4S,
                    v6=KRILL_CHILD_IPV6S),
                'embedded')
            krill_ca_api.add_child_ca(parent_handle, req)
            logging.debug('Added')

            logging.debug('Waiting for children to be registered')
            wait_until_ca_has_at_least_one(parent_handle, 'children')

        logging.info('Creating CA <- CA relationship if not already present')
        if len(krill_ca_api.get_ca(child_handle).parents) == 0:
            logging.debug('No parents, adding...')
            req = AddParentCARequest(parent_handle, 'embedded')
            krill_ca_api.add_ca_parent(child_handle, req)
            logging.debug('Added')

            logging.debug('Waiting for parents to be registered')
            wait_until_ca_has_at_least_one(child_handle, 'parents')

        logging.info('Creating CA ROAs if not already present')
        if len(krill_roa_api.list_route_authorizations(child_handle)) == 0:
            delta = ROADelta(added=TEST_ROAS, removed=[])

            @retry(
                stop_max_attempt_number=3,
                wait_exponential_multiplier=1000,
                wait_exponential_max=10000)
            def update_roas():
                logging.debug('Updating ROAs...')
                krill_roa_api.update_route_authorizations(child_handle, delta)

            update_roas()

    logging.info('Krill configuration complete')

    yield krill_api_client


class ServiceDetails:
    def __init__(self, service_name, details):
        self.service_name = service_name
        self.details = details

    @staticmethod
    def id_generator(val):
        if isinstance(val, ServiceDetails):
            return val.service_name


@pytest.mark.usefixtures("krill_with_roas")
class TestKrillWithRelyingParties:
    def test_setup(self):
        # Cause the krill_with_roas and dependent fixtures to be setup once
        # before the tests below run, otherwise the first real test also
        # includes the work and output of creating the fixtures.
        pass

    @pytest.mark.parametrize("service", [
        ServiceDetails("routinator", (3323, 20, "routinator --version")),
        ServiceDetails("fortvalidator", (323, 20, "fort --version")),
        ServiceDetails("octorpki", (8083, 30, "/octorpki -version")),
        ServiceDetails("rcynic", (8084, 30, "echo 'Believed to be buildbot-1.0.1544679302'")),
        ServiceDetails("rpkiclient", (8085, 30, "cat /opt/version.txt")),
        ServiceDetails("rpkivalidator3", (8323, 240, "cat /opt/version.txt")),
    ], ids=ServiceDetails.id_generator)
    def test_rtr(self, request, krill_fqdn, docker_project, function_service_manager, service, metadata):
        (rtr_port, timeout, version_cmd) = service.details

        function_service_manager.start_services_with_dependencies(docker_project, service.service_name)

        if version_cmd:
            logging.info(f"Running command '{version_cmd}'' in container for service {service.service_name}..")
            (exit_code, output) = run_command(docker_project, service.service_name, version_cmd)
            output = output.decode('utf-8').strip()
            logging.info(f"Command exit code={exit_code}, output={output}")
            metadata[f"{service.service_name} version"] = output

        try:
            rtr_start_time = int(time())
            logging.info(f'Connecting RTR client to {krill_fqdn}:{rtr_port}')
            received_roas = set(rtr_fetch_one(krill_fqdn, rtr_port, timeout))
            rtr_elapsed_time = int(time()) - rtr_start_time

            # r is now a list of PFXRecord
            # see: https://python-rtrlib.readthedocs.io/en/latest/api.html#rtrlib.records.PFXRecord
            logging.info(f'Received {len(received_roas)} ROAs via RTR from {service.service_name} in {rtr_elapsed_time} seconds')

            # are each of the TEST_ROAS items in r?
            # i.e. is the intersection of the two sets equal to that of the TEST_ROAS set?

            logging.info(f'Comparing {len(received_roas)} received ROAs to {len(TEST_ROAS)} expected ROAs...')
            expected_roas = set([roa_to_roa_string(r) for r in TEST_ROAS])
            assert received_roas == expected_roas
        except rtrlib.exceptions.SyncTimeout as e:
            logging.error(f'Timeout (>{timeout} seconds) while syncing RTR with {service.service_name} at {krill_fqdn}:{rtr_port}')
            if service.service_name == 'rpkivalidator3':
                try:
                    if not tests.util.rpkivalidator3.did_trust_anchor_validation_run_complete(krill_fqdn, 8080, 1):
                        logging.error(f'{service.service_name} initial certificate tree validation run did not yet complete')
                except Exception as innerE:
                    logging.error(f'Unable to interrogate {service.service_name} initial certificate tree validation run status: {innerE}')

            raise e
