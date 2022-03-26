# gem install <all gems in Gemfile>

ocra \
  eevee.rb \
  src/*.rb \
  rmxp/*.rb \
  --gemfile "Gemfile" \
  --gem-full \
  --dll "ruby_builtin_dlls\libssp-0.dll" \
  --dll "ruby_builtin_dlls\libgmp-10.dll" \
  --dll "ruby_builtin_dlls\libgcc_s_seh-1.dll" \
  --dll "ruby_builtin_dlls\libwinpthread-1.dll" \
  --output "eevee.exe" \
  --no-dep-run \
  --no-lzma
