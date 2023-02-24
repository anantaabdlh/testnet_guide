#!/bin/bash

GREEN="\e[32m"
LIGHT_GREEN="\e[92m"
YELLOW="\e[33m"
DEFAULT="\e[39m"

function install_node {
   echo "*********************"
   echo -e "\e[1m\e[33m	WARNING!!!! THIS NODE IS INSTALLED IN PORT 14657!!!!\e[0m"
   echo "*********************"
   echo -e "\e[1m\e[32m	Enter your Node Name:\e[0m"
   echo "_|-_|-_|-_|-_|-_|-_|"
   read MONIKER
   echo "_|-_|-_|-_|-_|-_|-_|"
   echo export MONIKER=${MONIKER} >> $HOME/.bash_profile
   source ~/.bash_profile


    echo "Installing Depencies..."
    sudo apt update
    sudo apt install curl tar wget tmux htop net-tools clang pkg-config libssl-dev jq build-essential git make ncdu -y
    
    echo "Installing GO..."
	sudo rm -rf /usr/local/go
	curl -Ls https://go.dev/dl/go1.19.5.linux-arm64.tar.gz | sudo tar -xzf - -C /usr/local
	eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
	eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
    
    echo "Downloading and building binaries..."
    cd $HOME
    rm -rf planq
    git clone https://github.com/planq-network/planq.git
    cd planq
    git fetch
 
    echo "Build binaries.."
    git checkout v1.0.2
    make build
	mkdir -p $HOME/.planqd/cosmovisor/genesis/bin
	mkdir -p ~/.planqd/cosmovisor/upgrades
	cp ~/go/bin/planqd ~/.planqd/cosmovisor/genesis/bin
    
    echo "Install and building Cosmovisor..."
    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.4.0

# Create service
sudo tee /etc/systemd/system/planqd.service > /dev/null << EOF
[Unit]
Description=planq-mainnet node service
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.planqd"
Environment="DAEMON_NAME=planqd"
Environment="UNSAFE_SKIP_BACKUP=true"

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable planqd

    # Create application symlinks
    sudo ln -s $HOME/.planqd/cosmovisor/genesis $HOME/.planqd/cosmovisor/current
    sudo ln -s $HOME/.planqd/cosmovisor/current/bin/planqd /usr/local/bin/planqd
    
    echo "Configuring Node..."
    # Set node configuration
   planqd config chain-id planq_7070-2
   planqd config keyring-backend file
   planqd config node tcp://localhost:14657

   # Initialize the node
   planqd init $MONIKER --chain-id planq_7070-2

   # Download genesis and addrbook
   wget https://raw.githubusercontent.com/planq-network/networks/main/mainnet/genesis.json
   mv genesis.json ~/.planqd/config/
   wget -O $HOME/.planqd/config/addrbook.json "https://raw.githubusercontent.com/elangrr/testnet_guide/main/planq/addrbook.json"


   # Add seeds
seeds=`curl -sL https://raw.githubusercontent.com/planq-network/networks/main/mainnet/seeds.txt | awk '{print $1}' | paste -s -d, -`
sed -i.bak -e "s/^seeds =.*/seeds = \"$seeds\"/" ~/.planqd/config/config.toml
sed -i 's/max_num_inbound_peers =.*/max_num_inbound_peers = 100/g' $HOME/.planqd/config/config.toml
sed -i 's/max_num_outbound_peers =.*/max_num_outbound_peers = 100/g' $HOME/.planqd/config/config.toml
   
   # Set minimum gas price and timeout commit and peers
   sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.025aplanq\"|" $HOME/.planqd/config/app.toml
	
   # Set Indexer Null
   indexer="null" && \
   sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.planqd/config/config.toml
   
   # Set pruning
   sed -i -e "s|^pruning *=.*|pruning = \"custom\"|" $HOME/.planqd/config/app.toml
   sed -i -e "s|^pruning-keep-recent *=.*|pruning-keep-recent = \"100\"|" $HOME/.planqd/config/app.toml
   sed -i -e "s|^pruning-keep-every *=.*|pruning-keep-every = \"0\"|" $HOME/.planqd/config/app.toml
   sed -i -e "s|^pruning-interval *=.*|pruning-interval = \"19\"|" $HOME/.planqd/config/app.toml

   # Set custom ports
   sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:14658\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:14657\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:14060\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:14656\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":14660\"%" $HOME/.planqd/config/config.toml
   sed -i.bak -e "s%^address = \"tcp://0.0.0.0:1417\"%address = \"tcp://0.0.0.0:14317\"%; s%^address = \":8080\"%address = \":14080\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:14090\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:14091\"%; s%^address = \"0.0.0.0:8545\"%address = \"0.0.0.0:14545\"%; s%^ws-address = \"0.0.0.0:8546\"%ws-address = \"0.0.0.0:14546\"%" $HOME/.planqd/config/app.toml

   echo "Starting Node..."
   sudo systemctl start planqd && journalctl -u planqd -f --no-hostname -o cat

}

