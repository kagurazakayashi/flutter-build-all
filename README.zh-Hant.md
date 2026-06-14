# flutter-build-all — Flutter 全平台建置腳本

[English](README.md) | [简体中文](README.zh-Hans.md) | **繁體中文** | [日本語](README.ja.md)

一個 Dart CLI 工具，放在 Flutter 專案根目錄或作為 Git 子模組使用，一鍵建置到所有支援的平台。內建圖示生成（透過 flutter-icon-creator）與多語言生成功能，並自動附帶資源檔案與安裝腳本。

## 環境要求

- **Dart SDK** 3.4+
- **Flutter SDK**（任意穩定版本）

無需額外安裝 Python 或 pip 依賴。YAML 解析和 Markdown 轉換均為 Dart 內建套件，首次 `dart run` 時自動獲取。

## 快速開始

### 方式一：Git 子模組（推薦）

```bash
cd /path/to/your-flutter-project
git submodule add git@github.com:kagurazakayashi/flutter-build-all.git flutter-build-all
git submodule update --init --recursive
```

之後在專案根目錄執行：

```bash
dart flutter-build-all/bin/build_all.dart
```

也可建立捷徑腳本 `build-all.bat`（Windows）或 `build-all.sh`（Linux/macOS）：

```batch
:: build-all.bat
@ECHO OFF
CALL dart "flutter-build-all\bin\build_all.dart" %*
```

### 方式一之：編譯為獨立可執行檔

```bash
dart compile exe flutter-build-all/bin/build_all.dart -o build-all.exe
```

編譯後無需 Dart SDK，直接執行：

```bash
./build-all --target "windows,web"
```

### 方式二：直接複製檔案

將整個倉庫複製到專案中的子目錄，然後在專案根目錄執行：

```bash
dart tools/build-all/bin/build_all.dart
```

> 範本檔案（`.tmpl`）必須與 `build_all.dart` 保持在同一套件目錄下，工具透過腳本自身路徑查找範本。

## 使用範例

### 環境檢測

```bash
dart flutter-build-all/bin/build_all.dart --test
```

檢查 Dart / Flutter 版本、當前 OS 可建置的平台、pubspec.yaml 解析結果，不執行任何建置。

### 建置指定平台

```bash
# 僅建置 Windows
dart flutter-build-all/bin/build_all.dart --target "windows"

# 建置 Windows 和 Web
dart flutter-build-all/bin/build_all.dart --target "windows,web"

# 建置桌面端（跳過 Web 和行動端）
dart flutter-build-all/bin/build_all.dart --target "windows,linux,macos"
```

### 跳過靜態分析（快速建置）

```bash
dart flutter-build-all/bin/build_all.dart --analyze=off --target "windows"
```

### 跳過圖示自動生成

```bash
dart flutter-build-all/bin/build_all.dart --icon=off --target "windows"
```

### 平行建置

```bash
# 自動按 CPU 核心數平行
dart flutter-build-all/bin/build_all.dart --jobs 0

# 指定 4 個平行任務
dart flutter-build-all/bin/build_all.dart --jobs 4

# 平行 + 平台過濾
dart flutter-build-all/bin/build_all.dart --jobs 4 --target "linux,web"
```

### 自訂應用資訊

```bash
dart flutter-build-all/bin/build_all.dart \
  --name "MyApp" \
  --appver "2.0.0" \
  --appdesc "A powerful Flutter application" \
  --appicon "assets/icon.png" \
  --appcategory "Network;FileTransfer"
```

## 參數一覽

| 參數 | 簡寫 | 類型 | 預設值 | 說明 |
|------|------|------|--------|------|
| `--test` | `-t` | 旗標 | — | 僅檢測環境，不建置 |
| `--config` | `-f` | 字串 | `build-all.ini`（自動） | .ini 設定檔路徑 |
| `--target` | `-p` | 字串 | 全部可用平台 | 逗號分隔平台清單，如 `"windows,linux,web"` |
| `--name` | `-n` | 字串 | pubspec.yaml 自動 | 自訂輸出目錄名稱 |
| `--appver` | `-v` | 字串 | pubspec.yaml 自動 | 版本號，影響輸出目錄命名 |
| `--jobs` | `-j` | 整數 | 序列 | 平行任務數，`0` = CPU 核心數 |
| `--analyze` | `-A` | on/off | `on` | 建置前執行 `flutter analyze` |
| `--icon` | `-i` | on/off | `on` | 自動呼叫 flutter-icon-creator 生成全平台圖示 |
| `--l10n` | `-l` | on/off | `on` | 執行 `flutter gen-l10n` |
| `--web-embed-fonts` | `-w` | on/off | `off` | 下載 Flutter fallback 字型並內嵌到 Web 產物 |
| `--web-base-href` | `-b` | 字串 | `/` | Web 建置 base href |
| `--proxy` | `-x` | 字串 | 環境變數自動 | 字型下載代理（支援 http:// 與 socks5:// 格式） |
| `--appdesc` | `-d` | 字串 | 空 | 應用描述 |
| `--appgeneric` | `-g` | 字串 | 空 | 通用名稱 |
| `--appcategory` | `-c` | 字串 | `Utility` | Linux 桌面分類 |
| `--appicon` | `-a` | 字串 | `web/icons/Icon-192.png` | 圖示檔案路徑 |
| `--appiconbg` | `-B` | 字串 | 自動偵測 | 圖示背景圖片路徑（覆蓋 ico/iconb.png 自動偵測） |
| `--appidentifier` | `-I` | 字串 | 自動推導 | macOS Bundle ID |
| `--appmacoscategory` | `-m` | 字串 | `public.app-category.utilities` | macOS 應用分類 |
| `--project-dir` | `-r` | 字串 | 當前目錄 | Flutter 專案根目錄 |

