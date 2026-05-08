# flutter-build-all — Flutter 全プラットフォームビルドツール

[English](README.md) | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md) | **日本語**

Dart CLI ツールです。Flutter プロジェクトのルートに配置（または Git サブモジュールとして使用）し、全サポートプラットフォーム向けのビルドをワンコマンドで実行します。アイコン生成（flutter-icon-creator 経由）と l10n 生成を内蔵し、リソースファイルとインストールスクリプトも自動的にバンドルされます。

## 必要条件

- **Dart SDK** 3.4+
- **Flutter SDK**（任意の安定版）

Python や pip 依存は不要です。YAML 解析と Markdown 変換は Dart の組み込みパッケージで処理され、初回 `dart run` 時に自動取得されます。

## クイックスタート

### 方法1：Git サブモジュール（推奨）

```bash
cd /path/to/your-flutter-project
git submodule add git@github.com:kagurazakayashi/flutter-build-all.git flutter-build-all
git submodule update --init --recursive
```

プロジェクトルートから実行：

```bash
dart flutter-build-all/bin/build_all.dart
```

ラッパースクリプトも作成できます（例：`build-all.bat` / `build-all.sh`）：

```batch
:: build-all.bat
@ECHO OFF
CALL dart "flutter-build-all\bin\build_all.dart" %*
```

### おまけ：スタンドアロン実行ファイルにコンパイル

```bash
dart compile exe flutter-build-all/bin/build_all.dart -o build-all.exe
```

コンパイル後は Dart SDK 不要：

```bash
./build-all --target "windows,web"
```

### 方法2：ファイルコピー

リポジトリ全体をプロジェクトのサブディレクトリにコピーし、プロジェクトルートから実行：

```bash
dart tools/build-all/bin/build_all.dart
```

> テンプレートファイル（`.tmpl`）は `build_all.dart` と同じパッケージディレクトリに配置する必要があります。ツールは自身のスクリプトパスからテンプレートを検索します。

## 使用例

### 環境チェック

```bash
dart flutter-build-all/bin/build_all.dart --test
```

Dart / Flutter のバージョン、現在の OS でビルド可能なプラットフォーム、pubspec.yaml の解析結果を表示します（ビルドは実行しません）。

### 特定プラットフォームのビルド

```bash
# Windows のみ
dart flutter-build-all/bin/build_all.dart --target "windows"

# Windows と Web
dart flutter-build-all/bin/build_all.dart --target "windows,web"

# デスクトップのみ（Web とモバイルをスキップ）
dart flutter-build-all/bin/build_all.dart --target "windows,linux,macos"
```

### 静的解析をスキップ（高速ビルド）

```bash
dart flutter-build-all/bin/build_all.dart --analyze=off --target "windows"
```

### アイコン生成をスキップ

```bash
dart flutter-build-all/bin/build_all.dart --icon=off --target "windows"
```

### 並列ビルド

```bash
# CPU コア数に応じて自動並列化
dart flutter-build-all/bin/build_all.dart --jobs 0

# 4 並列
dart flutter-build-all/bin/build_all.dart --jobs 4

# 並列 + プラットフォームフィルター
dart flutter-build-all/bin/build_all.dart --jobs 4 --target "linux,web"
```

### アプリ情報のカスタマイズ

```bash
dart flutter-build-all/bin/build_all.dart \
  --name "MyApp" \
  --appver "2.0.0" \
  --appdesc "A powerful Flutter application" \
  --appicon "assets/icon.png" \
  --appcategory "Network;FileTransfer"
```

## オプション一覧

| オプション | 略称 | 型 | デフォルト | 説明 |
|-----------|------|------|---------|------|
| `--test` | `-t` | フラグ | — | 環境チェックのみ、ビルドなし |
| `--config` | `-f` | 文字列 | `build-all.ini`（自動） | .ini 設定ファイルのパス |
| `--target` | `-p` | 文字列 | 全利用可能 | カンマ区切りプラットフォーム、例 `"windows,linux,web"` |
| `--name` | `-n` | 文字列 | pubspec.yaml から自動 | 出力ディレクトリ名 |
| `--appver` | `-v` | 文字列 | pubspec.yaml から自動 | アプリバージョン |
| `--jobs` | `-j` | 整数 | シーケンシャル | 並列ジョブ数。`0` = CPU コア数自動 |
| `--analyze` | `-A` | on/off | `on` | ビルド前に `flutter analyze` を実行 |
| `--icon` | `-i` | on/off | `on` | flutter-icon-creator で全プラットフォームアイコンを自動生成 |
| `--l10n` | `-l` | on/off | `on` | `flutter gen-l10n` を実行 |
| `--web-embed-fonts` | `-w` | on/off | `off` | Flutter フォールバックフォントをダウンロードして Web 出力に埋め込む |
| `--web-base-href` | `-b` | 文字列 | `/` | Web ビルドの base href |
| `--appdesc` | `-d` | 文字列 | 空 | アプリ説明 |
| `--appgeneric` | `-g` | 文字列 | 空 | 一般名 |
| `--appcategory` | `-c` | 文字列 | `Utility` | Linux デスクトップカテゴリ |
| `--appicon` | `-a` | 文字列 | `web/icons/Icon-192.png` | アイコンファイルのパス |
| `--appiconbg` | `-B` | 文字列 | 自動検出 | 背景アイコン画像のパス（ico/iconb.png の自動検出を上書き） |
| `--appidentifier` | `-I` | 文字列 | 自動導出 | macOS Bundle ID |
| `--appmacoscategory` | `-m` | 文字列 | `public.app-category.utilities` | macOS アプリカテゴリ |
| `--project-dir` | `-r` | 文字列 | カレント | Flutter プロジェクトルート |

