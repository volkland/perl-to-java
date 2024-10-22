FROM debian:bullseye

ARG INSTALL_COVERAGE_TOOLS=false

RUN apt-get update -y && apt-get install -y \
    perl-base \
    procps \
    git \
    make gcc \
    default-libmysqlclient-dev \
    libdbd-mysql-perl \
    && apt-get clean

# Install cpanminus (cpanm)
RUN cpan install App::cpanminus

# Install Perl modules without running tests
RUN cpanm --notest Log::Log4perl Mojolicious JSON Config::Simple
RUN cpanm --notest DBI
RUN cpanm --notest DBD::mysql@4.050

# Verify DBD::mysql installation
RUN perl -MDBD::mysql -e 'print "DBD::mysql is installed\n"' || echo "DBD::mysql installation failed"


RUN if [ "$INSTALL_COVERAGE_TOOLS" = "true" ]; then \
    cpan App::cpanminus && \
    cpanm Devel::Cover Pod::Coverage Devel::CheckLib Test::Differences Sereal && \
    echo "Installed Perl coverage tools"; \
    else \
    echo "Skipping Perl coverage tools installation"; \
    fi

# Set ENV variable if coverage tools are installed
RUN if [ "$INSTALL_COVERAGE_TOOLS" = "true" ]; then \
    echo "HARNESS_PERL_SWITCHES=-MDevel::Cover" >> /etc/environment; \
    fi

COPY lib /root/daemon/lib
COPY script /root/daemon/script

COPY docker/e2e/perlapp.conf /usr/local/etc/perlapp/perlapp.conf
COPY docker/logger.conf /usr/local/etc/perlapp/logger.conf

COPY docker/e2e/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

## Tool to convert Perl reports to LCOV format
RUN if [ "$INSTALL_COVERAGE_TOOLS" = "true" ]; then \
    git clone https://github.com/linux-test-project/lcov.git /root/daemon/lcov && \
    cd /root/daemon/lcov && \
    git checkout d465f73 && \
    make install && \
    rm -rf /root/daemon/lcov/.git; \
    fi

WORKDIR /root/daemon

EXPOSE 13360

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]