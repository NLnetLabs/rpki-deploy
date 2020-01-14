import logging
import rtrlib


def pfxrecord_to_roa_string(r):
    return f'{r.prefix}/{r.min_len}-{r.max_len} => {r.asn}'


def roa_to_roa_string(r):
    return f'{r.prefix}-{r.max_length} => {r.asn}'


def rtr_fetch_one(host, port, timeout_seconds):
    logging.info(f'Connecting to {host}:{port} with an RTR sync timeout of {timeout_seconds} seconds...')
    mgr = rtrlib.RTRManager(host, port, retry_interval=5)

    mgr.start(wait=True, timeout=timeout_seconds)
    ipv4 = [pfxrecord_to_roa_string(r) for r in mgr.ipv4_records()]
    ipv6 = [pfxrecord_to_roa_string(r) for r in mgr.ipv6_records()]
    mgr.stop()

    return ipv4 + ipv6