# statusbardisabler.koplugin

`statusbardisabler.koplugin` is a KOReader plugin that toggles the bottom
status bar based on the current book path.

## Features

- configurable list of path fragments
- disables the bottom status bar when a book path matches any fragment
- restores the status bar on non-matching books only if this plugin disabled it
- does not change footer presets or the alt status bar

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
