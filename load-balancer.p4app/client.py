import sys
import socket

SERVER_HOST = '10.0.0.5'
SERVER_PORT = 5555
if len(sys.argv)>1:
    SERVER_HOST = sys.argv[1]
if len(sys.argv)>2:
    test_input = [ l.strip() for l in open(sys.argv[2]) ]
else:
    test_input = None


client_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
while True:
    if test_input is None:
        text = input("> ")
    else:
        text = test_input.pop(0)
    if text=='quit':
        break
    print("Sending              : ",text)
    client_socket.sendto(text.encode(), (SERVER_HOST, SERVER_PORT))
    response, server_address = client_socket.recvfrom(1024)
    print("Response from server : ", response.decode())
