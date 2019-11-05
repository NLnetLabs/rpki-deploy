FROM debian
RUN apt-get update && apt-get -y install wget
WORKDIR /tmp
RUN wget https://github.com/NICMx/FORT-validator/releases/download/v1.1.0/fort_1.1.0-1_amd64.deb
RUN apt install -y --no-install-recommends ./fort_1.1.0-1_amd64.deb
COPY --from=relyingpartybase /opt/my_funcs.sh /opt/my_funcs.sh
COPY entrypoint.sh /opt/
WORKDIR /
ENTRYPOINT ["/opt/entrypoint.sh"]