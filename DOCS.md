# Modding tools

Internally, we have been using [eevee](https://github.com/enumag/eevee) for development for over a year now. It can be helpful for modding as well so here is an introduction to how it works and how it can help you.

The project is open-source so feel free to use it for other games as well if you want to.

If you have questions or need help with the setup, ask `@enumag` on Discord or create an issue on GitHub.

You can download the latest modding tools zip from [releases](https://github.com/enumag/eevee/releases).

The modding tools zip contains the following:
- `eevee.exe` - the version of eevee we're currently using
- `eevee.yaml` - our eevee configuration
- `eevee.export.bat` - exports rxdata files to ruby
- `eevee.import.bat` - imports ruby files back to rxdata
- `eevee.patch.bat` - generates a patch (requires setup)
- `eevee.rmxp.bat` - opens RPG Maker and watches for changes to export
- `ResizeEnableRunner.exe` - a tool that lets you resize RPG Maker windows (optional)
- `ResizeEnable.dll` - a dll used by ResizeEnableRunner.exe (optional)
- `.gitignore` - recommended gitignore file for Git users

## Initialization

First unzip all these files into your game directory. Then use `eevee.export.bat`. This will create a `DataExport` directory with maps and other rxdata files exported as ruby.

## Searching

The ruby files are human-readable and versioning friendly. This means you can use a text editor to search the files for all kinds of things such as where to obtain a particular item.

Most notably eevee uses `s(<number>)` and `v(<number>)` for all usages of switches and variables meaning you can search for all usages of a certain switch or variable and find out where it's changed or used in conditions. It's worth noting that the search result would not include script usages where switches and variables are generally accessed through `$game_switches[<number>]` and `$game_variables[<number>]`.

## Refactoring

Similarly, you can use bulk-replace to apply a change everywhere throughout the game. For instance, a new version of the base game may change some API often used in events as a script command. You might be able to adjust your events with single search & replace or using text editing a lot faster than by finding and fixing all cases one by one in RPG Maker.

You can also use search & replace to move around switches, variables and other things to different numbers to avoid conflicts with other mods or a newer version of the base game. For variables and switches eevee even offers a shortcut command:

```sh
./eevee.exe shuffle s123 s1234
./eevee.exe shuffle v123 v1234
```

The first command will move switch 123 to switch 1234. The second will do the same with a variable. Note that this internally just moves the name or the switch and variable and replaces `s(123)` with `s(1234)` in the exported files. It doesn't replace `$game_switches[123]` usages in scripts, nor in script commands within events.

After editing the ruby files manually or using the shuffle command you need to run `eevee.import.bat` to make the changes available in the game and RPG Maker.

## RPG Maker

Now you can use `eevee.rmxp.bat` to open the game in RPG Maker XP if you have it installed. Eevee will keep running in the background, and when you save your changes it will export the updated rxdata files to ruby.

If `eevee.rmxp.bat` fails to open RMXP for you even after converting all files it means that your system doesn't have correct file association for `*.rxproj` files to open in RMXP. Fix it first.

Eevee will also run `ResizeEnableRunner.exe` in the background to let you resize RPG Maker windows. Most notably the event window and script command window.

While RPG Maker is open:
- Do *NOT* change the Ruby files in the `DataExport` directory. `Scripts` can be changed freely.
- Do *NOT* use Git commands that can change the ruby files such as `checkout`, `pull`, `merge`, `rebase` and `cherry-pick`. Using `commit` and `push` is fine.

## Missing assets

Eevee can also check that the game events aren't using any missing assets. It also detects some other mistakes like unused or conflicting events.

```sh
./eevee.exe assets
```

## Invalid tiles

We also found that some of our maps were using invalid tiles - index outside the boundaries of the given tileset. Those are invalid and may cause passability issues with JoiPlay's map optimizer. Eevee can replace all such tiles with zeros.

```sh
./eevee.exe tiles
```

Speaking of JoiPlay's map optimizer, I have found several bugs in it. As a result, this repository actually contains a fixed implementation which we're using internally. Running it, however, is a lot more difficult as I was unable to compile it into an exe. In case you need it, look into `Dockerfile`, `optimize.rb` and the `joiplay` directory.

## Incorrect half pixels

If the art in your games is using a double-pixel images, you can use this command to detect mistakes. The path can be either a single file or a directory. For a single file, it prints all incorrect pixels. For a directory, it only prints the first incorrect pixel for each file.

```sh
./eevee.exe pixels <path>
```

## Map tree

Another use case we had was that we needed an easy way to find IDs of each map and where it is in the map tree. You can use this command to generate the map tree as a text.

```sh
./eevee.exe tree
```

## No limits

You can even break RPG Maker's limits beyond the standard 5000 switches and 5000 variables by using the shuffle command to move something above this limit. You can still see, use and manage switches and variables above the limit in RPG Maker. While it doesn't allow you to set the maximum above 5000, it works just fine if you set the maximum above that using other means like eevee.

## Backups

Eevee always makes a backup of rxdata files before deleting or overwriting them. These backups are stored in the `DataBackups` directory. Backups older than two weeks are deleted automatically. This is useful when you accidentally lose some of your work because eevee updated the rxdata files. In general, this only happens if you run RPG Maker without eevee or if eevee crashes. In such a case, you should be able to restore your work from these backups.

## Git

For any large mod, it's recommended to use a Git repository for versioning. If you're not using Git yet but would like to start, then use these steps:

1. Create an empty Git repository.
2. Make an initial commit with no files or just an empty `.gitignore` file. Do *NOT* commit the game or the mod in the first commit!
3. Create a branch called `vanilla` and commit the base game.
    - Note: This should be the version your mod is already compatible with, not a version you want to upgrade to!
4. Add and commit the modding tools. Most importantly all the eevee files and `.gitignore`.
5. Run `eevee.export.bat` and commit the generated ruby files.
6. Go to the `Data` directory and delete or rxdata files except `Scripts.rxdata` and `PkmnAnimations.rxdata` and commit.
7. Checkout the `main` branch and merge the `vanilla` branch into `main`.
8. Add your mod to the base game and use `eevee.export.bat` to export your changed maps to ruby files.
9. Commit the mod to the `main` branch.

If you're already using Git, then an experienced Git user should be able to adjust it to a setup similar to if you were using the steps above. This, however, depends on what your very first commit contains and if you have a commit with the base version of the game, so we can't cover all the possible cases here. Ask on Discord if you need help.

## Patches

If you're using Git, eevee can also help you generate patches. We have been using it to generate the bugfix patches with just the updated files. Similarly, you can use it to generate a zip with just the files that were actually changed in your mod. In eevee.yaml you can set glob masks for which files should be included in the patch:

```yaml
# Files which will always be included in a patch
patch_always: '{Scripts/*.rb,Scripts/Reborn/*}'

# Files which will be included in a patch if they were changed since the base commit
patch_changed: '{Readme.txt,Audio/*,Data/*,DataExport/*,Fonts/*,Graphics/*}'

# Commit ID of the base version. Typically, a commit with just the vanilla game after eevee export.
base_commit: '<commit id>'
```

Then you can run `eevee.patch.bat` to generate `patch.zip` which should now only contain the files changed by your mod plus anything matching the `patch_always` mask.

## Mod upgrade

This is a very advanced topic, but eevee can help you with upgrading modded maps to the latest version of the game. For small mods it might be faster to recreate the mod manually on the new version, but for large mods that add many events throughout the entire game, this can save you many hours and dozens of bugs.

### Step 1: Update eevee

(Skip this step if your `vanilla` branch already has the latest modding tools.)

Note: Better open the documentation of the newer modding tools and follow them instead.

1. Checkout the `vanilla` branch from earlier.
2. Download the latest modding tools and commit them.
3. Run `eevee.import.bat`, then delete `DataExport/checksums.csv` and run `eevee.export.bat`. Commit all changes.
    - If eevee fails here, then the new version of eevee is incompatible with the old format. Report it as a bug on GitHub.
4. Checkout the `main` branch again and merge the `vanilla` branch into it.
    - If there are any conflicts, resolve them simply by using the version from your branch.
5. Repeat step 3.

### Step 2: Prepare base game

If you have a remote repository on GitHub or another server, better push all your branches first before continuing.

1. In you Git repository checkout the `vanilla` branch again.
2. Now delete all files and directories **(!!!)** *except* for the `.git` directory **(!!!)**. Do *NOT* commit.
    - The `.git` directory may be hidden depending on your system settings.
    - You can also keep any gitignored files such as the `Save Data` and `DataBackups` directories if you want.
3. Unpack the latest version of the base game, run `eevee.export.bat` and commit all changes.
4. Check if the version is actually the latest, there might be a bugfix patch available that is not part of the main download.
    - If there is a patch update available then update, run `eevee.export.bat` and commit all changes again.
5. Make a copy of the `Scripts` directory elsewhere on your PC, you may need it later.
6. Make notes of the highest IDs the new base game is using:
    - switches - check in RPG Maker or in `DataExport/System.rb`
    - variables - check in RPG Maker or in `DataExport/System.rb`
    - animations - check in RPG Maker or in `DataExport/Animations.rb`
    - common events - check in RPG Maker or in `DataExport/CommonEvents.rb`
    - tilesets - check in RPG Maker or in `DataExport/Tilesets.rb`
    - maps - highest number of `DataExport/Map*.rb`

Now your `vanilla` branch is up-to-date, and you can continue with the next step.

### Step 3: Prepare your mod

(This step could, in theory, be fully automated by writing a script that detects and automatically fixes the conflicts. Let us know if you'd like to help improve eevee and contribute this.)

Now comes the most challenging part. Preparing your mod to avoid as many conflicts as possible and then correctly resolving the rest during the merge.

1. Checkout the `main` branch with your mod.
2. Find the lowest number of your mod-specific switch, variable, animation, common event, tileset and map.
3. If your mod-specific switches and variables collide with the new base game switches and variables, use eevees shuffle command co move them to higher IDs.
    - Preferably make some reasonably large space between the base game and yours switches and variables so that you can avoid this in the future.
4. If your mod-specific animations, common events or tilesets collide with the base game, then change their IDs manually in `DataExport` ruby files.
    - Find the colliding ones in `Animations.rb`, `CommonEvents.rb` and `Tilesets.rb` a and increase their IDs so that they don't conflict.
    - Then search the `DataExport` files for usages of those ids using `anim(<id>)`, `call_common_event(<id>)` and `tileset_id: <id>` and replace them with their new numbers.
5. If your mod-specific maps collide with the base game, then rename the conflicting map files to higher numbers.
    - Update the numbers accordingly in `MapInfos.rb` - both the indexes and parent ids.
    - Then search the `DataExport` files for usages of `transfer_player(map: <id>,` and replace them with their new numbers.
    - If you're using `transfer_player_variables` to move the player to some of your maps then you need to find and adjust those places and adjust the variable values accordingly in RPG Maker.
6. Commit all changes if you didn't do it after each part.

### Step 4: Finding conflicting events

(This step could, in theory, be fully automated by writing a script that saves the used event ids in one branch, finds conflicts on the other branch and makes the changes automatically. Let us know if you'd like to help improve eevee and contribute this.)

Now try to merge the `vanilla` branch into the `main` branch. Don't try to resolve any conflicts yet. For a larger mod there will most likely still be way too many conflicts at this point. What you're interested in for now are conflicts within existing maps. More specifically, conflicting event ids within these maps. By that, I mean events that you added which have IDs that conflict with base game events on the same map. Now do the following:

1. Note down the pairs of conflicting map id + event id. Also note the highest event id used by the base game in each such map.
2. Abort the git merge.
3. Now use your notes and update the conflicting map events to ids higher than the highest event id for that map used in base game.
    - For each such event search the map file for usages of the conflicting event using `character(<id>)` and replace them with their new numbers.

You may need to repeat this process of attempting a merge, noting the conflicting ids, aborting and fixing the ids a few times.

### Step 5: Merging the branches

At this point you should have everything prepared to merge the files in `DataExport` without issues.

For `Audio`, `Fonts` and `Graphics` you're on your own in resolving the conflicts. In general, it's better to use base game files and then apply your changes again afterward.

For `Scripts` it's recommended to delete the directory while resolving the conflicts and use the previously backed up `Scripts` from the base game. Then reapply your script changes after the merge manually. Whenever possible, you should use ruby overrides in separate files rather than modifying the existing scripts.

That's all. We hope these tools will help you. Good luck with modding!
