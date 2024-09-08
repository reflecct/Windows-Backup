@echo off
setlocal enabledelayedexpansion

:: Windows Backup and Restore Script with Tokens Authentication and Troubleshooting (by reflecct)
:: This script automates the backup and restoration process with token protection.

set "backupDir=C:\BackupsReflect\ManualBackup"
set "tokenFile=%backupDir%\backupTokens.txt"

:CheckAdmin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script must be run as an administrator.
    echo [INFO] Exiting script...
    pause
    exit /b 1
)

if not exist "%backupDir%" mkdir "%backupDir%" 2>nul
if not exist "%tokenFile%" type nul > "%tokenFile%" 2>nul

:MainMenu
cls
echo ==================================================
echo Windows Backup and Restore Script
echo ==================================================
echo 1. Backup Windows (Save)
echo 2. Restore Windows
echo 3. Troubleshoot Common Issues
echo 4. Manual Backup of Important Files
echo 5. Exit
echo ==================================================
set /p "choice=Choose an option (1-5): "

if "%choice%"=="1" goto BackupOperation
if "%choice%"=="2" goto RestoreOperation
if "%choice%"=="3" goto TroubleshootMenu
if "%choice%"=="4" goto ManualBackup
if "%choice%"=="5" exit /b 0

echo [ERROR] Invalid choice. Please choose 1, 2, 3, 4, or 5.
pause
goto MainMenu

:BackupOperation
echo [INFO] Starting Backup Process...

:EnterToken
set /p "token=Enter a unique token for this backup (e.g., Backup123): "

if "!token!"=="" (
    echo [ERROR] Token cannot be empty. Please enter a valid token.
    goto EnterToken
)

findstr /x "!token!" "%tokenFile%" >nul
if %errorlevel% equ 0 (
    echo [ERROR] This token already exists. Please choose a different one.
    goto EnterToken
)

echo !token!>> "%tokenFile%"

echo [INFO] Performing Windows Backup...
wbadmin start backup -backupTarget:%backupDir% -include:C: -allCritical -quiet
if errorlevel 1 (
    echo [ERROR] Backup failed. Common causes:
    echo        - Insufficient disk space on the backup target.
    echo        - The backup service is not running.
    echo [INFO] Returning to main menu...
    pause
    goto MainMenu
)

ren "%backupDir%\WindowsImageBackup" "!token!"
if errorlevel 1 (
    echo [ERROR] Failed to rename the backup folder with token: !token!
    echo [INFO] Returning to main menu...
    pause
    goto MainMenu
)

echo [INFO] Backup completed successfully with token: !token!
echo [INFO] Backup saved to: %backupDir%\!token!
pause
goto MainMenu

:RestoreOperation
echo [INFO] Starting Restore Process...

set /p "token=Enter the token of the backup you want to restore: "

findstr /x "!token!" "%tokenFile%" >nul
if %errorlevel% neq 0 (
    echo [ERROR] Invalid token. No backup found for the given token: !token!
    echo [INFO] Returning to main menu...
    pause
    goto MainMenu
)

if not exist "%backupDir%\!token!" (
    echo [ERROR] Backup folder not found for token: !token!
    echo [INFO] Returning to main menu...
    pause
    goto MainMenu
)

echo [INFO] Performing Windows Restore...
wbadmin start recovery -version:!token! -itemType:AllCritical -quiet
if errorlevel 1 (
    echo [ERROR] Restore failed. Common causes:
    echo        - The backup version is corrupt or incomplete.
    echo        - Insufficient permissions to restore the system.
    echo [INFO] Returning to main menu...
    pause
    goto MainMenu
)

echo [INFO] Restore completed successfully. The system will reboot in 10 seconds.
shutdown /r /t 10
pause
goto MainMenu

:ManualBackup
cls
echo ==================================================
echo Manual Backup of Important Files
echo ==================================================
echo [INFO] Starting Manual Backup of Important Files...

set "importantDirs=%systemdrive%\Windows\System32 %systemdrive%\Users\%USERNAME% %systemdrive%\Windows\SystemApps %systemdrive%\Windows\SystemResources"

for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "timestamp=%datetime:~0,8%-%datetime:~8,6%"
set "backupFolder=%backupDir%\ManualBackup_%timestamp%"

mkdir "%backupFolder%" 2>nul

for %%D in (%importantDirs%) do (
    echo [INFO] Backing up %%D...
    start /b robocopy "%%D" "%backupFolder%\%%~nxD" /E /COPY:DAT /DCOPY:T /R:0 /W:0 /XA:SH /XJ /XF *.lock /MT:16 /NFL /NDL /NP /LOG+:"%backupFolder%\backup_log.txt"
    
    echo [INFO] Finished backing up %%D. Check the log file for details.
)

echo [INFO] Manual Backup completed. Files saved to %backupFolder%
echo [INFO] Check the log file at %backupFolder%\backup_log.txt for details.
pause
goto MainMenu

:TroubleshootMenu
cls
echo ==================================================
echo Troubleshooting Common Issues
echo ==================================================
echo 1. Check/Start Windows Backup Service
echo 2. Check/Start Volume Shadow Copy Service
echo 3. Exit Troubleshooting
echo ==================================================
set /p "troubleChoice=Choose an option (1-3): "

if "%troubleChoice%"=="1" (
    sc query "wbengine" | findstr /I "RUNNING" >nul
    if errorlevel 1 (
        echo [INFO] Starting Windows Backup Service...
        sc start "wbengine" >nul
        if errorlevel 1 (
            echo [ERROR] Failed to start Windows Backup Service.
        ) else (
            echo [INFO] Windows Backup Service started successfully.
        )
    ) else (
        echo [INFO] Windows Backup Service is already running.
    )
    pause
    goto TroubleshootMenu
)

if "%troubleChoice%"=="2" (
    sc query "VSS" | findstr /I "RUNNING" >nul
    if errorlevel 1 (
        echo [INFO] Starting Volume Shadow Copy Service...
        sc start "VSS" >nul
        if errorlevel 1 (
            echo [ERROR] Failed to start Volume Shadow Copy Service.
        ) else (
            echo [INFO] Volume Shadow Copy Service started successfully.
        )
    ) else (
        echo [INFO] Volume Shadow Copy Service is already running.
    )
    pause
    goto TroubleshootMenu
)

if "%troubleChoice%"=="3" goto MainMenu

echo [ERROR] Invalid choice. Please choose 1, 2, or 3.
pause
goto TroubleshootMenu