## 設定檔

所有參數均可透過 `.ini` 設定檔設定，命令列參數始終優先。將 `build-all.ini` 放置於專案根目錄，或透過 `--config` 指定自訂路徑：

```ini
[project]
; 自訂輸出名稱（留空從 pubspec.yaml 自動偵測）
name = example_app
; 版本號，影響輸出目錄命名（留空自動偵測）
appver = 1.0.0
; 應用描述（用於 .desktop 檔案與 Info.plist）
appdesc = Example Application
; 通用名稱（用於桌面條目顯示）
appgeneric = ExampleApp

[platform]
; 目標平台，逗號分隔（如 "windows,linux,web"）
target = windows,linux,web

[build]
; 建置前執行 flutter analyze 靜態分析（on / off）
analyze = on
; 自動生成全平台圖示（on / off）
icon = on
; 執行 flutter gen-l10n 多語系生成（on / off）
l10n = on
; 平行建置任務數（0 = CPU 核心數，留空 = 序列模式）
jobs = 0

[web]
; 下載 Flutter fallback 字型並內嵌到 Web 建置產物（on / off）
web-embed-fonts = off
; Web 建置的 base href（如 "/"、"/myapp/"）
web-base-href = /
; 字型下載代理（支援 http:// 與 socks5:// 格式）
; proxy = socks5://192.168.1.45:23334

[desktop]
; Linux 桌面條目分類，分號分隔
appcategory = Utility
; 前景圖示檔案路徑（相對於專案根目錄）
appicon = web/icons/Icon-192.png
; 背景圖示圖片路徑（可選，覆蓋 ico/iconb.png 自動偵測）
; appiconbg =
; macOS Bundle Identifier（留空從 pubspec.yaml 自動推導）
appidentifier = com.example.app
; macOS 應用分類（UTI 格式）
appmacoscategory = public.app-category.utilities
```

命令列參數可暫時覆蓋設定檔的任意設定：

```bash
dart flutter-build-all/bin/build_all.dart -f my-config.ini -p "macos"
```

## 建置流程

1. 讀取 `pubspec.yaml`，獲取應用名稱和版本號
2. 自動檢測 `ico/iconf.png`、`ico/icon.png` 等圖示來源檔案，若存在則呼叫 flutter-icon-creator 生成全平台圖示（`--icon=off` 跳過）
3. 檢測 `lib/l10n/app_*.arb`，若存在則執行 `flutter gen-l10n`（`--l10n=off` 跳過）
4. 執行 `flutter analyze`（`--analyze=off` 跳過）
5. 根據當前 OS 枚舉可建置平台
5. 尋找專案根目錄下的 README 和 LICENSE 檔案
6. 逐個（或平行）執行 `flutter build`
7. 將建置產物、資源檔案、安裝腳本複製到 `bin/` 目錄

## 輸出結構

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

目錄命名規則：`{name}_v{ver}_{platform}`（有版本號時）或 `{name}_{platform}`。

## 平台特殊處理

- **Windows** — 自動檢測 `ico/`、`windows/runner/resources/` 下的圖示檔案；生成 `install_app.ps1`（UTF-8-BOM + CRLF）
- **Linux** — 生成 `install_app.sh`，支援 `install` / `uninstall` / `install_menu` / `install_desktop` 子命令
- **macOS** — Flutter 自動生成 `.app` Bundle；額外生成 `install_app.sh` 用於複製到 `/Applications`

## 注意事項

- **必須在 Flutter 專案根目錄下執行**（或使用 `--project-dir` 指定）
- 並非所有平台都能在當前 OS 上建置（如 iOS 需要 macOS）
- 每次執行會清空 `bin/` 目錄
- `--test` 不執行建置，僅檢測環境

## 授權條款

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

## 參見

- [go-build-all](https://github.com/kagurazakayashi/go-build-all) — Go 全平台交叉編譯工具，採用相同參數風格
