#!/bin/bash 

discovery(){
    type=0
    local chn
    chn=$(echo "$my_ip" | cut -d'.' -f1-3)
    sender_name=$1
    echo "$type;$my_ip;$sender_name;0;0"
    for i in $(seq 2 254);do
        echo "$type;$my_ip;$sender_name;0;0" | nc -G 1 "$chn.$i" 5000 &
    done 
}

decrypt_msg(){
    local vars=$(echo $1 | md5)
    if [ "$3" = "$4" ]
    then
        if [ "$vars" = "$2" ]
        then
            echo "1"
            cypher=$2
        else
            echo "0"
        fi
    fi
}

be_discoverable(){
    sender_name=$1
    while true;do
        local request
        request=$(nc -l 5000)
        local type
        type=$(echo "$request" | cut -d';' -f1)
        local client_ip_
        client_ip_=$(echo "$request" | cut -d';' -f2)
        local client_name
        client_name=$(echo "$request" | cut -d';' -f3)
        if [ "$type" = "0" ]
        then
            echo "1;$my_ip;$sender_name;$client_ip_;$client_name" | nc -G 1 "$client_ip_" 5000 &
            echo "$client_ip_;$client_name" >> client_list.txt
            delete_duplicates
        fi
        if [ "$type" = "1" ]
        then
            echo "$client_ip_;$client_name" >> client_list.txt
            delete_duplicates
        fi
    done
}

delete_duplicates(){
    var=$(awk '!a[$0]++' client_list.txt)
    echo "$var" > client_list.txt
}

recieve_message(){
    while true;do
        local request
        request=$(nc -l 5001)
        local sender_ip
        sender_ip=$(echo "$request" | cut -d';' -f1)
        touch "$sender_ip.txt"
        local cyper
        cyper=$(echo "$request" | cut -d';' -f2)
        local message
        message=$(echo "$request" | cut -d';' -f3)
        varrr=$(decrypt_msg "$cypher" "$cyper" "$sender_ip" "$client_ip")
        if [ "$varrr" = "0" ]; then
            echo "Conversation has compromised please exit immediately."
        fi
        cypher=$cyper
        echo "$message" >> "$sender_ip.txt"
    done
}

cypher="everyoneKnowingTheProtocolCanSniffAndBreakSecurityAndOurMessagesArePlainText"
pkill -f "tail -f"
pkill -f "nc -l"
rm -rf 192.168.*
my_ip=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
client_ip="0.0.0.0"
echo "Enter your nick:"
read nick
be_discoverable "$nick" &
discovery "$nick"
sleep 2
recieve_message &
while true; do
    lines=$(cat -n client_list.txt)
    echo $lines
    echo "To close the program enter SIGEXIT"
    read number
    if [ "$number" = "SIGEXIT" ]; then
        break
    fi
    client_info=$(sed "${number}q;d" client_list.txt)
    client_ip=$(echo "$client_info" | cut -d';' -f1)
    echo $client_ip   
    echo "To exit the room, type SIGEXIT"
    touch "$client_ip.txt"  
    pkill -f "tail -f"
    tail -f "$client_ip.txt" &
    while true; do     
        read msg
        if [ "$msg" = "SIGEXIT" ]; then
            break
        fi
        second_c=$(echo $cypher | md5)
        cypher=$second_c
        echo "$my_ip;$second_c;$msg" | nc -G 1 "$client_ip" 5001 &
    done
done