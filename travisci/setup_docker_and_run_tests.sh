#!/bin/bash

## This script has to run as root because "/sbin/my_init" (the init system
## of the Docker image) does things that require root permissions

# Stop the script at the first failure
set -e

echo "DEBUG: Environment of $0"; env; id; echo "END_DEBUG"

# It seems that non-root users cannot execute anything from /home/travis
# so we copy the whole directory for the sgeuser user
SGEUSER_HOME=/home/sgeuser
cp -a /home/travis/build/Ensembl/ensembl-hive-sge $SGEUSER_HOME
SGE_CHECKOUT_LOCATION=$SGEUSER_HOME/ensembl-hive-sge
chown -R sgeuser: $SGE_CHECKOUT_LOCATION
HIVE_CHECKOUT_LOCATION=$SGE_CHECKOUT_LOCATION/ensembl-hive

# Install extra packages inside the container
export DEBIAN_FRONTEND=noninteractive
$HIVE_CHECKOUT_LOCATION/docker/setup_os.Ubuntu-16.04.sh
$SGE_CHECKOUT_LOCATION/scripts/ensembl-hive-sge/setup_os.Ubuntu-16.04.sh
$HIVE_CHECKOUT_LOCATION/docker/setup_cpan.Ubuntu-16.04.sh $HIVE_CHECKOUT_LOCATION $SGE_CHECKOUT_LOCATION

sudo --login -u sgeuser $SGE_CHECKOUT_LOCATION/travisci/run_tests.sh

