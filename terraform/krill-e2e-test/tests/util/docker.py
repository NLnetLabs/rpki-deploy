import logging
import os
import pytest

from time import time
from compose.project import Project
from compose.service import ImageType
from compose.cli.docker_client import docker_client
from compose.config import config

from tests.util.collections import isiterable
from tests.util.pytest import isfailed


def get_container_logs(docker_project, service_name, prefix=True,
    timestamps=True, since=None, until=None):

    # fetch and convert the log stream to a collection of UTF-8 log strings
    binary_log_output = docker_project.client.logs(
        service_name, timestamps=timestamps, since=since, until=until)
    one_long_log_str = str(binary_log_output, 'utf-8')
    log_lines = one_long_log_str.split('\n')

    if prefix:
        log_lines = [f'{service_name}: {line}' for line in log_lines]

    return log_lines


def run_command(docker_project, service_name, cmd):
    exec_id = docker_project.client.exec_create(service_name, cmd)['Id']
    output = docker_project.client.exec_start(exec_id)
    exit_code = docker_project.client.exec_inspect(exec_id).get("ExitCode")
    return (exit_code, output)


class ServiceManager:
    def __init__(self, request):
        self.start_time = int(time())
        self.docker_project = None
        self.request = request
        self.service_names = []
        self.passed = False

    def start_services_with_dependencies(self, docker_project, service_names):
        self.docker_project = docker_project
        self.service_names = service_names if isiterable(service_names) else [service_names]
        logging.info(f'Starting Docker services {self.service_names}...')
        self.docker_project.up(service_names=self.service_names)
        logging.info(f'Active containers: {[c.name for c in self.docker_project.containers()]}')

    def teardown(self):
        self.end_time = int(time())

        all_service_names = [
            s.name for s in self.docker_project.get_services(
                service_names=self.service_names, include_deps=True)]

        if isfailed(self.request):
            for service_name in all_service_names:
                container_logs = os.linesep.join(
                    get_container_logs(
                        self.docker_project,
                        service_name,
                        since=self.start_time,
                        until=self.end_time))
                logging.warn(f'Test failed, dumping logs for Docker service {service_name}:{os.linesep}{container_logs}')

        logging.info(f'Killing and removing services: {all_service_names}')
        self.docker_project.kill(service_names=all_service_names)
        self.docker_project.remove_stopped()


def get_docker_host_fqdn():
    return os.getenv('KRILL_FQDN')


@pytest.fixture()
def docker_host_fqdn():
    return get_docker_host_fqdn()


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


@pytest.fixture(scope="class")
def class_service_manager(request):
    mgr = ServiceManager(request)
    yield mgr
    mgr.teardown()


@pytest.fixture(scope="function")
def function_service_manager(request):
    mgr = ServiceManager(request)
    yield mgr
    mgr.teardown()