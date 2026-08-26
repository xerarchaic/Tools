@echo off
setlocal enabledelayedexpansion

:: Usage: Nessus-Post-Scan.bat [/quiet]
:: /quiet - skip interactive pauses (for unattended / remote execution, e.g. via PsExec)
set "QUIET=0"
if /i "%~1"=="/quiet" set "QUIET=1"

echo ******************************************************************************
echo ** This batch file will automatically remove all changes and settings       **
echo ** made to this computer for the purposes of the Nessus authenticated scan. **
echo ** The script must be run from the same location as the Nessus-Pre-Scan.bat **
echo ******************************************************************************
echo [!] This script requires Administrator privileges.
echo.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Not running as Administrator. Right-click and choose "Run as administrator", then re-run.
    if "%QUIET%"=="0" pause
    exit /b 1
)

SET "runningpath=%~dp0"

if not exist "%runningpath%Settings-Backup" (
    echo [ERROR] Settings-Backup folder not found next to this script. Nothing to restore.
    if "%QUIET%"=="0" pause
    exit /b 1
)

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
    )
)

if "%BACKUP_OK%"=="0" (
    echo.
    echo [ERROR] Backup set is incomplete - refusing to attempt a partial restore.
    echo [ERROR] Review "%runningpath%Settings-Backup" manually before proceeding.
    if "%QUIET%"=="0" pause
    exit /b 1
)

if "%QUIET%"=="0" pause
echo.
echo Restoring original Firewall settings...
netsh advfirewall import "%runningpath%Settings-Backup\firewall-rules-backup.wfw"

echo Restoring original Remote Registry settings...
REG restore "HKLM\SYSTEM\CurrentControlSet\services\RemoteRegistry" "%runningpath%Settings-Backup\Nessus-Original-Key-1.hiv"

echo Restoring registry key for File and Printer services...
REG restore "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile\Services\FileAndPrint" "%runningpath%Settings-Backup\Nessus-Original-Key-2.hiv"
echo (If the last command returned an error, that key may not have existed originally - safe to ignore.)

echo Restoring original Internet Connection Firewall for LAN or VPN connections settings...
REG restore "HKLM\SOFTWARE\Policies\Microsoft\Windows\Network Connections" "%runningpath%Settings-Backup\Nessus-Original-Key-3.hiv"

echo Restoring original UAC settings...
REG restore "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\system" "%runningpath%Settings-Backup\Nessus-Original-Key-4.hiv"

:: ---------------------------------------------------------------------------
:: Restore WMI and Remote Registry to their pre-scan running state + start type.
:: NOTE: "usebackq" is required here - without it, a quoted path in a FOR /F
:: in() clause is parsed as a literal string instead of being opened as a file,
:: which silently no-ops this whole restore step.
:: ---------------------------------------------------------------------------

call :RestoreServiceState winmgmt WMI "%runningpath%Settings-Backup\wmi_original_state.txt"
call :RestoreServiceState RemoteRegistry REMOTEREG "%runningpath%Settings-Backup\remotereg_original_state.txt"

echo.
echo All commands completed. Original configuration restored.
echo You can now delete the scripts and backup folder.
echo.
if "%QUIET%"=="0" pause
exit /b 0

:RestoreServiceState
:: %1 = service name, %2 = variable prefix, %3 = path to saved state file
set "SVCNAME=%~1"
set "PREFIX=%~2"
set "STATEFILE=%~3"

if not exist "%STATEFILE%" (
    echo [WARNING] No saved state file found for %SVCNAME% - skipping restore for this service.
    exit /b 0
)

set "%PREFIX%_STATE="
set "%PREFIX%_STARTTYPE="

for /f "usebackq delims=" %%a in ("%STATEFILE%") do (
    if not defined %PREFIX%_STATE (
        set "%PREFIX%_STATE=%%a"
    ) else (
        set "%PREFIX%_STARTTYPE=%%a"
    )
)

echo Restoring %SVCNAME%: was !%PREFIX%_STATE!, start type !%PREFIX%_STARTTYPE!

if /i "!%PREFIX%_STARTTYPE!"=="AUTO_START" (
    sc config %SVCNAME% start= auto
) else if /i "!%PREFIX%_STARTTYPE!"=="DEMAND_START" (
    sc config %SVCNAME% start= demand
) else if /i "!%PREFIX%_STARTTYPE!"=="DISABLED" (
    sc config %SVCNAME% start= disabled
)

if /i "!%PREFIX%_STATE!"=="STOPPED" (
    sc stop %SVCNAME% >nul 2>&1
)

exit /b 0
