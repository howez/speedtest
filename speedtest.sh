#!/bin/bash
LOOP="${LOOP:-true}"
LOOP_DELAY="${LOOP_DELAY:-60}"
DB_SAVE="${DB_SAVE:-false}"
DB_HOST="${DB_HOST:-http://localhost:8086}"
DB_NAME="${DB_NAME:-speedtest}"
DB_USERNAME="${DB_USERNAME:-admin}"
DB_PASSWORD="${DB_PASSWORD:-password}"
HOST="${HOST:-speedtest.chi11.us.leaseweb.net}"

run_speedtest()
{
    # Number of ping attempts
    count=4

    # Ping the host and capture the output
    ping_output=$(ping -c $count $HOST)
    output=$(iperf3 -c $HOST -p 5201-5210 -P 20 -J)

    # Extract relevant data from the ping output
    packets_transmitted=$(echo "$ping_output" | grep 'packets transmitted' | awk '{print $1}')
    packets_received=$(echo "$ping_output" | grep 'packets transmitted' | awk '{print $4}')


    min_latency=$(echo "$ping_output" | grep 'min/avg/max' | awk -F'/' '{print $4}')
    avg_latency=$(echo "$ping_output" | grep 'min/avg/max' | awk -F'/' '{print $5}')
    max_latency=$(echo "$ping_output" | grep 'min/avg/max' | awk -F'/' '{print $6}')

    sum_sent_bps=$(echo "$output" | jq '.end.sum_sent.bits_per_second')
    sum_received_bps=$(echo "$output" | jq '.end.sum_received.bits_per_second')

    sum_sent_gbps=$(echo "scale=2; $sum_sent_bps / 1000000000" | bc)
    sum_received_gbps=$(echo "scale=2; $sum_received_bps / 1000000000" | bc)

    # Format the extracted data as JSON
    json_output=$(cat <<EOF
{
    "host": "$HOST",
    "packets_transmitted": $packets_transmitted,
    "packets_received": $packets_received,
    "min_latency_ms": $min_latency,
    "avg_latency_ms": $avg_latency,
    "max_latency_ms": $max_latency,
    "upload": $sum_sent_gbps,
    "download": $sum_received_gbps
}
EOF
)

# Output the JSON
echo "$json_output"

    if $DB_SAVE; 
    then
        echo "Saving values to database..."
        curl -s -S -XPOST "$DB_HOST/write?db=$DB_NAME&precision=s&u=$DB_USERNAME&p=$DB_PASSWORD" \
            --data-binary "download,host=$HOSTNAME value=$DOWNLOAD $DATE"
        curl -s -S -XPOST "$DB_HOST/write?db=$DB_NAME&precision=s&u=$DB_USERNAME&p=$DB_PASSWORD" \
            --data-binary "upload,host=$HOSTNAME value=$UPLOAD $DATE"
        curl -s -S -XPOST "$DB_HOST/write?db=$DB_NAME&precision=s&u=$DB_USERNAME&p=$DB_PASSWORD" \
            --data-binary "ping,host=$HOSTNAME value=$min_latency $DATE"
        curl -s -S -XPOST "$DB_HOST/write?db=$DB_NAME&precision=s&u=$DB_USERNAME&p=$DB_PASSWORD" \
            --data-binary "ping_avg,host=$HOSTNAME value=$avg_latency $DATE"
        curl -s -S -XPOST "$DB_HOST/write?db=$DB_NAME&precision=s&u=$DB_USERNAME&p=$DB_PASSWORD" \
            --data-binary "ping_max,host=$HOSTNAME value=$max_latency $DATE"
        echo "Values saved."
    fi
}


if $LOOP;
then
    while :
    do
        run_speedtest
        echo "Running next test in ${LOOP_DELAY}s..."
        echo ""
        sleep $LOOP_DELAY
    done
else
    run_speedtest
fi

