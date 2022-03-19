# gem install <all gems in Gemfile>

ocra \
  console.rb \
  common.rb \
  rmxp/*.rb \
  plugins/*.rb \
  --gemfile "./Gemfile" \
  --gem-full \
  --dll "ruby_builtin_dlls\libssp-0.dll" \
  --dll "ruby_builtin_dlls\libgmp-10.dll" \
  --dll "ruby_builtin_dlls\libgcc_s_seh-1.dll" \
  --dll "ruby_builtin_dlls\libwinpthread-1.dll" \
  --no-dep-run \
  --no-lzma
