@echo off
set "task_path=\My tasks\VPN-autoconnect"
set "working_dir=%APPDATA%\vpn-autolaunch"
set "bat_file=%working_dir%\vpn.bat"
set "vbs_file=%working_dir%\connect.vbs"
set "task_xml_file=%working_dir%\VPNTask.xml"

if exist %working_dir% (
    if exist "%bat_file%" (
        del "%bat_file%"
        echo Removed: %bat_file%
    )
    
    if exist "%vbs_file%" (
        del "%vbs_file%"
        echo Removed: %vbs_file%
    )

    dir /b /s /a "%working_dir%" | findstr .>nul || (
        rd /s /q %working_dir%
        echo Removed: %working_dir%
    )
)
schtasks /delete /tn "%task_path%" /f
pause