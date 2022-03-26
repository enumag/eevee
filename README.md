# Easy Essentials VErsioning Engine

- Maintained by: enumag (enumag@gmail.com)
- Original project by: Raku (rakudayo@gmail.com)
- Updated by: Gegerlan (gegerlan2@hotmail.com)

This tool is meant to provide better versioning for games based on [Essentials](https://github.com/Maruno17/pokemon-essentials).

## Usage for other games

Note that this is currently mainly tested on a game which is based on an older version of Essentials so not sure if it's completely compatible with current Essentials.

It will most likely work for other RMXP-based games as well but it's not my focus.

Older versions of this tool also had support for RMVX and RMVXA games but I removed all of that to simplify the code. With some effort it could likely be re-introduced.

## Features

- Export .rxdata to .yaml files.
- Import .yaml files back to .rxdata files.
- Configuration using [`eevee.yaml`](example/eevee.yaml).
- Hash-based comparison to see if export / import is necessary.
- Internal post-processing to minimize the amount of changed lines and conflicts.
- Parallel processing to speed things up.

Support for exporting scripts was in the original project but I removed it because the game we're testing the tool on has a much better way to deal with that.

## Usage

TBD, feel free to nag me about this.
