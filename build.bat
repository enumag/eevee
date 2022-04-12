@echo off

:: Hack to keep the window open on error. Source:
:: https://stackoverflow.com/questions/17118846/how-to-prevent-batch-window-from-closing-when-error-occurs
if not defined in_subprocess (cmd /k set in_subprocess=y ^& %0 %*) & exit )

ocra ^
  eevee.rb ^
  src/*.rb ^
  rmxp/*.rb ^
  --gemfile "Gemfile" ^
  --gem-full ^
  --dll "ruby_builtin_dlls\libssp-0.dll" ^
  --dll "ruby_builtin_dlls\libgmp-10.dll" ^
  --dll "ruby_builtin_dlls\libgcc_s_seh-1.dll" ^
  --dll "ruby_builtin_dlls\libwinpthread-1.dll" ^
  --dll "ruby_builtin_dlls\zlib1.dll" ^
  --output "eevee.exe" ^
  --no-dep-run ^
  --no-lzma
