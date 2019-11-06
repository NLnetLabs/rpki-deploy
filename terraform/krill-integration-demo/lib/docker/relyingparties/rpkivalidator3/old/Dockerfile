FROM ripencc/rpki-validator-3-docker
RUN yum install -y wget net-tools less openssh-clients
# COPY entrypoint.sh /opt/
# ENTRYPOINT ["/opt/entrypoint.sh"]
COPY krill-init.sh /opt/
COPY krill-init.service /etc/systemd/system/
RUN chmod 644 /etc/systemd/system/krill-init.service
RUN ln -s /etc/systemd/system/krill-init.service /etc/systemd/system/multi-user.target.wants/krill-init.service
RUN sed -i -e 's/WARN/DEBUG/g' /etc/rpki-validator-3/application.properties
RUN sed -i -e 's/jvm.mem.initial=1024m/jvm.mem.initial=512m/g' /etc/rpki-validator-3/application-defaults.properties
RUN sed -i -e 's/jvm.mem.maximum=1536m/jvm.mem.maximum=512m/g' /etc/rpki-validator-3/application-defaults.properties
RUN rm /var/lib/rpki-validator-3/preconfigured-tals/*