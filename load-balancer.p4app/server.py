import sys
import socket

HOST = '0.0.0.0'  
PORT = 5555       
debug_info = b"" if len(sys.argv)<2 else b" "+sys.argv[1].encode()

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((HOST, PORT))
print("Server listening on",HOST,":",PORT,"...")

while True:
    data, address = sock.recvfrom(1024)
    print("Received message from",address,":",data)
    sock.sendto(data[::-1]+debug_info, address)
