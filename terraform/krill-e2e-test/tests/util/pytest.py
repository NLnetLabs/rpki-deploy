import logging
import pprint

# Based on:
#   - https://github.com/pytest-dev/pytest/issues/230#issuecomment-223453793
#   - https://github.com/pytest-dev/pytest/issues/230#issuecomment-402580536
#   - https://github.com/pytest-dev/pytest/blob/a176ff77bc679db0305abc360434c2ca15e12165/doc/en/example/simple.rst#making-test-result-information-available-in-fixtures
# Requires pytest_runtest_makereport() function in conftest.py to create rep_call.
def isfailed(request):
    # TODO: there is no key 'call' for a failure during a fixture setup,
    # and in the case of a parameterized test the nodeid is a startswith match
    # to the first part of the key that is actually stored in the test report,
    # so there is no exact match. How do we want to detect failure in this case
    # so that we can trigger dumping of the docker logs?
    key = (request.node.nodeid, 'call')
    reports = request.node.module._test_reports
    return reports[key].outcome == 'failed' if key in reports else False
