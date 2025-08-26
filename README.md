# Easy Essentials VErsioning Engine

- Maintained by: enumag (enumag@gmail.com)
- Original project by: Raku (rakudayo@gmail.com)

This tool is meant to provide better versioning for games based on [Essentials](https://github.com/Maruno17/pokemon-essentials).

## Documentation

See [`DOCS.md`](DOCS.md)

## Usage for other games

Note that this is currently mainly tested on a game which is based on an older version of Essentials, so not sure if it's completely compatible with current Essentials.

It will most likely work for other RMXP-based games as well, but it's not my focus.

Older versions of this tool also had support for RMVX and RMVXA games, but I removed all of that to simplify the code. With some effort, it could likely be re-introduced.

Support for exporting scripts was in the original project, but I removed it because the game we're testing the tool on has a much better way to deal with that.

The Ruby format is currently missing support for many features not used in Essentials. For such games you have to use the YAML format or contribute the missing code.

## Features

- Export .rxdata to .yaml files.
- Import .yaml files back to .rxdata files.
- Configuration using [`eevee.yaml`](example/eevee.yaml).
- Time stamp and filesize comparison to see if export / import is necessary.
- Custom Ruby format to minimize the number of changed lines and conflicts.
- Parallel processing to speed things up.

## Installation

Add the following lines into your `.gitignore`:

```
/Data/*.rxdata
!/Data/Scripts.rxdata
!/Data/PkmnAnimations.rxdata

/DataExport/checksums.csv
/DataExport/*.local.yaml
/DataExport/*.local.rb

/DataBackup/*

/Save Data/
/RGSS104E.dll
/Game.rxproj
```

If you have any of these lines in your `.gitignore` then remove them:

```
Data/Actors.rxdata
Data/Armors.rxdata
Data/Classes.rxdata
Data/Enemies.rxdata
Data/Items.rxdata
Data/Skills.rxdata
Data/States.rxdata
Data/Weapons.rxdata
Data/Troops.rxdata
```

Add `eevee.exe`, `eevee.yaml`, `eevee.rmxp.bat`, `eevee.import.bat` and `eevee.export.bat` into your game directory.

Commit your changes before continuing.

Run `eevee.export.bat` and commit everything.

Go into your `Data` directory, make a backup of all these files and then delete them:

```
Actors.rxdata
Animations.rxdata
Armors.rxdata
Classes.rxdata
CommonEvents.rxdata
Enemies.rxdata
Items.rxdata
Map*.rxdata
MapInfos.rxdata
Skills.rxdata
States.rxdata
System.rxdata
Tilesets.rxdata
TilesetsTemp.rxdata
Troops.rxdata
Weapons.rxdata
```

Backup and delete `Game.rxproj` from your game directory.

Commit those file deletions.

Optional: If you're planning to use Eevee to generate patches then adjust `patch_always` and `patch_changed` in your `eevee.yaml`.

Optional: Add `ResizeEnable.dll` and `ResizeEnableRunner.exe` into your game directory.

## Docker

In eevee directory:

```
docker build . --tag eevee
```

In game directory:

```
docker run -v $PWD:/app eevee ruby /eevee/eevee.rb import
docker run -v $PWD:/app eevee ruby /eevee/eevee.rb export
docker run -v $PWD:/app eevee ruby /eevee/optimize.rb
```

## Compilation

It is recommended to use eevee releases compiled automatically through GitHub Actions. Below is a setup useful for local testing. This is written for Windows 11 PowerShell with admin privileges.

```
choco install ruby
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
ridk install
gem install aibika listen
```

Next on the list I needed `gem install wdm` but it's a native extension and needs C compiler.
The installation finally passed after running these, though I'm unsure which of these are actually required.
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

Now `build.bat` should be able to build `eevee.exe`. But it won't work because the gems won't be included.

To fix it I had to `gem install` all the gems listed in `Gemfile` and recompile. This can be done in bulk with `bundle install` from eevee's directory.

Sometimes it is necessary to update the local gems using `bundle update`.

Also ran into some issues with `gem install psych`, it was missing `yaml.h`. Fixed it by restricting it to 4.0 in `Gemfile`.

Some tweaking of build.bat may be needed as well.
This time I had to remove `--dll "ruby_builtin_dlls\libssp-0.dll" ^` as this library didn't exist in `C:\tools\ruby31\bin\ruby_builtin_dlls`.
