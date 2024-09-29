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
set "batfile=%working_dir%\vpn.bat"
(
    echo @echo off
    echo powershell -Command "if ((Get-VpnConnection -Name '%selected_vpn%').ConnectionStatus -eq 'Connected') { exit 0 } else { exit 1 }"
    echo if %%ERRORLEVEL%%==0 ^(
    echo     exit /b 0
    echo ^)
    echo rasdial "%selected_vpn%"
) > "%batfile%"
echo Created: %batfile%

:: Absolute path to vpn.bat
for %%i in ("%batfile%") do set "batpath=%%~fpi%%~nxi"

:: Creating a new connect.vbs file
set "vbsfile=%working_dir%\connect.vbs"
echo Set WshShell = CreateObject("WScript.Shell") > %vbsfile%
echo WshShell.Run chr(34) ^& "%batfile%" ^& Chr(34), 0 >> %vbsfile%
echo Set WshShell = Nothing >> %vbsfile%
echo Created: %vbsfile%

:: Getting user SID
for /f "tokens=2" %%u in ('whoami /user') do set "user_sid=%%u"

:: Creating temporaty task XML-file
set "taskXmlFile=%working_dir%\VPNTask.xml"
(
    echo ^<?xml version="1.0" encoding="UTF-16"?^>
    echo ^<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
    echo   ^<RegistrationInfo^>
    echo     ^<Date^>2024-09-29T14:40:53.0092209^</Date^>
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
    echo       ^<Command^>%vbsfile%^</Command^>
    echo     ^</Exec^>
    echo   ^</Actions^>
    echo ^</Task^>
) > "%taskXmlFile%"
echo Created: %taskXmlFile%

:: Registering task in Task Scheduler
set "taskpath=\My tasks\VPN-autoconnect"
schtasks /delete /tn "%taskpath%" /f >nul 2>&1
schtasks /create /xml "%taskXmlFile%" /tn "%taskpath%" >nul 2>&1
if errorlevel 1 (
    echo Error: Failed to register the task. Check the XML format or permissions.
) else (
    echo Task with path %taskpath% succesfully registered in Task ^Scheduler.
)

if /i "%keepXML%"=="false" (
    del %taskXmlFile%
    echo Removed: %taskXmlFile%
)

pause