# flutter-build-all — Flutter 全平台建置腳本

[English](README.md) | [简体中文](README.zh-Hans.md) | **繁體中文** | [日本語](README.ja.md)

一個獨立的 Python 3 腳本（`build_all.py`），放在 Flutter 專案根目錄下執行，即可一鍵建置該 Flutter 專案到所有支援的平台，並自動附帶資源檔案與安裝腳本。

## 目錄

- [功能概覽](#功能概覽)
- [第三方庫](#第三方庫)
- [引入方式](#引入方式)
  - [方式一：複製檔案](#方式一複製檔案)
  - [方式二：Git 子模組](#方式二git-子模組)
- [使用方法](#使用方法)
  - [快速開始](#快速開始)
  - [按平台過濾建置](#按平台過濾建置)
  - [Web 渲染器](#web-渲染器)
- [參數詳解](#參數詳解)
- [建置流程](#建置流程)
- [輸出目錄結構](#輸出目錄結構)
- [注意事項](#注意事項)

## 功能概覽

- 讀取 `pubspec.yaml` 取得應用名稱與版本號
- 枚舉所有可用的 Flutter 平台（`windows`、`linux`、`macos`、`web`、`android`、`ios`）
- 自動檢測 `l10n/app_*.arb` 檔案，建置前執行 `flutter gen-l10n`
- 建置前執行 `flutter analyze` 進行靜態檢查
- 將 README 檔案（支援 Markdown 轉 HTML，可選的第三方庫）和 LICENSE 檔案一併打包
- **Linux**：生成 `install_app.sh`，支援建立/移除桌面捷徑與 `.desktop` 選單項目
- **Windows**：生成 `install_app.ps1`，支援建立/移除開始選單和桌面捷徑
- **macOS**：生成 `install_app.sh`，用於將 `.app` 安裝到 `/Applications`
- **平行建置**：使用 `--jobs` 參數可平行建置多個平台

## 第三方庫

| 庫            | 用途                                                       | 安裝方法                 | 是否必須                                      |
| ------------- | ---------------------------------------------------------- | ------------------------ | --------------------------------------------- |
| `pyyaml`      | 解析 `pubspec.yaml` 以讀取應用名稱和版本號                 | `pip install pyyaml`     | 否。未安裝時使用正規表示式回退方案            |
| `markdown`    | 將 README.md 轉換為 HTML 並隨建置輸出一併打包               | `pip install markdown`   | 否。未安裝時 README 以純文字 `.txt` 形式輸出  |

## 引入方式

### 方式一：複製檔案

將本倉庫中的以下檔案複製到你的 Flutter 專案根目錄：

```
你的專案/
├── build_all.py          # 主腳本（必需）
├── install_app.sh.tmpl   # Linux 安裝腳本範本
├── install_app.ps1.tmpl  # Windows 安裝腳本範本
└── Info.plist.tmpl       # macOS App Bundle 範本（預留）
```

如果不需要某個平台的打包功能，對應的範本檔案可以省略。

### 方式二：Git 子模組

```bash
# 在你的 Flutter 專案根目錄下執行
git submodule add git@github.com:kagurazakayashi/flutter-build-all.git tools/build-all
git submodule update --init --recursive
```

子模組引入後，使用時需要指定 `--project-dir` 參數（或在專案目錄中直接呼叫子模組中的腳本）：

```bash
# 在專案根目錄執行
python tools/build-all/build_all.py

# 或在任意目錄執行
python tools/build-all/build_all.py --project-dir /path/to/your-flutter-project
```

## 使用方法

### 快速開始

```bash
cd /path/to/你的Flutter專案
python build_all.py
```

輸出將存放在 `bin/` 目錄下，每個平台一個子目錄。

### 按平台過濾建置

```bash
# 僅建置 Windows
python build_all.py --target "windows"

# 僅建置 Windows 和 Linux
python build_all.py --target "windows,linux"

# 跳過 Web 建置
python build_all.py --no-web
```

### Web 渲染器

```bash
python build_all.py --target "web" --web-renderer canvaskit
```

### 平行建置

```bash
python build_all.py --jobs 0
```

## 參數詳解

### 基礎參數

| 參數             | 類型    | 預設值                 | 說明                                                        |
| ---------------- | ------- | ---------------------- | ----------------------------------------------------------- |
| `--test`         | 旗標    | 無                     | 檢查建置環境，不執行實際建置                                |
| `--name`         | 字串    | 從 `pubspec.yaml` 取得 | 自訂輸出目錄名稱                                            |
| `--target`       | 字串    | 無（全部平台）         | 逗號分隔的平台過濾清單，例如 `"windows,linux,web"`          |
| `--appver`       | 字串    | 自動檢測               | 應用版本號                                                  |
| `--web-renderer` | 字串    | `auto`                 | Web 渲染器：`auto`、`canvaskit` 或 `html`                   |
| `--no-web`       | 旗標    | 無                     | 跳過 Web 平台建置                                           |
| `--skip-analyze` | 旗標    | 無                     | 跳過 `flutter analyze` 步驟                                 |
| `--jobs`         | 整數    | 無（序列）             | 平行建置任務數                                              |

### 應用資訊參數

| 參數                 | 類型   | 預設值                          | 說明               |
| -------------------- | ------ | ------------------------------- | ------------------ |
| `--appdesc`          | 字串   | 空                              | 應用描述           |
| `--appgeneric`       | 字串   | 空                              | 應用通用名稱       |
| `--appcategory`      | 字串   | `Utility`                       | Linux 桌面分類     |
| `--appicon`          | 字串   | `web/icons/Icon-192.png`        | 圖示檔案路徑       |
| `--appidentifier`    | 字串   | 從 app name 推導                | macOS Bundle ID    |
| `--appmacoscategory` | 字串   | `public.app-category.utilities` | macOS 應用分類     |

### 路徑參數

| 參數            | 類型   | 預設值   | 說明                       |
| --------------- | ------ | -------- | -------------------------- |
| `--project-dir` | 字串   | 當前目錄 | 指定 Flutter 專案根目錄    |

## 建置流程

1. **專案檢查** — 驗證 `pubspec.yaml` 存在並讀取 `name` 欄位
2. **本地化生成** — 檢測 `l10n/app_*.arb`，若存在則執行 `flutter gen-l10n`
3. **靜態檢查** — 執行 `flutter analyze`
4. **讀取專案資訊** — 從 `pubspec.yaml` 讀取應用名稱和版本號
5. **枚舉平台** — 根據當前作業系統確定可建置的平台
6. **查找資源** — 查找專案根目錄下的 README 和 LICENSE 檔案
7. **逐個建置** — 對每個平台執行 `flutter build`
8. **後處理** — 將建置產物、資源檔案、安裝腳本複製到 `bin/` 目錄

## 輸出目錄結構

```
bin/
├── myapp_v2.0.0_windows/
├── myapp_v2.0.0_linux/
├── myapp_v2.0.0_macos/
├── myapp_v2.0.0_web/
├── myapp_v2.0.0_android/
└── ...
```

## 注意事項

- **必須在 Flutter 專案根目錄下執行** — 腳本需要讀取 `pubspec.yaml`
- **Python 版本** — 需要 Python 3.6 及以上
- **平台可用性** — 並非所有平台都能在所有作業系統上建置（例如 iOS 需要 macOS）
- **`pyyaml` 庫是可選的** — 未安裝時使用正規表示式回退解析
- **輸出覆蓋** — 每次執行會清空 `bin/` 目錄

## 許可證

```LICENSE
Copyright (c) 2026 KagurazakaYashi
flutter-build-all is licensed under Mulan PSL v2.
```
