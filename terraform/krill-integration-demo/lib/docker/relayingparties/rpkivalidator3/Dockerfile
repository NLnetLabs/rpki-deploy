FROM centos:7
RUN yum install -y java-1.8.0-openjdk-devel which rpm-build wget rsync net-tools
WORKDIR /opt/maven
RUN curl -fsSLo- 'http://ftp.nluug.nl/internet/apache/maven/maven-3/3.6.2/binaries/apache-maven-3.6.2-bin.tar.gz' | tar zx --strip-components 1
ENV PATH="/opt/maven/bin:${PATH}"
WORKDIR /tmp/build/rpki-validator-3
RUN curl -fsSLo- 'https://github.com/RIPE-NCC/rpki-validator-3/archive/v3.1.tar.gz' | tar zx --strip-components 1
RUN mvn -Dmaven.test.skip -DskipTests package
RUN cp rpki-validator/target/rpki-validator-3.1-SNAPSHOT.jar /opt/
COPY --from=relayingpartybase /opt/my_funcs.sh /opt/my_funcs.sh
COPY *.properties /etc/rpki-validator-3/
COPY *.sh /opt/
ENV JAVA_CMD=/usr/bin/java
ENV CONFIG_DIR=/etc/rpki-validator-3
ENV JAR=/opt/rpki-validator-3.1-SNAPSHOT.jar
WORKDIR /
ENTRYPOINT [ "/opt/entrypoint.sh" ]