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