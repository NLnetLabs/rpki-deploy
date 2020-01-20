import requests


def did_trust_anchor_validation_run_complete(fqdn, port, ta_index):
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
    return (requests.get(f'http://{host}:{port}/api/trust-anchors/1').
        json()['data']['initialCertificateTreeValidationRunCompleted'])