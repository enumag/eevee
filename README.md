# Easy Essentials VErsioning Engine

- Maintained by: enumag (enumag@gmail.com)
- Original project by: Raku (rakudayo@gmail.com)

This tool is meant to provide better versioning for games based on [Essentials](https://github.com/Maruno17/pokemon-essentials).

## Usage for other games

Note that this is currently mainly tested on a game which is based on an older version of Essentials so not sure if it's completely compatible with current Essentials.

It will most likely work for other RMXP-based games as well but it's not my focus.

Older versions of this tool also had support for RMVX and RMVXA games but I removed all of that to simplify the code. With some effort it could likely be re-introduced.

Support for exporting scripts was in the original project but I removed it because the game we're testing the tool on has a much better way to deal with that.

## Features

- Export .rxdata to .yaml files.
- Import .yaml files back to .rxdata files.
- Configuration using [`eevee.yaml`](example/eevee.yaml).
- Time stamp and filesize comparison to see if export / import is necessary.
- Internal post-processing to minimize the amount of changed lines and conflicts.
- Parallel processing to speed things up.

## Installation

TBD, feel free to nag me about this.

## Docker

In eevee directory:

```
docker build . --tag eevee
```

In game directory:

```
docker run -v $PWD:/app eevee import
docker run -v $PWD:/app eevee export
```

## Compilation

This is written for Windows 11 PowerShell with admin privileges.

```
choco install ruby
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
ridk install
gem install ocra listen
```

Next on the list I needed `gem install wdm` but it's a native extension and needs C compiler.
The installation finally passed after running these though I'm unsure which of these are actually required.
My suspicion is that gcc and make are necessary while the rest is useless, but I'm not reinstalling windows to test that.

```
ridk exec pacman -S mingw-w64-x86_64-libxslt
ridk exec pacman -S mingw-w64-ucrt-x86_64-gcc
ridk exec pacman -S mingw-w64-x86_64-ruby
ridk exec pacman -S make
```

Now finally:

```
gem install wdm parallel rubyzip
```

Next ocra failed on missing `fiber.so` which isn't distributed with Ruby 3.1+.
So instead I got it from Ruby 3.0 (x64) here:

https://rubyinstaller.org/downloads/

In the archive it was in `rubyinstaller-3.0.5-1-x64/lib/ruby/3.0.0/x64-mingw32/fiber.so`.

It belongs to this directory (path may be different depending on where Ruby is installed):

```
C:\tools\ruby31\lib\ruby\3.1.0\x64-mingw-ucrt
```

Now `build.bat` should be able to build `eevee.exe`. But it won't work because the gems won't be included.

To fix it I had to `gem install` all the gems listed in `Gemfile` and recompile. This can be done in bulk with `bundle install` from eevee's directory.

Also ran into some issues with `gem install psych`, it was missing `yaml.h`. Fixed it by restricting it to 4.0 in `Gemfile`.

Some tweaking of build.bat may be needed as well.
This time I had to remove `--dll "ruby_builtin_dlls\libssp-0.dll" ^` as this library didn't exist in `C:\tools\ruby31\bin\ruby_builtin_dlls`.
