#!/bin/bash

# Get the absolute directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

items=(
"share/jive/jive/JiveMain.lua" 
"share/jive/jive/RemoteControlServer.lua" 
"share/jive/jive/ui/Framework.lua" 
"share/jive/jive/net/SocketTcpServer.lua" 
"share/jive/applets/SlimBrowser/Volume.lua" 
"share/jive/applets/Clock/ClockApplet.lua" 
"share/jive/applets/NowPlaying/NowPlayingApplet.lua" 
)

# Define a subroutine
process_item() {
    local item=$1
    echo "Processing $item"
	sudo rm /opt/jivelite/${item}
	sudo ln -s /tmp/tcloop/pcp-jivelite/opt/jivelite/${item} /opt/jivelite/${item}
}

# Iterate through the list and call the subroutine for each item
for item in "${items[@]}"; do
    process_item "$item"
done

sudo cp -Rf $SCRIPT_DIR/jivelite/* /opt/jivelite

#sudo cp -f $SCRIPT_DIR/jivelite/bin/jivelite.sh /opt/jivelite/bin

sudo rm /tmp/jivelite*.bmp
sudo rm $HOME/jivelite*.bmp
sudo rm /var/log/jivelite.log
