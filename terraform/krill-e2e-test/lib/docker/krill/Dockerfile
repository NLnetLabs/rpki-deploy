ARG BASE_IMG
FROM ${BASE_IMG}

RUN echo "BASE_IMG=${BASE_IMG}"
RUN apk add opensc rsyslog softhsm
RUN softhsm2-util --init-token --slot 0 --label "My token 1" --pin 1234 --so-pin 1234
RUN sed -i -e 's/log.level = ERROR/log.level = DEBUG/' /etc/softhsm2.conf
RUN pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --pin 1234 --list-objects