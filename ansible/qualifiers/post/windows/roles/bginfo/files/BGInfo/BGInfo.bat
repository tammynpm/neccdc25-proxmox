reg add HKU\.DEFAULT\Software\Sysinternals\BGInfo /v EulaAccepted /t REG_DWORD /d 1 /f

set "BGI_DOMAIN=%USERDNSDOMAIN%"
set "BGI_DIR=\\%BGI_DOMAIN%\SYSVOL\%BGI_DOMAIN%\scripts\BGInfo"
set "BGI_CFG=%BGI_DIR%\BGInfoConfig.bgi"
if exist "%BGI_DIR%\BGInfoConfig-%BGI_DOMAIN%.bgi" set "BGI_CFG=%BGI_DIR%\BGInfoConfig-%BGI_DOMAIN%.bgi"

"%BGI_DIR%\BGInfo64.exe" "%BGI_CFG%" /silent /nolicprompt /timer:0
