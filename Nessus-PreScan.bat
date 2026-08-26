@echo off
setlocal enabledelayedexpansion

:: Usage: Nessus-Pre-Scan.bat [/quiet]
:: /quiet - skip interactive pauses (for unattended / remote execution, e.g. via PsExec)
set "QUIET=0"
if /i "%~1"=="/quiet" set "QUIET=1"
if "%QUIET%"=="0" cls

echo ****************************************************************************
echo ** This batch file will automatically execute a series of commands that   **
echo ** will allow a Nessus scan to carry out a credentialed vulnerability     **
echo ** assessment against this machine. Please remember to run the Post-Scan  **
echo ** script once the audit has been completed.                              **
echo ****************************************************************************
echo [!] This script requires Administrator privileges.
echo.

:: --- Verify we are actually elevated. Everything below fails silently if not. ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Not running as Administrator. Right-click and choose "Run as administrator", then re-run.
    if "%QUIET%"=="0" pause
    exit /b 1
)

SET "runningpath=%~dp0"

if "%QUIET%"=="0" pause
echo.
echo Saving current system settings...
if not exist "%runningpath%Settings-Backup" mkdir "%runningpath%Settings-Backup" 2>nul

:: --- Verify the backup folder is actually writable before we touch anything else ---
echo write-test > "%runningpath%Settings-Backup\writetest.tmp" 2>nul
if not exist "%runningpath%Settings-Backup\writetest.tmp" (
    echo [ERROR] Cannot write to "%runningpath%Settings-Backup" - the folder is missing, read-only, or this
    echo [ERROR] location is write-protected. NO configuration changes have been made.
    echo [ERROR] Re-run this script from a writable location, e.g. C:\Windows\Temp, and try again.
    if "%QUIET%"=="0" pause
    exit /b 1
)
del "%runningpath%Settings-Backup\writetest.tmp" >nul 2>&1

netsh advfirewall export "%runningpath%Settings-Backup\firewall-rules-backup.wfw"
REG save "HKLM\SYSTEM\CurrentControlSet\services\RemoteRegistry" "%runningpath%Settings-Backup\Nessus-Original-Key-1.hiv" /y
REG save "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile\Services\FileAndPrint" "%runningpath%Settings-Backup\Nessus-Original-Key-2.hiv" /y
echo (If the last command returned an error, that key may not exist yet on this machine - safe to ignore.)
REG save "HKLM\SOFTWARE\Policies\Microsoft\Windows\Network Connections" "%runningpath%Settings-Backup\Nessus-Original-Key-3.hiv" /y
REG save "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\system" "%runningpath%Settings-Backup\Nessus-Original-Key-4.hiv" /y

:: ---------------------------------------------------------------------------
:: Capture original state (running + start type) for WMI and Remote Registry
:: so Post-Scan can put things back exactly as they were, not just "on".
:: ---------------------------------------------------------------------------

call :CaptureServiceState winmgmt WMI
call :CaptureServiceState RemoteRegistry REMOTEREG

(
    echo %WMI_STATE%
    echo %WMI_STARTTYPE%
) > "%runningpath%Settings-Backup\wmi_original_state.txt"

(
    echo %REMOTEREG_STATE%
    echo %REMOTEREG_STARTTYPE%
) > "%runningpath%Settings-Backup\remotereg_original_state.txt"

:: ---------------------------------------------------------------------------
:: Hard gate: do NOT make any system changes unless every backup artifact we
:: actually depend on for restore is present and non-empty. This is the check
:: that was missing before - a write-protected folder used to fail silently
:: here and the script would go on to change live settings anyway.
:: ---------------------------------------------------------------------------
set "BACKUP_OK=1"
for %%F in (
    "firewall-rules-backup.wfw"
    "Nessus-Original-Key-1.hiv"
    "Nessus-Original-Key-3.hiv"
    "Nessus-Original-Key-4.hiv"
    "wmi_original_state.txt"
    "remotereg_original_state.txt"
) do (
    if not exist "%runningpath%Settings-Backup\%%~F" (
        echo [ERROR] Missing expected backup file: %%~F
        set "BACKUP_OK=0"
    ) else (
        for %%S in ("%runningpath%Settings-Backup\%%~F") do if %%~zS==0 (
            echo [ERROR] Backup file is empty: %%~F
            set "BACKUP_OK=0"
        )
    )
)

if "%BACKUP_OK%"=="0" (
    echo.
    echo [ERROR] Backup verification failed. NO configuration changes have been made.
    echo [ERROR] Check permissions on "%runningpath%Settings-Backup" and re-run.
    if "%QUIET%"=="0" pause
    exit /b 1
)

echo.
echo [ATTENTION] Original system configuration saved and verified. Do not delete the following folder:
echo %runningpath%Settings-Backup\
echo.

:: --- Configuration changes ---

echo [-] Enabling File and Printer Sharing firewall rules
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

echo [-] Enabling Windows Management Instrumentation (WMI) firewall rules
netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=Yes

echo [-] Setting Remote Registry to start automatically, and starting it now
REG add "HKLM\SYSTEM\CurrentControlSet\services\RemoteRegistry" /v Start /t REG_DWORD /d 2 /f
sc config RemoteRegistry start= auto
sc start RemoteRegistry >nul 2>&1

echo [-] Setting registry key for File and Printer services
REG add "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile\Services\FileAndPrint" /v Enabled /t REG_DWORD /d 1 /f

echo [-] Setting registry key for Remote and Local access
REG add "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile\Services\FileAndPrint" /v RemoteAddresses /t REG_SZ /d "localsubnet" /f

echo [-] Disabling Internet Connection Firewall for LAN or VPN connections
REG add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Network Connections" /v NC_PersonalFirewallConfig /t REG_DWORD /d 1 /f

echo [-] Disabling UAC remote restrictions for local accounts
REG add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\system" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f

echo [-] Enabling and starting the WMI service
sc config winmgmt start= auto
sc start winmgmt >nul 2>&1

:: --- Verify the two services Nessus actually depends on are really up ---
echo.
echo Verifying service state...
sc query winmgmt | find "RUNNING" >nul
if %errorlevel% equ 0 (echo [OK] WMI service is running.) else (echo [WARNING] WMI service does NOT appear to be running - investigate before scanning.)

sc query RemoteRegistry | find "RUNNING" >nul
if %errorlevel% equ 0 (echo [OK] Remote Registry service is running.) else (echo [WARNING] Remote Registry service does NOT appear to be running - investigate before scanning.)

echo.
echo [DONE] All commands completed.
echo You can now close this window and run Nessus.
echo.
if "%QUIET%"=="0" pause
exit /b 0

:CaptureServiceState
:: %1 = service name, %2 = variable prefix
set "SVCNAME=%~1"
set "PREFIX=%~2"
set "%PREFIX%_STATE=STOPPED"
set "%PREFIX%_STARTTYPE=UNKNOWN"

for /f "delims=" %%s in ('sc query %SVCNAME% ^| find "RUNNING"') do set "%PREFIX%_STATE=RUNNING"

sc qc %SVCNAME% | find "AUTO_START" >nul
if %errorlevel% equ 0 (
    set "%PREFIX%_STARTTYPE=AUTO_START"
) else (
    sc qc %SVCNAME% | find "DEMAND_START" >nul
    if %errorlevel% equ 0 (
        set "%PREFIX%_STARTTYPE=DEMAND_START"
    ) else (
        sc qc %SVCNAME% | find "DISABLED" >nul
        if %errorlevel% equ 0 set "%PREFIX%_STARTTYPE=DISABLED"
    )
)
exit /b 0
