@echo off
setlocal enabledelayedexpansion

:: Getting args
set "keepXML=false"
if /i "%~1"=="-keepXML" set "keepXML=true"

:: Getting the list of VPN networks via PowerShell and saving it to a variable
:get-vpn
set count=0
for /f "tokens=*" %%i in ('powershell -Command "Get-VpnConnection | Select-Object -ExpandProperty Name"') do (
    set /a count+=1
    set "vpn[!count!]=%%i"
    echo !count!. %%i
)

:: Check if any VPNs are found
if %count%==0 (
    echo Error: No configured VPN connections found.
    pause
    goto :eof
)

:: Request to select a VPN network
set /p choice="Enter the number of the corresponding VPN network: "

:: Checking the correctness of the selection
if "!vpn[%choice%]!"=="" (
    echo Error: VPN connection with this number not found.
    pause
    goto :get-vpn
)

:: Saving the selected VPN to a variable
set "selected_vpn=!vpn[%choice%]!"
echo You choosed: %selected_vpn%
pause

set "working_dir=%APPDATA%\vpn-autolaunch"
if not exist "%working_dir%" mkdir "%working_dir%"

:: Creating a new vpn.bat with the connect command
set "bat_file=%working_dir%\vpn.bat"
(
    echo @echo off
    echo powershell -Command "if ((Get-VpnConnection -Name '%selected_vpn%').ConnectionStatus -eq 'Connected') { exit 0 } else { exit 1 }"
    echo if %%ERRORLEVEL%%==0 ^(
    echo     exit /b 0
    echo ^)
    echo rasdial "%selected_vpn%"
) > "%bat_file%"
echo Created: %bat_file%

:: Absolute path to vpn.bat
for %%i in ("%bat_file%") do set "batpath=%%~fpi%%~nxi"

:: Creating a new connect.vbs file
set "vbs_file=%working_dir%\connect.vbs"
echo Set WshShell = CreateObject("WScript.Shell") > %vbs_file%
echo WshShell.Run chr(34) ^& "%bat_file%" ^& Chr(34), 0 >> %vbs_file%
echo Set WshShell = Nothing >> "%vbs_file%"
echo Created: %vbs_file%

:: Getting user SID
for /f "tokens=2" %%u in ('whoami /user') do set "user_sid=%%u"

:: Creating temporaty task XML-file
set "task_xml_file=%working_dir%\VPNTask.xml"
(
    echo ^<?xml version="1.0" encoding="UTF-16"?^>
    echo ^<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
    echo   ^<RegistrationInfo^>
    echo     ^<Author^>%COMPUTERNAME%\%USERNAME%^</Author^>
    echo     ^<URI^>\My tasks\VPN-autoconnect^</URI^>
    echo   ^</RegistrationInfo^>
    echo   ^<Triggers^>
    echo     ^<LogonTrigger^>
    echo       ^<Enabled^>true^</Enabled^>
    echo       ^<UserId^>%COMPUTERNAME%\%USERNAME%^</UserId^>
    echo     ^</LogonTrigger^>
    echo     ^<EventTrigger^>
    echo       ^<Enabled^>true^</Enabled^>
    echo       ^<Subscription^>^&lt;QueryList^&gt;^&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"^&gt;^&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"^&gt;*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]^&lt;/Select^&gt;^&lt;/Query^&gt;^&lt;/QueryList^&gt;^</Subscription^>
    echo     ^</EventTrigger^>
    echo   ^</Triggers^>
    echo   ^<Principals^>
    echo     ^<Principal id="Author"^>
    echo       ^<UserId^>%user_sid%^</UserId^>
    echo       ^<LogonType^>InteractiveToken^</LogonType^>
    echo       ^<RunLevel^>LeastPrivilege^</RunLevel^>
    echo     ^</Principal^>
    echo   ^</Principals^>
    echo   ^<Settings^>
    echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
    echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
    echo     ^<StopIfGoingOnBatteries^>true^</StopIfGoingOnBatteries^>
    echo     ^<AllowHardTerminate^>true^</AllowHardTerminate^>
    echo     ^<StartWhenAvailable^>false^</StartWhenAvailable^>
    echo     ^<RunOnlyIfNetworkAvailable^>true^</RunOnlyIfNetworkAvailable^>
    echo     ^<IdleSettings^>
    echo       ^<StopOnIdleEnd^>true^</StopOnIdleEnd^>
    echo       ^<RestartOnIdle^>false^</RestartOnIdle^>
    echo     ^</IdleSettings^>
    echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
    echo     ^<Enabled^>true^</Enabled^>
    echo     ^<Hidden^>false^</Hidden^>
    echo     ^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>
    echo     ^<DisallowStartOnRemoteAppSession^>false^</DisallowStartOnRemoteAppSession^>
    echo     ^<UseUnifiedSchedulingEngine^>true^</UseUnifiedSchedulingEngine^>
    echo     ^<WakeToRun^>false^</WakeToRun^>
    echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
    echo     ^<Priority^>7^</Priority^>
    echo   ^</Settings^>
    echo   ^<Actions Context="Author"^>
    echo     ^<Exec^>
    echo       ^<Command^>%vbs_file%^</Command^>
    echo     ^</Exec^>
    echo   ^</Actions^>
    echo ^</Task^>
) > "%task_xml_file%"
echo Created: %task_xml_file%

:: Registering task in Task Scheduler
set "task_path=\My tasks\VPN-autoconnect"
schtasks /delete /tn "%task_path%" /f >nul 2>&1
schtasks /create /xml "%task_xml_file%" /tn "%task_path%" >nul 2>&1
if errorlevel 1 (
    echo Error: Failed to register the task. Check the XML format or permissions.
) else (
    echo Task with path %task_path% succesfully registered in Task Scheduler.
)

if /i "%keepXML%"=="false" (
    del "%task_xml_file%"
    echo Removed: %task_xml_file%
)

pause