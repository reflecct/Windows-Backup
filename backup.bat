@echo off
setlocal enabledelayedexpansion
:: Created by reflecct (discord: reflecct)

:: Configuration
set "backupDir=C:\BackupsReflect"
set "tokenFile=%backupDir%\backupTokens.txt"
set "logFile=%backupDir%\backup_log.txt"

:: Ensure running as administrator
net session >nul 2>&1 || (
    echo [ERROR] This script must be run as an administrator.
    echo [INFO] Exiting script...
    pause
    exit /b 1
)

:: Create necessary directories and files
if not exist "%backupDir%" mkdir "%backupDir%" 2>nul
if not exist "%tokenFile%" type nul > "%tokenFile%" 2>nul

:MainMenu
cls
call :PrintHeader "Windows Backup and Restore Script"
echo 1. Backup Windows (Save)
echo 2. Restore Windows
echo 3. Troubleshoot Common Issues
echo 4. Manual Backup of Important Files
echo 5. List Existing Backups
echo 6. Delete a Backup
echo 7. Exit
call :PrintFooter
set /p "choice=Choose an option (1-7): "

if "%choice%"=="1" goto BackupOperation
if "%choice%"=="2" goto RestoreOperation
if "%choice%"=="3" goto TroubleshootMenu
if "%choice%"=="4" goto ManualBackup
if "%choice%"=="5" goto ListBackups
if "%choice%"=="6" goto DeleteBackup
if "%choice%"=="7" exit /b 0

echo [ERROR] Invalid choice. Please choose 1-7.
pause
goto MainMenu

:BackupOperation
cls
call :PrintHeader "Backup Operation"
call :EnterToken
if defined token (
    echo [INFO] Performing Windows Backup...
    call :RunCommand "wbadmin start backup -backupTarget:%backupDir% -include:C: -allCritical -quiet"
    if !errorlevel! equ 0 (
        ren "%backupDir%\WindowsImageBackup" "!token!"
        echo [INFO] Backup completed successfully with token: !token!
        echo [INFO] Backup saved to: %backupDir%\!token!
    ) else (
        call :HandleBackupError
    )
)
pause
goto MainMenu

:RestoreOperation
cls
call :PrintHeader "Restore Operation"
call :EnterExistingToken
if defined token (
    echo [INFO] Performing Windows Restore...
    call :RunCommand "wbadmin start recovery -version:!token! -itemType:AllCritical -quiet"
    if !errorlevel! equ 0 (
        echo [INFO] Restore completed successfully. The system will reboot in 10 seconds.
        shutdown /r /t 10
    ) else (
        call :HandleRestoreError
    )
)
pause
goto MainMenu

:ManualBackup
cls
call :PrintHeader "Manual Backup of Important Files"
set "importantDirs=%systemdrive%\Windows\System32 %systemdrive%\Users\%USERNAME% %systemdrive%\Windows\SystemApps %systemdrive%\Windows\SystemResources"
set "timestamp=%date:~-4%%date:~3,2%%date:~0,2%-%time:~0,2%%time:~3,2%%time:~6,2%"
set "timestamp=!timestamp: =0!"
set "backupFolder=%backupDir%\ManualBackup_!timestamp!"

mkdir "%backupFolder%" 2>nul

for %%D in (%importantDirs%) do (
    echo [INFO] Backing up %%D...
    start /b robocopy "%%D" "%backupFolder%\%%~nxD" /E /COPY:DAT /DCOPY:T /R:0 /W:0 /XA:SH /XJ /XF *.lock /MT:16 /NFL /NDL /NP /LOG+:"%logFile%"
)

echo [INFO] Manual Backup completed. Files saved to %backupFolder%
echo [INFO] Check the log file at %logFile% for details.
pause
goto MainMenu

:TroubleshootMenu
cls
call :PrintHeader "Troubleshooting Common Issues"
echo 1. Check/Start Windows Backup Service
echo 2. Check/Start Volume Shadow Copy Service
echo 3. Exit Troubleshooting
call :PrintFooter
set /p "troubleChoice=Choose an option (1-4): "

if "%troubleChoice%"=="1" call :ManageService "wbengine" "Windows Backup" & goto TroubleshootMenu
if "%troubleChoice%"=="2" call :ManageService "VSS" "Volume Shadow Copy" & goto TroubleshootMenu
if "%troubleChoice%"=="3" goto MainMenu

echo [ERROR] Invalid choice. Please choose 1-4.
pause
goto TroubleshootMenu

:ListBackups
call :PrintHeader "Existing Backups"
for /f "tokens=*" %%a in ('dir /b /ad "%backupDir%"') do (
    echo %%a
)
pause
goto MainMenu

:DeleteBackup
call :PrintHeader "Delete a Backup"
call :EnterExistingToken
if defined token (
    set /p "confirm=Are you sure you want to delete the backup !token!? (Y/N): "
    if /i "!confirm!"=="Y" (
        rmdir /s /q "%backupDir%\!token!"
        findstr /v /c:"!token!" "%tokenFile%" > "%tokenFile%.tmp"
        move /y "%tokenFile%.tmp" "%tokenFile%" >nul
        echo [INFO] Backup !token! has been deleted.
    ) else (
        echo [INFO] Deletion cancelled.
    )
)
pause
goto MainMenu

:: Helper Functions
:PrintHeader
echo ==================================================
echo %~1
echo ==================================================
exit /b

:PrintFooter
echo ==================================================
exit /b

:EnterToken
set /p "token=Enter a unique token for this backup (e.g., Backup123): "
if "!token!"=="" (
    echo [ERROR] Token cannot be empty. Please enter a valid token.
    exit /b 1
)
findstr /x "!token!" "%tokenFile%" >nul && (
    echo [ERROR] This token already exists. Please choose a different one.
    exit /b 1
)
echo !token!>> "%tokenFile%"
exit /b 0

:EnterExistingToken
set /p "token=Enter the token of the backup: "
findstr /x "!token!" "%tokenFile%" >nul || (
    echo [ERROR] Invalid token. No backup found for the given token: !token!
    set "token="
    exit /b 1
)
if not exist "%backupDir%\!token!" (
    echo [ERROR] Backup folder not found for token: !token!
    set "token="
    exit /b 1
)
exit /b 0

:RunCommand
%~1
exit /b %errorlevel%

:HandleBackupError
echo [ERROR] Backup failed. Common causes:
echo        - Insufficient disk space on the backup target.
echo        - The backup service is not running.
exit /b

:HandleRestoreError
echo [ERROR] Restore failed. Common causes:
echo        - The backup version is corrupt or incomplete.
echo        - Insufficient permissions to restore the system.
exit /b

:ManageService
sc query "%~1" | findstr /I "RUNNING" >nul
if errorlevel 1 (
    echo [INFO] Starting %~2 Service...
    sc start "%~1" >nul
    if errorlevel 1 (
        echo [ERROR] Failed to start %~2 Service.
    ) else (
        echo [INFO] %~2 Service started successfully.
    )
) else (
    echo [INFO] %~2 Service is already running.
)
pause
exit /b
