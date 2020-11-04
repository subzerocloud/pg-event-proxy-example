#!/bin/sh
# wait-for-postgres.sh

set -e
  
host="$1"
port="$2"
shift
shift
shift
cmd="$@"
  
until nc -zw10 $host $port; do
  >&2 echo "tcp://$host:$port unavailable - sleeping"
  sleep 1
done
  
>&2 echo "tcp://$host:$port - executing command"
exec $cmd

