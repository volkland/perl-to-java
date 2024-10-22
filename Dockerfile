FROM azul/zulu-openjdk:21.0.4 AS build

LABEL maintainer="noone :D"

RUN apt-get update && apt-get install -y maven && apt-get clean

WORKDIR /usr/src/app/

COPY maven_settings.xml ./maven_settings.xml

COPY pom.xml ./pom.xml
COPY java-wrapper/pom.xml java-wrapper/pom.xml
COPY java-ear/pom.xml java-ear/pom.xml
COPY java-war/pom.xml java-war/pom.xml
COPY perlapp-ejb/pom.xml perlapp-ejb/pom.xml
COPY java-war/jars/ejb-3.1.jar java-war/jars/ejb-3.1.jar
COPY perlapp-ejb/jars/ejb-3.1.jar perlapp-ejb/jars/ejb-3.1.jar

COPY java-wrapper/src java-wrapper/src
COPY java-war/src java-war/src
COPY perlapp-ejb/src perlapp-ejb/src


# build (only, tests run in extra test step of pipeline!)
RUN --mount=type=cache,target=/root/.m2 mvn -s ./maven_settings.xml -f ./pom.xml -P '!code-format' package -DskipTests -Dmaven.test.skip

FROM azul/zulu-openjdk-debian:21.0.4

# Install curl
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# install wildfly
RUN curl -L https://download.jboss.org/wildfly/24.0.1.Final/wildfly-24.0.1.Final.tar.gz -o /tmp/wildfly.tar.gz
RUN mkdir /opt/wildfly && tar -xzf /tmp/wildfly.tar.gz --directory=/opt/wildfly --strip-components=1 && rm /tmp/wildfly.tar.gz

# jacoco agent for code coverage
# downloaded from: https://repo1.maven.org/maven2/org/jacoco/org.jacoco.agent/0.8.11/
COPY docker/org.jacoco.agent-0.8.11-runtime.jar /jacoco/jacocoagent.jar
RUN mkdir /coverage && chown -R 40001 /coverage

# envsubst from curl -L https://github.com/a8m/envsubst/releases/download/v1.2.0/envsubst-`uname -s`-`uname -m` as static file
COPY docker/envsubst /usr/local/bin/
RUN chmod +x /usr/local/bin/envsubst

# Provision service wrapper.conf
RUN chown -R 40001 /usr/local/etc/

# Provision users
COPY docker/config-templates/mgmt-users.properties.tmpl /opt/wildfly/standalone/configuration/

# seems like the properties files and respective standalone-full configuration must exist
RUN echo "" > /opt/wildfly/standalone/configuration/application-users.properties
RUN echo "" > /opt/wildfly/standalone/configuration/application-roles.properties

# Deploy configuration module base structure
COPY docker/modules/sippy/module.xml /opt/wildfly/modules/system/layers/base/com/sippy/configuration/main/
COPY docker/modules/mysql /opt/wildfly/modules/system/layers/base/com/mysql/main/

# downloaded from: https://mvnrepository.com/artifact/org.jolokia/jolokia-war-unsecured/1.7.2
COPY docker/jolokia-war-unsecured-1.7.2.war /jolokia.war

# set user permissions
RUN chown -R 40001 /opt/wildfly/standalone/
RUN chown -R 40001 /opt/wildfly/modules/system/layers/base/com/sippy/configuration/
RUN chown -R 40001 /usr/local/etc/

# Provision configuration module - Expose HttpHandler to applications
RUN sed -i -r "s/(\s*)(<\/paths>)/\1    <path name=\"com\/sun\/net\/httpserver\"\/>\n\1\2/g" /opt/wildfly/modules/system/layers/base/sun/jdk/main/module.xml

# Configure wildfly for number-porting-service - standalone-full.xml
COPY docker/config-templates/standalone-full.xml.tmpl /opt/wildfly/standalone/configuration/standalone-full.xml.tmpl

# Deploy the actual thing:
COPY --from=build /usr/src/app/java-ear/target/java-service.ear /opt/wildfly/standalone/deployments

# ports to be reachable from outside:
# portd
EXPOSE 3360/tcp
# war
EXPOSE 8080/tcp
# wrapper
EXPOSE 8099/tcp
# wildfly management
EXPOSE 9990/tcp

COPY docker/entrypoint.sh /
COPY docker/variables.* /

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
