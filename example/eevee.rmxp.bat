@echo off

:: Hack to minimize the window. Source:
:: https://stackoverflow.com/questions/2106723/how-to-minimize-the-command-prompt-when-running-a-batch-script
if not "%minimized%"=="" goto :minimized
"./eevee.exe" "import"
set minimized=true
start /min cmd /C "%~dpnx0"
goto :EOF
:minimized

:: Hack to keep the window open on error. Source:
:: https://stackoverflow.com/questions/17118846/how-to-prevent-batch-window-from-closing-when-error-occurs
if not defined in_subprocess (cmd /k set in_subprocess=y ^& %0 %*) & exit )

"./eevee.exe" "rmxp" && timeout /t 1 /nobreak > NUL && exit
