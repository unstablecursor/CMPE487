#!/bin/bash 

discovery(){
    type=0
    local my_ip=`ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
    sender_name=$1
    echo "$type;$my_ip;$sender_name;0;0"
    base='192.168.5.'
    for i in `seq 2 254`;do
        echo "$type;$my_ip;$sender_name;0;0" | nc -G 1 "$base"$i 5000 &
    done 
}

be_discoverable(){
    local my_ip=`ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
    sender_name=$1
    while true;do
        local request=$(nc -l 5000)
        local type=$(echo $request | cut -d';' -f1)
        local client_ip_=$(echo $request | cut -d';' -f2)
        local client_name=$(echo $request | cut -d';' -f3)
        if [$type -eq 0]
        then
            echo "1;$my_ip;$sender_name;$client_ip_;$client_name" | nc -G 1 $client_ip_ 5000 &
            echo "$client_ip_;$client_name" >> client_list.txt
        fi
        if [$type -eq 1]
        then
            echo "$client_ip_;$client_name" >> client_list.txt
        fi
    done
}

recieve_message(){
    while true;do
        local request=$(nc -l 5001)
        local sender_ip=$(echo $request | cut -d';' -f1)
        local cyper=$(echo $request | cut -d';' -f2)
        local msg=$(echo $request | cut -d';' -f3)
        let "lines=lines+1"
        touch "$sender_ip.txt"
        echo $msg >> "$sender_ip.txt"
        print_msg $sender_ip $msg
    done
}

print_msg(){
    if [ "$1" = $client_ip ]; then
        echo $2
    fi
}
# send_message(){
#     local my_ip=`ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
#     #local cyper=2
#     echo "1;$my_ip;$1" | nc -G 1 $2 5001 &
# }

lines=0
my_ip=`ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
client_ip="0.0.0.0"
echo "Enter your nick:"
read nick
be_discoverable $nick &
discovery $nick
sleep 2
recieve_message &
while true; do
    lines=$(cat -n client_list.txt)
    echo $lines
    echo "To close the program enter SIGKILL"
    read number
    if [ "$number" = "SIGEXIT" ]; then
        break
    fi
    client_info=$(sed "${number}q;d" client_list.txt)
    client_ip=$(echo $client_info | cut -d';' -f1)
    echo $client_ip
    lines=0
    echo "To exit the room, type SIGEXIT"
    touch "$client_ip.txt"  
    while true; do     
        read msg
        if [ "$msg" = "SIGEXIT" ]; then
            break
        fi
        incom=$(tail -"$lines" "$client_ip.txt")
        echo $incom
        echo "$my_ip;1;$msg" | nc -G 1 "$client_ip" 5001 &
    done
done
