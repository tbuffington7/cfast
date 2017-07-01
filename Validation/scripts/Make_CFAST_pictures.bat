@echo off

echo Creating figures for the CFAST Users guide

set installed_smokeview=0

call :getopts %*
if %stopscript% == 1 (
  exit /b
)

set SCRIPT_DIR=%CD%
cd ..
set BASEDIR=%CD%
cd ..
set SVNROOT=%CD%
cd ..\smv
set SMVROOT=%CD%

set RUNSMV=call %SVNROOT%\Validation\scripts\runsmv.bat

if "%installed_smokeview%" == "1" (
   set SMOKEVIEW=smokeview.exe
   call :is_file_installed %SMOKEVIEW% || exit /b 1
   echo %SMOKEVIEW% found

   set SH2BAT=sh2bat.exe
   call :is_file_installed %SH2BAT% || exit /b 1
   echo %SH2BAT% found
)

if "%installed_smokeview%" == "0" (
  cd %SCRIPT_DIR%

  set SMOKEVIEW=%SMVROOT%\Build\smokeview\intel_win_64\smokeview_win_64.exe
  call :does_file_exist %SMOKEVIEW% || exit /b 1
  echo %SMOKEVIEW% found

  set SH2BAT=%SMVROOT%\Build\sh2bat\intel_win_64\sh2bat_win_64.exe
  call :does_file_exist %SH2BAT% || exit /b 1
  echo %SH2BAT% found
)

cd %SCRIPT_DIR%
%SH2BAT% CFAST_Pictures.sh CFAST_Pictures.bat

echo Generating images
cd %BASEDIR%
call %SCRIPT_DIR%\CFAST_Pictures.bat

cd %SCRIPT_DIR%

goto eof

:: -------------------------------------------------------------
:is_file_installed
:: -------------------------------------------------------------

  set program=%1
  %program% -help 1> installed_error.txt 2>&1
  type installed_error.txt | find /i /c "not recognized" > installed_error_count.txt
  set /p nothave=<installed_error_count.txt
  erase installed_error_count.txt installed_error.txt
  if %nothave% == 1 (
    echo "***Fatal error: %program% not present"
    exit /b 1
  )
  exit /b 0

:: -------------------------------------------------------------
  :does_file_exist
:: -------------------------------------------------------------

set file=%1

if NOT exist %file% (
  echo ***Fatal error: %file% does not exist. Aborting
  exit /b 1
)
exit /b 0

:getopts
 set stopscript=0
 if (%1)==() exit /b
 set valid=0
 set arg=%1
 if /I "%1" EQU "-help" (
   call :usage
   set stopscript=1
   exit /b
 )
 if /I "%1" EQU "-smokeview" (
   set valid=1
   set installed_smokeview=1
 )
 if /I "%1" EQU "-installed" (
   set valid=1
   set installed_smokeview=1
 )
 shift
 if %valid% == 0 (
   echo.
   echo ***Error: the input argument %arg% is invalid
   echo.
   echo Usage:
   call :usage
   set stopscript=1
   exit /b
 )
if not (%1)==() goto getopts
exit /b

:usage  
echo Run_CFAST_Cases [options]
echo. 
echo -help           - display this message
echo -smokeview      - use installed smokeview and utilities 
exit /b

:eof
