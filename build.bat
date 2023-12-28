@echo off

:: Hack to keep the window open on error. Source:
:: https://stackoverflow.com/questions/17118846/how-to-prevent-batch-window-from-closing-when-error-occurs
if not defined in_subprocess (cmd /k set in_subprocess=y ^& %0 %*) & exit )

aibika ^
  eevee.rb ^
  src/*.rb ^
  rmxp/*.rb ^
  --gemfile Gemfile ^
  --gem-full ^
  --dll ruby_builtin_dlls\libyaml-0-2.dll ^
  --dll ruby_builtin_dlls\zlib1.dll ^
  --icon eevee.ico ^
  --output eevee.exe ^
  --no-dep-run ^
  --no-lzma
