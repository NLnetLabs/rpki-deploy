import json
import krill_ca_api
import os
import pytest

from contextlib import contextmanager
from krill_ca_api.rest import ApiException
from tests.util.docker import register_version_cmd


class KrillUnknownPublisherException(Exception):
    pass


class KrillUnknownChildException(Exception):
    pass


class KrillUnknownParentException(Exception):
    pass


class KrillUnknownCAException(Exception):
    pass


class KrillInvalidROADeltaNotAllResourcesHeldException(Exception):
    pass


@contextmanager
def enhanced_exceptions():
  try:
    yield
  except ApiException as e:
    if e.status == 404:
        krill_err_code = json.loads(e.body)['code']

        raise {
            2201: KrillUnknownPublisherException(e),
            2305: KrillUnknownChildException(e),
            2306: KrillUnknownParentException(e),
            2403: KrillInvalidROADeltaNotAllResourcesHeldException,
            2502: KrillUnknownCAException(e),
        }.get(krill_err_code, e)

    return e


@pytest.fixture(scope="module")
def krill_api_config():
    configuration = krill_ca_api.Configuration()
    configuration.access_token = os.getenv('KRILL_ADMIN_TOKEN')
    configuration.host = "https://{}/api/v1".format(os.getenv('KRILL_FQDN_FOR_TEST'))
    configuration.verify_ssl = True
    configuration.ssl_ca_cert = 'relyingparties/base/rootCA.crt'
    configuration.assert_hostname = False
    configuration.cert_file = None
    return configuration


def get_tal_url_str():
    return f'https://{os.getenv("KRILL_FQDN_FOR_TEST")}/ta/ta.tal'


def select_krill_config_file(docker_project, cfg_file_name):
    options = docker_project.get_service('krill').config_dict()["options"]
    options['command'] = ["krill", "-c", f"/krill_configs/{cfg_file_name}"]