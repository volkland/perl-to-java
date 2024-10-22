#!/bin/sh

# Check if coverage tools are installed and set the environment variable
if [ -n "$(which cover)" ]; then
  echo "Running with coverage enabled"
    HARNESS_PERL_SWITCHES=-MDevel::Cover=+select,all perl /root/daemon/script/perlapp.pl daemon -m production -l http://*:13360 && cover -report html
else
  echo "Running without coverage"
  perl /root/daemon/script/perlapp.pl daemon -m production -l http://*:13360
fi