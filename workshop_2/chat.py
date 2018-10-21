import socket
import time as t
import configs.client_config as cfg
import hashlib
import threading

CHAT_IP = "0.0.0.0"
CHATS = {}
CYPHERS = {}
IP_NAMES = {}


def handle_udp_connection(port):
    udp_server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0)
    udp_server.bind((cfg.HOST, port))
    while True:
        try:
            data, addr = udp_server.recvfrom(cfg.BUFFER_SIZE)
            if data:
                msg = data.decode().split(";")
                if msg[0] == '1':
                    if CHATS.get(msg[1]) is None:
                        CHATS[msg[1]] = []
                    IP_NAMES[msg[1]] = msg[2]
                if msg[0] == '0':
                    resp = ";".join([str(1), cfg.HOST, cfg.NICK, msg[1], msg[2]])
                    if CHATS.get(msg[1]) is None:
                        CHATS[msg[1]] = []
                    IP_NAMES[msg[1]] = msg[2]
                    udp_server.sendto(resp.encode(), addr)
        except socket.error as e:
            print("Socket error: {}".format(e))


def cypher_check(cyper, ip):
    if CYPHERS.get(ip) is None:
        rnd_string = "asdsdfdsf"
        CYPHERS[ip] = hashlib.md5(rnd_string.encode('utf-8')).hexdigest()
    ip_cypher = CYPHERS[ip]
    cypher_1up = hashlib.md5(ip_cypher.encode('utf-8')).hexdigest()
    if cyper == cypher_1up:
        CYPHERS[ip] = cypher_1up
        return True
    else:
        CYPHERS.pop(ip, None)
        CHATS.pop(ip, None)
        print("Conversation have been compromised.")
        return False


def handle_incom(port):
    udp_server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0)
    udp_server.bind((cfg.HOST, port))
    while True:
        try:
            data, addr = udp_server.recvfrom(cfg.BUFFER_SIZE)
            if data:
                msg = data.decode().split(";")
                sender_ip = msg[0]
                cypher = msg[1]
                message = msg[2]
                if cypher_check(cypher, sender_ip):
                    CHATS[sender_ip].append(IP_NAMES[sender_ip] + ": " + message)
                    if CHAT_IP == sender_ip:
                        print (IP_NAMES[sender_ip] + ": " + message)
        except socket.error as e:
            print("Socket error: {}".format(e))


def discover_udp_connection():
    udp_server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0)
    ip_addr = cfg.HOST.split(".")
    ip_base = ".".join([ip_addr[0], ip_addr[1], ip_addr[2]])
    ip_top = 1
    while ip_top < 255:
        try:
            addr = (ip_base + "." + str(ip_top), 5000)
            resp = ";".join([str(0), cfg.HOST, cfg.NICK, "0", "0"])
            udp_server.sendto(resp.encode(), addr)
        except socket.error as e:
            print("Socket error: {}".format(e))
        ip_top += 1


if __name__ == '__main__':
    print(cfg.HOST)
    sender_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sender_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0)
    hndl_udp = threading.Thread(name='handle_udp_connection', target=handle_udp_connection, args=[5000])
    hndl_udp.start()
    t.sleep(1)
    discover_udp_connection()
    t.sleep(1)
    hndl_incom = threading.Thread(name='handle_incom', target=handle_incom, args=[5001])
    hndl_incom.start()
    while True:
        for key, val in IP_NAMES.items():
            print (val)
        client_name = input("Enter a name to talk to that user: ")
        for key, val in IP_NAMES.items():
            if val == client_name:
                CHAT_IP = key
                break
        print("===Enter wq to exit===")
        for val in CHATS[CHAT_IP]:
            print(val)
        if CYPHERS.get(CHAT_IP) is None:
            rand_string = "asdsdfdsf"
            CYPHERS[CHAT_IP] = hashlib.md5(rand_string.encode('utf-8')).hexdigest()
        while True:
            msg_to_send = input()
            if msg_to_send == "wq":
                break
            CHATS[CHAT_IP].append(cfg.NICK + ": " + msg_to_send)
            cypher_to_send = hashlib.md5(CYPHERS[CHAT_IP].encode('utf-8')).hexdigest()
            # TODO: Uncomment this line to enable p2p chat.
            # CYPHERS[CHAT_IP] = cypher_to_send
            packet_to_send = ";".join([cfg.HOST, cypher_to_send, msg_to_send])
            sender_sock.sendto(packet_to_send.encode(), (CHAT_IP, 5001))