## 設定ファイル

すべてのオプションは `.ini` ファイルで設定可能です。コマンドライン引数が常に優先されます。プロジェクトルートに `build-all.ini` を置くか、`--config` でカスタムパスを指定します：

```ini
[project]
; 出力名（空の場合は pubspec.yaml から自動検出）
name = example_app
; アプリバージョン（空の場合は自動検出）
appver = 1.0.0
; アプリ説明（.desktop ファイルと Info.plist 用）
appdesc = Example Application
; 一般名（デスクトップエントリ表示用）
appgeneric = ExampleApp

[platform]
; ターゲットプラットフォーム、カンマ区切り（例 "windows,linux,web"）
target = windows,linux,web

[build]
; ビルド前に flutter analyze を実行（on / off）
analyze = on
; 全プラットフォームアイコンを自動生成（on / off）
icon = on
; flutter gen-l10n を実行（on / off）
l10n = on
; 並列ジョブ数（0 = CPU コア数、空 = シーケンシャル）
jobs = 0

[web]
; Flutter フォールバックフォントを Web 出力に埋め込む（on / off）
web-embed-fonts = off
; Web ビルドの base href（例 "/"、"/myapp/"）
web-base-href = /

[desktop]
; Linux デスクトップエントリのカテゴリ、セミコロン区切り
appcategory = Utility
; 前景アイコンファイルのパス（プロジェクトルートからの相対パス）
appicon = web/icons/Icon-192.png
; 背景アイコン画像のパス（オプション、ico/iconb.png の自動検出を上書き）
; appiconbg =
; macOS Bundle Identifier（空の場合は pubspec.yaml から自動導出）
appidentifier = com.example.app
; macOS アプリカテゴリ（UTI 形式）
appmacoscategory = public.app-category.utilities
```

コマンドライン引数で個別に上書き可能です：

```bash
dart flutter-build-all/bin/build_all.dart -f my-config.ini -p "macos"
```

## ビルドプロセス

1. `pubspec.yaml` からアプリ名とバージョンを読み取り
2. `ico/iconf.png`、`ico/icon.png` などのアイコンソースファイルを自動検出し、flutter-icon-creator で全プラットフォームアイコンを生成（`--icon=off` でスキップ）
3. `lib/l10n/app_*.arb` を検出し、存在すれば `flutter gen-l10n` を実行（`--l10n=off` でスキップ）
4. `flutter analyze` を実行（`--analyze=off` でスキップ）
5. 現在の OS に基づいてビルド可能なプラットフォームを列挙
5. プロジェクトルートの README と LICENSE を検索
6. 各プラットフォームで `flutter build` を実行（`--jobs` で並列化）
7. ビルド成果物、リソース、インストールスクリプトを `bin/` にコピー

## 出力構造

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

命名規則：`{name}_v{ver}_{platform}`（バージョンあり）または `{name}_{platform}`。

## プラットフォーム固有

- **Windows** — `ico/` や `windows/runner/resources/` からアイコンを自動検出；`install_app.ps1` を生成（UTF-8-BOM + CRLF）
- **Linux** — `install_app.sh` を生成、`install` / `uninstall` / `install_menu` / `install_desktop` サブコマンド対応
- **macOS** — Flutter が `.app` バンドルを自動生成；さらに `/Applications` へのコピー用 `install_app.sh` を生成

## 注意事項

- Flutter プロジェクトルート（`pubspec.yaml` がある場所）で実行してください（または `--project-dir` を指定）
- すべてのプラットフォームがすべての OS でビルドできるわけではありません（例：iOS は macOS が必要）
- `bin/` ディレクトリは実行のたびにクリアされます
- `--test` は環境チェックのみで、ビルドは実行しません

## ライセンス

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

## 関連

- [go-build-all](https://github.com/kagurazakayashi/go-build-all) — 同じパラメータ形式の Go クロスコンパイルツール
