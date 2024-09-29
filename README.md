This batch file configures the Windows Task Scheduler to automatically start another batch file that connects to the selected VPN to automatically connect to VPN when Windows starts up and connect to any WiFi/Lan networks.

Tested on Windows 11

How to use:
1. Setup your VPN network
2. Download and run this batch file
3. Choose preffered VPN from the list
4. Done!

All files are located in `%APPDATA%/Roaming/vpn-autolaunch`. Task will be created at `Task Scheduler Library\My tasks\VPN-autoconnect`

You can use `-keepXML` flag for avoid deleting temporary XML file.
