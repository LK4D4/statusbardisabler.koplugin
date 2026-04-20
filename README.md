# statusbardisabler.koplugin

`statusbardisabler.koplugin` is a KOReader plugin that toggles the bottom
status bar based on the current book path.

## Features

- configurable list of path fragments
- disables the bottom status bar when a book path matches any fragment
- restores the status bar on non-matching books only if this plugin disabled it
- does not change footer presets or the alt status bar

## How It Works

A path fragment is a plain piece of text that the plugin looks for inside the
full book file path.

Examples:

- fragment `Manga` matches `/mnt/onboard/Books/Manga/Naruto 01.cbz`
- fragment `Comics/Marvel` matches `/mnt/onboard/Books/Comics/Marvel/X-Men.cbz`
- fragment `One Piece` matches `/mnt/onboard/Manga/One Piece/001.cbz`

The match is a simple case-sensitive "path contains this text" check.

If any configured fragment matches the current book path, the plugin hides the
bottom status bar. If no fragment matches, the plugin turns the status bar back
on only when this plugin was the one that hid it before.

## Usage

1. Enable the plugin in KOReader if needed.
2. Open a book and go to `Tools` -> `Status bar disabler`.
3. Choose `Add path fragment`.
4. Type part of the path that should trigger status bar hiding.
5. Press `Save`.

You can add multiple fragments. A book only needs to match one of them.

For a manga library stored under a folder named `Manga`, the easiest setup is:

- add the fragment `Manga`

That will match any book whose full path contains `Manga`.

## Managing Fragments

- `Add path fragment` opens a text box where you enter the text to match
- `Managed paths` shows all saved fragments
- selecting an existing fragment lets you edit or delete it
- `Show debug info` shows the current book path, saved fragments, current footer state, and whether the plugin hid it

Notes:

- matching is case-sensitive, so `Manga` and `manga` are different
- fragments must be unique
- fragments do not use wildcards or regular expressions
- you do not need to enter the whole path, only a distinctive part of it

## Installation

### AppStore

Install through the App Store plugin for KOReader.

### Manual

1. Download or clone this repository.
2. Ensure the folder name is `statusbardisabler.koplugin`.
3. Copy it into KOReader's `plugins` directory.
4. Restart KOReader.

## Tests

Run from the repository root:

```bash
lua5.1 tests/statusbardisabler_spec.lua
```
