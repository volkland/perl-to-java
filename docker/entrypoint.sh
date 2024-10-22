#!/bin/bash

set -u

JAVA_HOME=/usr/lib/jvm/zulu21
PATH=/usr/lib/jvm/zulu21/bin:$PATH

ulimit_n=$(ulimit -n)
if [ ${ulimit_n} -lt 4096 ]; then
  echo "[entrypoint] ERROR: number of open files is limited to ${ulimit_n} which is below 4096 as recommended by wildfly; aborting"
  exit 1
fi

echo "[entrypoint] INFO: running in environment='${ENV}'"

# note: secrets are passed directly via env
. /variables.${ENV}

for template_path in $(find / -type f -name "*.tmpl" 2>/dev/null); do
  new_path=$(echo $template_path | sed 's/.tmpl$//')

  echo "[entrypoint] replacing variables in $template_path ..."

  # using https://github.com/a8m/envsubst for --no-unset option
  envsubst --no-unset < $template_path > $new_path
  if [ $? -ne 0 ]; then
    echo "[entrypoint] ERROR: substituting from env failed; aborting"
    exit 1
  fi;

  echo "[entrypoint] DEBUG: successfully wrote '$new_path'"
done

ENABLE_REMOTE_DEBUGGING="${ENABLE_REMOTE_DEBUGGING:-false}"

DEBUGGING_ENV_REGEX="^(local|e2e)$"
if [ "$ENABLE_REMOTE_DEBUGGING" = 'true' ] && ! [[ $ENV =~ $DEBUGGING_ENV_REGEX ]]; then
  echo "[entrypoint] ERROR: Remote Debugging enabled in ENV=$ENV. Allowed ENVs: $DEBUGGING_ENV_REGEX"
  exit 1
fi

REMOTE_DEBUGGING_JAVA_OPTION=""

if [ "$ENABLE_REMOTE_DEBUGGING" = 'true' ]; then
  REMOTE_DEBUGGING_JAVA_OPTION="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=0.0.0.0:5005"
fi

echo "[entrypoint] DEBUG: REMOTE_DEBUGGING_JAVA_OPTION = '$REMOTE_DEBUGGING_JAVA_OPTION'"

ENABLE_CODE_COVERAGE="${ENABLE_CODE_COVERAGE:-false}"

if [ "$ENABLE_CODE_COVERAGE" = 'true' ] && [ "$ENV" = 'live' ]; then
  echo "[entrypoint] ERROR: Code Coverage is forbidden in live environment"
  exit 1
fi

CODE_COVERAGE_JAVA_OPTION=""

if [ "$ENABLE_CODE_COVERAGE" = 'true' ]; then
  # prepare deployment of jolokia war to enable convenient triggering of mbean dump for jacoco coverage report (see: jacoco-coverage.sh)
  cp /jolokia.war /opt/wildfly/standalone/deployments

  CODE_COVERAGE_JAVA_OPTION='-javaagent:/jacoco/jacocoagent.jar=destfile=/coverage/jacoco.exec,jmx=true'
fi
rm /jolokia.war

WILDFLY_BIND_SETTINGS="-b=0.0.0.0"

if [[ "$ENV" =~ $DEBUGGING_ENV_REGEX ]]; then
  echo '[entrypoint] DEBUG: enabling wildfly management web-interface at http://localhost:9990 '
  WILDFLY_BIND_SETTINGS="${WILDFLY_BIND_SETTINGS} -bmanagement=0.0.0.0"
fi

echo "[entrypoint] DEBUG: CODE_COVERAGE_JAVA_OPTION = '$CODE_COVERAGE_JAVA_OPTION'"

JBOSS_LOGMANAGER_BOOT_CLASSPATH=$(find /opt/wildfly/modules/system/layers/base/org/jboss/logmanager/main -type f -name "jboss-logmanager-*.jar")
echo "[entrypoint] DEBUG: JBOSS_LOGMANAGER_BOOT_CLASSPATH = '${JBOSS_LOGMANAGER_BOOT_CLASSPATH}'"

WILDFLY_COMMON_BOOT_CLASSPATH=$(find /opt/wildfly/modules/system/layers/base/org/wildfly/common/main -type f -name "wildfly-common-*.jar")
echo "[entrypoint] DEBUG: WILDFLY_COMMON_BOOT_CLASSPATH = '${WILDFLY_COMMON_BOOT_CLASSPATH}'"

echo "########################"
echo "### starting wildfly ###"
echo "########################"

JAVA_OPTS=""
JAVA_OPTS="${JAVA_OPTS} --add-opens=java.base/sun.reflect.generics.reflectiveObjects=ALL-UNNAMED"
JAVA_OPTS="${JAVA_OPTS} ${CODE_COVERAGE_JAVA_OPTION}"
JAVA_OPTS="${JAVA_OPTS} ${REMOTE_DEBUGGING_JAVA_OPTION}"
JAVA_OPTS="${JAVA_OPTS} ${WILDFLY_MEMORY_SETTINGS}"
JAVA_OPTS="${JAVA_OPTS} -server"
JAVA_OPTS="${JAVA_OPTS} -Duser.timezone=UTC"
JAVA_OPTS="${JAVA_OPTS} -Dfile.encoding=UTF-8"
JAVA_OPTS="${JAVA_OPTS} -Dfile.io.encoding=UTF-8"
JAVA_OPTS="${JAVA_OPTS} -DjavaEncoding=UTF-8"
JAVA_OPTS="${JAVA_OPTS} -Djava.net.preferIPv4Stack=true"
JAVA_OPTS="${JAVA_OPTS} -Djava.awt.headless=true"
JAVA_OPTS="${JAVA_OPTS} -Dsun.util.logging.disableCallerCheck=true"
JAVA_OPTS="${JAVA_OPTS} -Djboss.modules.system.pkgs=org.jboss.byteman,org.jboss.logmanager"
JAVA_OPTS="${JAVA_OPTS} -Dorg.jboss.logging.Logger.pluginClass=org.jboss.logging.logmanager.LoggerPluginImpl"
JAVA_OPTS="${JAVA_OPTS} -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
JAVA_OPTS="${JAVA_OPTS} -Xbootclasspath/a:${JBOSS_LOGMANAGER_BOOT_CLASSPATH}"
JAVA_OPTS="${JAVA_OPTS} -Xbootclasspath/a:${WILDFLY_COMMON_BOOT_CLASSPATH}"
JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote"
JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.authenticate=false"
JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.ssl=false"

export JAVA_OPTS

exec /opt/wildfly/bin/standalone.sh ${WILDFLY_BIND_SETTINGS} -c standalone-full.xml
