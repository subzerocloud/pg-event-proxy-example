#!/bin/bash

CUSTOM_CONFIG=$(cat <<EOF
#------------------------------------------------------------------------------
# CUSTOM SETTINGS (they override the values set above in the config)
#------------------------------------------------------------------------------

wal_level = logical
shared_preload_libraries = 'wal2json'

# log all queries
log_statement = 'all'
EOF
)

set -e
echo "${CUSTOM_CONFIG}" >> /var/lib/postgresql/data/postgresql.conf