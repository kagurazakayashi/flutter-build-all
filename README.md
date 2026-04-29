# flutter-build-all — Flutter all-platform build script

**English** | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md) | [日本語](README.ja.md)

A Dart CLI tool placed in the root of a Flutter project (or used as a Git submodule) that builds the project for all supported platforms in one command, with automatic bundling of resource files and install scripts.

## Requirements

- **Dart SDK** 3.4+
- **Flutter SDK** (any stable version)

No Python or pip dependencies needed. YAML parsing and Markdown conversion are handled by built-in Dart packages, fetched automatically on the first `dart run`.

## Quick Start

### Method 1: Git Submodule (Recommended)

```bash
cd /path/to/your-flutter-project
git submodule add git@github.com:kagurazakayashi/flutter-build-all.git flutter-build-all
git submodule update --init --recursive
```

Then run from the project root:

```bash
dart flutter-build-all/bin/build_all.dart
```

You can also create a wrapper script, e.g. `build-all.bat` (Windows) or `build-all.sh` (Linux/macOS):

```batch
:: build-all.bat
@ECHO OFF
CALL dart "flutter-build-all\bin\build_all.dart" %*
```

### Bonus: Compile to Standalone Executable

```bash
dart compile exe flutter-build-all/bin/build_all.dart -o build-all.exe
```

Once compiled, no Dart SDK is needed:

```bash
./build-all --target "windows,web"
```

### Method 2: Copy Files

Copy the entire repository into a subdirectory of your project, then run from the project root:

```bash
dart tools/build-all/bin/build_all.dart
```

> Template files (`.tmpl`) must reside in the same package directory as `build_all.dart`. The tool locates templates relative to its own script path.

## Usage Examples

### Environment Check

```bash
dart flutter-build-all/bin/build_all.dart --test
```

Checks Dart/Flutter versions, available platforms on the current OS, and pubspec.yaml parsing — no builds performed.

### Build Specific Platforms

```bash
# Windows only
dart flutter-build-all/bin/build_all.dart --target "windows"

# Windows and Web
dart flutter-build-all/bin/build_all.dart --target "windows,web"

# Desktop only (skip Web and mobile)
dart flutter-build-all/bin/build_all.dart --target "windows,linux,macos"

# Skip Web
dart flutter-build-all/bin/build_all.dart --no-web
```

### Skip Static Analysis (Quick Build)

```bash
dart flutter-build-all/bin/build_all.dart --skip-analyze --target "windows"
```

### Parallel Builds

```bash
# Auto-detect CPU core count
dart flutter-build-all/bin/build_all.dart --jobs 0

# 4 parallel jobs
dart flutter-build-all/bin/build_all.dart --jobs 4

# Parallel + platform filter
dart flutter-build-all/bin/build_all.dart --jobs 4 --target "linux,web"
```

### Custom App Info

```bash
dart flutter-build-all/bin/build_all.dart \
  --name "MyApp" \
  --appver "2.0.0" \
  --appdesc "A powerful Flutter application" \
  --appicon "assets/icon.png" \
  --appcategory "Network;FileTransfer"
```

### Web Renderer

```bash
dart flutter-build-all/bin/build_all.dart --target "web" --web-renderer canvaskit
```

Options: `auto` (default), `canvaskit`, `html`

## Options Reference

### Basic

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--test` | flag | — | Check environment only, no build |
| `--name` | string | auto from pubspec.yaml | Custom output directory name |
| `--target` | string | all available | Comma-separated platforms, e.g. `"windows,linux,web"` |
| `--appver` | string | auto from pubspec.yaml | App version (affects output directory naming) |
| `--web-renderer` | string | `auto` | Web renderer: `auto` / `canvaskit` / `html` |
| `--no-web` | flag | — | Skip Web platform |
| `--skip-analyze` | flag | — | Skip `flutter analyze` |
| `--jobs` | integer | sequential | Parallel job count. `0` = auto-detect CPU cores |

### App Info

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--appdesc` | string | empty | Application description |
| `--appgeneric` | string | empty | Generic app name |
| `--appcategory` | string | `Utility` | Linux desktop categories, semicolon-separated |
| `--appicon` | string | `web/icons/Icon-192.png` | Icon file path within the project |
| `--appidentifier` | string | auto-derived | macOS Bundle Identifier |
| `--appmacoscategory` | string | `public.app-category.utilities` | macOS app category |

### Path

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--project-dir` | string | current directory | Flutter project root directory |

## Build Process

1. Read `pubspec.yaml` for app name and version
2. Detect `lib/l10n/app_*.arb` and run `flutter gen-l10n` if present
3. Run `flutter analyze` (skip with `--skip-analyze`)
4. Enumerate buildable platforms based on current OS
5. Locate README and LICENSE files in the project root
6. Run `flutter build` for each platform (parallel with `--jobs`)
7. Copy build artifacts, resource files, and install scripts to `bin/`

## Output Structure

```
bin/
├── myapp_v2.0.0_windows/
│   ├── myapp.exe
│   ├── data/
│   ├── flutter_windows.dll
│   ├── README.html
│   ├── LICENSE.txt
│   ├── install_app.ps1
│   └── app_icon.ico
├── myapp_v2.0.0_linux/
├── myapp_v2.0.0_web/
└── ...
```

Naming convention: `{name}_v{ver}_{platform}` (with version) or `{name}_{platform}`.

## Platform-Specific

- **Windows** — Auto-detects icon from `ico/` or `windows/runner/resources/`; generates `install_app.ps1` (UTF-8-BOM + CRLF)
- **Linux** — Generates `install_app.sh` with `install` / `uninstall` / `install_menu` / `install_desktop` subcommands
- **macOS** — Flutter auto-generates `.app` bundle; extra `install_app.sh` for copying to `/Applications`

## Notes

- **Must run in a Flutter project root** (or use `--project-dir`)
- Not all platforms are buildable on all OSes (e.g. iOS requires macOS)
- The `bin/` directory is cleared on each run
- `--test` only checks the environment — it does not build anything

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
