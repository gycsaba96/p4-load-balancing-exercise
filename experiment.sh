

# start servers
p4app exec m h2 python3 /tmp/server.py h2 > /tmp/p4app_logs/h2-log.txt &
p4app exec m h3 python3 /tmp/server.py h3 > /tmp/p4app_logs/h3-log.txt &
p4app exec m h4 python3 /tmp/server.py h4 > /tmp/p4app_logs/h4-log.txt &

# start client
sleep 5
p4app exec m h1 python3 /tmp/client.py 10.0.10.2 /tmp/test-input.txt