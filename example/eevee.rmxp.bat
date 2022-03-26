@echo off

:: Hack to keep the window open on error. Source:
:: https://stackoverflow.com/questions/17118846/how-to-prevent-batch-window-from-closing-when-error-occurs
if not defined in_subprocess (cmd /k set in_subprocess=y ^& %0 %*) & exit )

"./eevee.exe" "rmxp" && timeout /t 1 /nobreak > NUL && exit
