@echo on 
REM unlocks all open handles in subdirectory using Sysinternals' handle.exe tool
REM Necessary on Windows,  if buildbot runs git + parallel builds. 
REM Often git would fail, because an open file from one of the old builds is still left
REM This script will prevent git errors
REM Usage : unlock_handles.bat [path_prefix]
REM The default value for the path_prefix is current directory
set OLD_CD=%CD%
if  "%1%" ==  "" (
  set dir=%CD%
) else (
  set dir=%1%
)
cd ..
echo Cleaning up open file handles under %dir%
handle /accepteula %dir%
for /f "tokens=3,6,8 delims=: " %%i in ('handle %dir% ^| findstr %dir%') do echo Releasing file lock on %%k & handle -c %%j -y -p %%i
echo Check no open file handles under %dir%
handle %dir%
cd %OLD_CD%