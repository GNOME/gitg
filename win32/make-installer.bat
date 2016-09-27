C:/msys64/usr/bin/bash.exe -c "./make-installer stage1"
if errorlevel 1 (
exit /b %errorlevel%
)

C:/msys64/usr/bin/bash.exe -c "./make-installer stage2"
if errorlevel 1 (
exit /b %errorlevel%
)