function check_logs {

    sudo journalctl -fu planqd -o cat
}

function create_wallet {
    echo "Creating your wallet.."
    sleep 2
    
    planqd keys add wallet
    
    sleep 3
    echo "SAVE YOUR MNEMONIC!!!"


}

function state_sync {
   echo " SOON... "
 
}

function sync_snapshot {
sudo systemctl stop planqd
cp $HOME/.planqd/data/priv_validator_state.json $HOME/.planqd/priv_validator_state.json.backup
rm -rf $HOME/.planqd/data

curl -L https://snapshot.archieve-planq.indonode.net/planq-snapshot.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.planqd
mv $HOME/.planqd/priv_validator_state.json.backup $HOME/.planqd/data/priv_validator_state.json

sudo systemctl restart planqd && journalctl -u planqd -f --no-hostname -o cat

}

function delete_node {
echo "BACKUP YOUR NODE!!!"
echo "Deleting node in 3 seconds"
sleep 3
cd $HOME
sudo systemctl stop planqd
sudo systemctl disable planqd
sudo rm /etc/systemd/system/planqd.service
sudo systemctl daemon-reload
sudo rm -rf $(which planqd) 
sudo rm -rf $HOME/.planqd
sudo rm -rf $HOME/planq
echo "Node has been deleted from your machine :)"
sleep 3
}

function select_option {
    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

function print_logo {
    echo -e $LIGHT_GREEN
    echo "██ ███    ██ ██████   ██████  ███    ██  ██████  ██████  ███████ ";
    echo "██ ████   ██ ██   ██ ██    ██ ████   ██ ██    ██ ██   ██ ██      ";
    echo "██ ██ ██  ██ ██   ██ ██    ██ ██ ██  ██ ██    ██ ██   ██ █████   ";
    echo "██ ██  ██ ██ ██   ██ ██    ██ ██  ██ ██ ██    ██ ██   ██ ██      ";
    echo "██ ██   ████ ██████   ██████  ██   ████  ██████  ██████  ███████ ";
    echo "                                                                 ";
    echo -e $DEFAULT
}

function main {
    cd $HOME

    print_logo

    echo "Indonode Node Installer CLI (Planq Mainnet Port 14)"
    echo "Choose the command you want to use:"

    options=(
        "Install Planq Node Port 14"
        "Check Logs"
        "Create wallet"
        "Sync Via State-sync (X) "
        "Sync Via Snapshot   (✓) "
        "Delete Node"
        "Exit"
    )

    select_option "${options[@]}"
    choice=$?
    clear

    case $choice in
        0)
            install_node
            ;;
        1)
            check_logs
            ;;
        2)
            create_wallet
            ;;    
        3)
            state_sync
            ;;
        4)
            sync_snapshot
            ;;
        5)
            delete_node
            ;;    
        6)
            exit 0
            ;;
    esac

    echo -e $DEFAULT
}

main
