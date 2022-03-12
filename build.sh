# gem install <all gems in Gemfile>

ocra \
  console.rb \
  rmxp/rgss.rb \
  rmxp/rgss_internal.rb \
  rmxp/rgss_mod.rb \
  rmxp/rgss_rpg.rb \
  common.rb \
  addons.rb \
  plugin_base.rb \
  plugins/data_importer_exporter.rb \
  --gemfile "./Gemfile" \
  --gem-full \
  --dll "ruby_builtin_dlls\libssp-0.dll" \
  --dll "ruby_builtin_dlls\libgmp-10.dll" \
  --dll "ruby_builtin_dlls\libgcc_s_seh-1.dll" \
  --dll "ruby_builtin_dlls\libwinpthread-1.dll" \
  --no-dep-run \
  --no-lzma
