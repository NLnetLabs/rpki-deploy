import logging
import pytest


# Store test reports in the Python module object for later access.
# Based on:
#   - https://github.com/pytest-dev/pytest/issues/230#issuecomment-223453793
#   - https://github.com/pytest-dev/pytest/issues/230#issuecomment-402580536
#   - https: // github.com / pytest - dev / pytest / blob / a176ff77bc679db0305abc360434c2ca15e12165 / doc / en / example / simple.rst  #making-test-result-information-available-in-fixtures
# See: pytest.py::isfailed() which uses the data stored by this hook
@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    # execute all other hooks to obtain the report object
    outcome = yield
    rep = outcome.get_result()

    # rep.when can be:  "setup", "call", or "teardown"
    # rep is of type TestReport

    _test_reports = getattr(item.module, '_test_reports', {})
    _test_reports[(item.nodeid, rep.when)] = rep
    item.module._test_reports = _test_reports


# Ensure that parametrized tests are named to our liking, e.g. a RelyingParty
# object as a value for a parametrized argument called 'service' would cause
# the test name to end with service0, service1, etc. By using repr() and
# implementing __str__() on RelyingParty the class can control its name when
# used in such cases.
def pytest_make_parametrize_id(config, val):
    return str(val)


@pytest.mark.optionalhook
def pytest_metadata(metadata):
    # Remove JAVA_HOME information automatically added by pytest-metadata to
    # the HTML report "Environment" section as it is irrelevant and confusing
    # for the Krill E2E test.
    metadata.pop("JAVA_HOME", None)