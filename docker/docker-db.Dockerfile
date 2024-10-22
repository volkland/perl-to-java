FROM mysql:5.6
ARG SQL_SCRIPT_DIR

RUN test -n "$SQL_SCRIPT_DIR" || (echo "SQL_SCRIPT_DIR not set" && false)

# We want our own (non-volume) datadir so that changes to migrations trigger database rebuild in docker build.
# The image entrypoint.sh only runs sql scripts if the data dir is empty, and a volume persists data during build.
RUN mkdir /custom_datadir
# filename must be after mysqld.cnf to override value set there
COPY <<EOF /etc/mysql/mysql.conf.d/z-custom-datadir.cnf
[mysqld]
datadir = /custom_datadir
EOF

COPY $SQL_SCRIPT_DIR /docker-entrypoint-initdb.d
