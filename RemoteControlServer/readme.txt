Project Overview

For my project, "Voice Assistant for piCorePlayer," I aimed to provide visual feedback for specific commands such as "set a timer for 10 minutes" or "set volume to 20." To achieve this, I modified several Lua files in Jivelite on my system. I created a fork of these modifications in case others might find them useful.

Instead of generating a new pcp-squeezelite.tcz using mksquashfs, I chose to replace links to certain Lua files in /opt/jivelite/share/jive with my modified versions through /opt/bootlocal.sh.

Key Features

- Extended Jivelite functionality to interface with other applications
- Implemented a new module: RemoteControlServer.lua
- Added support for action commands via TCP/UDP port 9009
- Introduced new commands:
  - 'volume_up:<value>' (shows the big volume popup and uses <value> as the new volume)
  - 'timer:<numofseconds>' (displays countdown timer on clock screensaver and now-playing screensaver)

Implementation Details

File Structure:
- Modified Lua files located in remotecontrolserver/home/tc/.jivelite/custom/jivelite/...
- copy.sh script copies modified files to /opt/jivelite/... during boot

Modified Files
- JiveMain.lua
- RemoteControlServer.lua (new)
- Framework.lua
- SocketTcpServer.lua
- ClockApplet.lua
- NowPlayingApplet.lua
- Volume.lua

System Specifications:
- Raspberry Pi 3B+
- 32-bit piCorePlayer installation
- HiFiBerry AMP2
- Raspberry Pi 7" Touchscreen
  
Software Versions:
- piCorePlayer v7.0.0
- www v00011
- Linux 5.4.83-pcpCore-v7
- piCore v12.0pCP
- Squeezelite v1.9.9-1386-pCP

While this setup may be somewhat outdated, it remains stable, so I have no need to update it.

My pcp-jivelite.tcz is the same as the one found at https://repo.picoreplayer.org/repo/12.x/armv7/tcz/.

Here’s my onboot.lst:

VU_Meter_Kolossos_Oval.tcz
crda.tcz
ntfs-3g.tcz
pcp-irtools.tcz
pcp-jivelite.tcz
pcp.tcz
samba4.tcz
slimserver.tcz
pcp-7.0.0-www.tcz
pcp-bt6.tcz
firmware-atheros.tcz
firmware-brcmwifi.tcz
firmware-ralinkwifi.tcz
firmware-rtlwifi.tcz
firmware-rpi-wifi.tcz
wireless_tools.tcz
wpa_supplicant.tcz
rpi-vc.tcz
compiletc.tcz
libasound-dev.tcz
curl.tcz
glibc_apps.tcz
pcp-ffmpeg.tcz
git.tcz
squashfs-tools.tcz
pcp-streamer.tcz

