#!/bin/bash

NETWORK=pg-event-proxy-example_default
function clean_up {

    echo "Stopping all background processed"
    docker stop -t 1 redis-monitor > /dev/null 2>&1
    docker stop -t 1 rabbitmq-monitor > /dev/null 2>&1
    docker stop -t 1 mosquitto-monitor > /dev/null 2>&1
    kill -9 $REDIS_MONITOR_PID > /dev/null 2>&1
    kill -9 $RABBITMQ_MONITOR_PID > /dev/null 2>&1
    kill -9 $MOSQUITTO_MONITOR_PID > /dev/null 2>&1
    
    echo "done"
    exit
}

trap clean_up SIGHUP SIGINT SIGTERM


echo "starting even monitoring on redis, rabbitmq, mqtt. Press [CTRL+C] to stop..."
docker run --network $NETWORK --name redis-monitor --rm redis:alpine \
    redis-cli -h redis -a pass monitor  | awk -vFPAT='([^ ]*)|("[^"]+")' -vOFS=, '{print "[redis-monitor] " $6}'&
REDIS_MONITOR_PID=$!

docker run --network $NETWORK --name rabbitmq-monitor --rm \
    -e AMQP_HOST=rabbitmq \
    -e AMQP_USER=user \
    -e AMQP_PASSWORD=pass \
    -e EXCHANGE=amq.topic \
    -e AMQP_QUEUE=monitor \
    -e AMQP_QUEUE_DURABLE=false \
      subzerocloud/amqptools | awk '{print "[rabbitmq-monitor] " $0}' &
RABBITMQ_MONITOR_PID=$!

docker run --network $NETWORK --name mosquitto-monitor --rm \
      eclipse-mosquitto \
      /usr/bin/mosquitto_sub \
      -h mosquitto -p 1883 -u user -P pass \
      --topic 'events' | awk '{print "[mosquitto-monitor] " $0}'&
MOSQUITTO_MONITOR_PID=$!



wait $REDIS_MONITOR_PID
wait $RABBITMQ_MONITOR_PID
wait $MOSQUITTO_MONITOR_PID