# TODO: try out the new ripencc/rpki-validator-3-docker:alpine
# We build from sources instead of using the official Docker image because we
# (a) don't want the complexity of an RPM and SystemD based deployment inside
# a Docker container, (b) want the docker logs command to show the
# application logs, and (c) want the ability to debug the application source
# code if needed.
FROM centos:7
RUN yum install -y java-1.8.0-openjdk-devel which rpm-build wget rsync net-tools
WORKDIR /opt/maven
RUN curl -fsSLo- 'http://ftp.nluug.nl/internet/apache/maven/maven-3/3.6.2/binaries/apache-maven-3.6.2-bin.tar.gz' | tar zx --strip-components 1
ENV PATH="/opt/maven/bin:${PATH}"
WORKDIR /tmp/build/rpki-validator-3
RUN curl -fsSLo- 'https://github.com/RIPE-NCC/rpki-validator-3/archive/v3.1.tar.gz' | tar zx --strip-components 1
RUN mvn -Dmaven.test.skip -DskipTests package
RUN cp rpki-validator/target/rpki-validator-3.1-SNAPSHOT.jar /opt/
COPY --from=relyingpartybase /opt/* /opt/
COPY *.properties /etc/rpki-validator-3/
COPY *.sh /opt/
ENV JAVA_CMD=/usr/bin/java
ENV CONFIG_DIR=/etc/rpki-validator-3
ENV JAR=/opt/rpki-validator-3.1-SNAPSHOT.jar
WORKDIR /
ENTRYPOINT [ "/opt/entrypoint.sh" ]