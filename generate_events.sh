#!/bin/bash
pg=postgres://user:pass@localhost:5432/app

function notify () {
    local pguri=$1
    local channel=$2
    local message=$3
    local query="select events.send_message('${channel}', '${message}', '', true)"
    psql -q -c "${query}" "${pguri}" > /dev/null
}

function insert () {
    local pguri=$1
    local table=$2
    local columns=name
    local message=$3
    local query="insert into ${table} ($columns) values ('$message')"
    psql -q -c "${query}" "${pguri}" > /dev/null
}


echo "starting even generation, press [CTRL+C] to stop.."

i=0
while true
do
    message="message ${i}"
    # insert $pg "foo" "${message}" # this will be seein in amqp upstream due to wal2json binding
    notify $pg "amqpchannel" "${message}"
    notify $pg "redischannel" "${message}"
    notify $pg "mqttchannel" "${message}"
    notify $pg "snschannel" "${message}"
    notify $pg "sqschannel" "${message}"
    notify $pg "lambdachannel" "${message}"
    
    echo "Event (NOTIFY/INSERT): ${message}"
    ((i++))
	sleep 1 # match development distribution delay
done
