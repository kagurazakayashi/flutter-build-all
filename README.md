# flutter-build-all — Flutter 全平台建置腳本

**English** | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md) | [日本語](README.ja.md)

A standalone Python 3 script (`build_all.py`) placed in the root of a Flutter project. Run it to build the project for all supported platforms in one command, with automatic bundling of resource files, install scripts, and platform-specific packaging.

## Table of Contents

- [Overview](#overview)
- [Third-Party Libraries](#third-party-libraries)
- [Integration](#integration)
  - [Method 1: Copy Files](#method-1-copy-files)
  - [Method 2: Git Submodule](#method-2-git-submodule)
- [Usage](#usage)
  - [Quick Start](#quick-start)
  - [Filter by Platform](#filter-by-platform)
  - [Web Renderer](#web-renderer)
- [Options](#options)
  - [Basic Options](#basic-options)
  - [App Info Options](#app-info-options)
  - [Path Options](#path-options)
- [Build Process](#build-process)
- [Output Directory Structure](#output-directory-structure)
- [Platform-Specific Handling](#platform-specific-handling)
  - [Linux](#linux)
  - [Windows](#windows)
  - [macOS](#macos)
- [Template Files](#template-files)
- [Testing](#testing)
- [Notes](#notes)

## Overview

- Reads `pubspec.yaml` to get the app name and version
- Enumerates all available Flutter platforms (`windows`, `linux`, `macos`, `web`, `android`, `ios`)
- Auto-detects `l10n/app_*.arb` files and runs `flutter gen-l10n` before building
- Runs `flutter analyze` for static analysis before building
- Bundles README files (Markdown to HTML conversion via optional third-party library) and LICENSE files into each output
- **Linux**: generates `install_app.sh` with desktop shortcut and `.desktop` menu entry management
- **Windows**: generates `install_app.ps1` with Start Menu and Desktop shortcut management
- **macOS**: generates `install_app.sh` to copy `.app` bundle to `/Applications`
- **Parallel builds**: use `--jobs` to build multiple platforms simultaneously

## Third-Party Libraries

| Library       | Purpose                                                                                  | Installation              | Required?                                        |
| ------------- | ---------------------------------------------------------------------------------------- | ------------------------- | ------------------------------------------------ |
| `pyyaml`      | Parses `pubspec.yaml` for reading app name and version                                   | `pip install pyyaml`      | No. Falls back to regex-based parsing            |
| `markdown`    | Converts README.md to HTML for bundling with build output                                | `pip install markdown`    | No. Without it, README is output as plain `.txt` |

## Integration

### Method 1: Copy Files

Copy the following files from this repository into your Flutter project root:

```
your-project/
├── build_all.py          # Main script (required)
├── install_app.sh.tmpl   # Linux install script template
├── install_app.ps1.tmpl  # Windows install script template
└── Info.plist.tmpl       # macOS App Bundle template (reserved)
```

Template files can be omitted if packaging for a specific platform is not needed.

### Method 2: Git Submodule

```bash
# Run from your Flutter project root
git submodule add git@github.com:kagurazakayashi/flutter-build-all.git tools/build-all
git submodule update --init --recursive
```

When using git submodule, specify `--project-dir` or invoke the script directly from the submodule directory:

```bash
# From the project root
python tools/build-all/build_all.py

# Or from any directory
python tools/build-all/build_all.py --project-dir /path/to/your-flutter-project
```

> **Note**: Template files (`.tmpl`) reside in the submodule directory. The script searches relative to `build_all.py` itself (`SCRIPT_DIR`), so as long as the script can access the `.tmpl` files in the same directory, it will work.

## Usage

### Quick Start

```bash
cd /path/to/your-flutter-project
python build_all.py
```

> The current directory (or the directory specified by `--project-dir`) must be a Flutter project (containing `pubspec.yaml`).

Output will be placed under `bin/`, one subdirectory per platform.

### Filter by Platform

```bash
# Build only Windows
python build_all.py --target "windows"

# Build Windows and Linux only
python build_all.py --target "windows,linux"

# Build Linux and web
python build_all.py --target "linux,web"

# Skip web
python build_all.py --no-web
```

`--target` accepts comma-separated platform names. Platforms not available on the current OS are automatically skipped.

### Web Renderer

```bash
# Use CanvasKit renderer for web
python build_all.py --target "web" --web-renderer canvaskit

# Use HTML renderer for web
python build_all.py --target "web" --web-renderer html
```

Available web renderers: `auto` (default), `canvaskit`, `html`.

### Parallel Builds

```bash
# Auto-detect CPU core count for parallelism
python build_all.py --jobs 0

# Use 4 parallel jobs
python build_all.py --jobs 4

# Combine with platform filter
python build_all.py --jobs 4 --target "linux,web"
```

## Options

### Basic Options

| Option          | Type    | Default                | Description                                                                                                  |
| --------------- | ------- | ---------------------- | ------------------------------------------------------------------------------------------------------------ |
| `--test`        | flag    | —                      | Check the build environment (Python, Flutter, available platforms) without performing an actual build        |
| `--name`        | string  | auto from `pubspec.yaml` | Custom name for the output directories. Defaults to the `name` field in `pubspec.yaml`                     |
| `--target`      | string  | — (all platforms)      | Comma-separated platform filter. e.g. `"windows,linux,web"`                                                  |
| `--appver`      | string  | auto-detect            | Application version appended to output directory name. Auto-detected from `pubspec.yaml` if not specified    |
| `--web-renderer` | string | `auto`                 | Web renderer: `auto`, `canvaskit`, or `html`                                                                |
| `--no-web`      | flag    | —                      | Skip web platform build                                                                                     |
| `--skip-analyze`| flag    | —                      | Skip `flutter analyze` step (useful for quick builds)                                                        |
| `--jobs`        | integer | — (sequential)         | Number of parallel build jobs. `0` means auto-detect based on CPU core count                                |

### App Info Options

| Option               | Type   | Default                          | Description                                                                                                                           |
| -------------------- | ------ | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `--appdesc`          | string | empty                            | Application description. Linux desktop entry `Comment`; Windows shortcut `Description`; macOS `Info.plist` `NSHumanReadableCopyright` |
| `--appgeneric`       | string | empty                            | Generic application name. Linux desktop entry `GenericName`; macOS `Info.plist` `CFBundleDisplayName`                                 |
| `--appcategory`      | string | `Utility`                        | Linux desktop entry `Categories`, semicolon-separated for multiple. e.g. `"Network;FileTransfer"`                                     |
| `--appicon`          | string | `web/icons/Icon-192.png`         | Path to the Linux icon file within the project. Windows/macOS auto-detect their respective icon files                                 |
| `--appidentifier`    | string | derived from pubspec name        | macOS Bundle Identifier. When not specified, derived from the app name                                                                |
| `--appmacoscategory` | string | `public.app-category.utilities`  | macOS app category for `Info.plist`. e.g. `public.app-category.developer-tools`                                                       |

### Path Options

| Option          | Type   | Default           | Description                                                                                                      |
| --------------- | ------ | ----------------- | ---------------------------------------------------------------------------------------------------------------- |
| `--project-dir` | string | current directory | Flutter project root directory. Useful when the script is not in the project root (e.g. used via git submodule)  |

## Build Process

When the script runs, it executes the following steps in order:

1. **Project check** — verifies `pubspec.yaml` exists and reads `name` field
2. **Localization generation** — detects `l10n/app_*.arb` and runs `flutter gen-l10n` if present
3. **Static analysis** — runs `flutter analyze`, aborts on failure (can be skipped with `--skip-analyze`)
4. **Read project info** — reads app name and version from `pubspec.yaml`
5. **Enumerate platforms** — determines available platforms based on current OS
6. **Find resources** — locates README and LICENSE files in the project root
7. **Build per platform** — runs `flutter build` for each platform (parallel when `--jobs` is specified):
   - Desktop: `flutter build windows/linux/macos`
   - Web: `flutter build web --web-renderer <renderer>`
   - Android: `flutter build apk`
   - iOS: `flutter build ios --no-codesign`
8. **Post-processing** — copies build artifacts to `bin/`, writes resource files, install scripts

## Output Directory Structure

```
bin/
├── myapp_v2.0.0_windows/
│   ├── myapp.exe                # Executable
│   ├── data/                    # Flutter data
│   ├── flutter_exported.dll     # Flutter engine
│   ├── README.html              # Converted README
│   ├── LICENSE.txt              # License (UTF-8-BOM + CRLF)
│   ├── install_app.ps1          # Windows install script
│   └── app_icon.ico             # App icon (if present)
├── myapp_v2.0.0_linux/
│   ├── myapp                    # Executable
│   ├── data/
│   ├── lib/
│   ├── README.html
│   ├── LICENSE.txt
│   ├── install_app.sh           # Linux install script
│   └── Icon-192.png             # App icon
├── myapp_v2.0.0_macos/
│   ├── myapp.app/               # macOS App Bundle
│   ├── README.html
│   ├── LICENSE.txt
│   └── install_app.sh
├── myapp_v2.0.0_web/
│   ├── index.html               # Web entry
│   ├── main.dart.js             # Compiled JS
│   ├── assets/
│   └── ...
├── myapp_v2.0.0_android/
│   └── app-release.apk
└── ...
```

Naming convention:

- With version: `{name}_v{ver}_{platform}`
- Without version: `{name}_{platform}`

## Platform-Specific Handling

### Linux

- Generates `install_app.sh` from `install_app.sh.tmpl`
- Copies the icon file to the output directory
- `install_app.sh` supports the following subcommands:
  - `install` — add to app menu and desktop
  - `uninstall` — remove from app menu and desktop
  - `install_menu` / `uninstall_menu` — app menu only
  - `install_desktop` / `uninstall_desktop` — desktop shortcut only

### Windows

- Generates `install_app.ps1` from `install_app.ps1.tmpl`
- Auto-detects icon file from common Flutter paths
- `install_app.ps1` supports the same set of subcommands (`install` / `uninstall` / `install_menu` etc.)
- Output text files use UTF-8-BOM encoding and CRLF line endings

### macOS

- Flutter generates the `.app` bundle automatically
- Generates `install_app.sh` to copy/remove the app from `/Applications`
- Supports `install` and `uninstall` subcommands

## Template Files

Template files must be placed in the same directory as `build_all.py` and use `{{variable}}` syntax. The script replaces these placeholders based on command-line arguments.

### `install_app.sh.tmpl` Placeholders

| Placeholder            | Source                           |
| ---------------------- | -------------------------------- |
| `{{APP_NAME}}`         | `--name` or auto-detected        |
| `{{APP_EXEC}}`         | `{name}` (no extension on Linux) |
| `{{APP_ICON_FILE}}`    | basename of `--appicon`          |
| `{{APP_ICON_NAME}}`    | icon filename without extension  |
| `{{APP_COMMENT}}`      | `--appdesc`                      |
| `{{APP_GENERIC_NAME}}` | `--appgeneric`                   |
| `{{APP_CATEGORIES}}`   | `--appcategory`                  |
| `{{APP_DESKTOP_NAME}}` | value of `--name`                |

### `install_app.ps1.tmpl` Placeholders

| Placeholder            | Source                              |
| ---------------------- | ----------------------------------- |
| `{{APP_NAME}}`         | `--name` or auto-detected           |
| `{{APP_EXEC}}`         | `{name}.exe`                        |
| `{{APP_ICON}}`         | basename of icon.ico (if present)   |
| `{{APP_COMMENT}}`      | `--appdesc`                         |
| `{{APP_DESKTOP_NAME}}` | value of `--name`                   |

### `Info.plist.tmpl` Placeholders

| Placeholder              | Source                            |
| ------------------------ | --------------------------------- |
| `{{APP_NAME}}`           | `--name`                          |
| `{{APP_DISPLAY_NAME}}`   | `--appgeneric`                    |
| `{{APP_EXEC}}`           | binary filename                   |
| `{{APP_ICON_NAME}}`      | icon filename without extension   |
| `{{APP_IDENTIFIER}}`     | `--appidentifier` or auto-derived |
| `{{APP_VERSION}}`        | `--appver` or auto-detected       |
| `{{APP_MACOS_CATEGORY}}` | `--appmacoscategory`              |
| `{{APP_COPYRIGHT}}`      | `--appdesc`                       |

## Testing

```bash
# Run self-test: check environment without performing an actual build
python build_all.py --test
```

`--test` will:

1. Display Python version
2. Check if Flutter is available
3. List available platforms for the current OS
4. Check optional dependencies (pyyaml, markdown)

## Notes

- **Must run inside a Flutter project root** — the script needs `pubspec.yaml`. Use `--project-dir` when using the submodule approach
- **Python version** — requires Python 3.6 or later
- **Platform availability** — not all platforms can be built on all operating systems (e.g., iOS requires macOS)
- **`pyyaml` library is optional** — without it, the script falls back to regex-based `pubspec.yaml` parsing
- **`markdown` library is optional** — without it, README is output as plain `.txt`; when installed, it's automatically converted to HTML
- **Output overwritten** — the `bin/` directory is cleared on each run
- **Windows encoding** — Windows `.txt` output uses UTF-8-BOM + CRLF; other platforms use UTF-8 + LF
- **`--test` does not build anything** — it only checks the environment

## License

```LICENSE
Copyright (c) 2026 KagurazakaYashi
flutter-build-all is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details.
```
