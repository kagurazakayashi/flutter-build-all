# flutter-build-all — Flutter 全平台编译脚本

[English](README.md) | **简体中文** | [繁體中文](README.zh-Hant.md) | [日本語](README.ja.md)

一个 Dart CLI 工具，放在 Flutter 项目根目录或作为 Git 子模块使用，一键编译到所有支持的平台。内置图标生成（通过 flutter-icon-creator）和多语言生成功能，并自动附带资源文件和安装脚本。

## 环境要求

- **Dart SDK** 3.4+
- **Flutter SDK**（任意稳定版本）

无需额外安装 Python 或 pip 依赖。YAML 解析和 Markdown 转换均为 Dart 内置包，首次 `dart run` 时自动获取。

## 快速开始

### 方式一：Git 子模块（推荐）

```bash
cd /path/to/your-flutter-project
git submodule add git@github.com:kagurazakayashi/flutter-build-all.git flutter-build-all
git submodule update --init --recursive
```

之后在项目根目录执行：

```bash
dart flutter-build-all/bin/build_all.dart
```

也可创建快捷脚本 `build-all.bat`（Windows）或 `build-all.sh`（Linux/macOS）：

```batch
:: build-all.bat
@ECHO OFF
CALL dart "flutter-build-all\bin\build_all.dart" %*
```

### 方式一之：编译为独立可执行文件

```bash
dart compile exe flutter-build-all/bin/build_all.dart -o build-all.exe
```

编译后无需 Dart SDK，直接运行：

```bash
./build-all --target "windows,web"
```

### 方式二：直接复制文件

将整个仓库复制到项目中的子目录，然后在项目根目录运行：

```bash
dart tools/build-all/bin/build_all.dart
```

> 模板文件（`.tmpl`）必须与 `build_all.dart` 保持在同一个包目录下，工具通过脚本自身路径查找模板。

## 使用示例

### 环境检测

```bash
dart flutter-build-all/bin/build_all.dart --test
```

检查 Dart / Flutter 版本、当前 OS 可编译的平台、pubspec.yaml 解析结果，不执行任何构建。

### 编译指定平台

```bash
# 仅编译 Windows
dart flutter-build-all/bin/build_all.dart --target "windows"

# 编译 Windows 和 Web
dart flutter-build-all/bin/build_all.dart --target "windows,web"

# 编译桌面端（跳过 Web 和移动端）
dart flutter-build-all/bin/build_all.dart --target "windows,linux,macos"
```

### 跳过静态分析（快速构建）

```bash
dart flutter-build-all/bin/build_all.dart --analyze=off --target "windows"
```

### 跳过图标生成

```bash
dart flutter-build-all/bin/build_all.dart --icon=off --target "windows"
```

### 并行编译

```bash
# 自动按 CPU 核心数并行
dart flutter-build-all/bin/build_all.dart --jobs 0

# 指定 4 个并行任务
dart flutter-build-all/bin/build_all.dart --jobs 4

# 并行 + 平台过滤
dart flutter-build-all/bin/build_all.dart --jobs 4 --target "linux,web"
```

### 自定义应用信息

```bash
dart flutter-build-all/bin/build_all.dart \
  --name "MyApp" \
  --appver "2.0.0" \
  --appdesc "A powerful Flutter application" \
  --appicon "assets/icon.png" \
  --appcategory "Network;FileTransfer"
```

## 参数一览

| 参数 | 简写 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--test` | `-t` | 标志 | — | 仅检测环境，不构建 |
| `--config` | `-f` | 字符串 | `build-all.ini`（自动） | .ini 配置文件路径 |
| `--target` | `-p` | 字符串 | 全部可用平台 | 逗号分隔平台列表，如 `"windows,linux,web"` |
| `--name` | `-n` | 字符串 | pubspec.yaml 自动 | 自定义输出目录名称 |
| `--appver` | `-v` | 字符串 | pubspec.yaml 自动 | 版本号，影响输出目录命名 |
| `--jobs` | `-j` | 整数 | 串行 | 并行任务数，`0` = CPU 核心数 |
| `--analyze` | `-A` | on/off | `on` | 构建前执行 `flutter analyze` |
| `--icon` | `-i` | on/off | `on` | 自动调用 flutter-icon-creator 生成全平台图标 |
| `--l10n` | `-l` | on/off | `on` | 执行 `flutter gen-l10n` |
| `--web-embed-fonts` | `-w` | on/off | `off` | 下载 Flutter fallback 字型并内嵌到 Web 产物 |
| `--web-base-href` | `-b` | 字符串 | `/` | Web 构建 base href |
| `--proxy` | `-x` | 字符串 | 环境变量自动 | 字体下载代理（支持 http:// 与 socks5:// 格式） |
| `--appdesc` | `-d` | 字符串 | 空 | 应用描述 |
| `--appgeneric` | `-g` | 字符串 | 空 | 通用名称 |
| `--appcategory` | `-c` | 字符串 | `Utility` | Linux 桌面分类 |
| `--appicon` | `-a` | 字符串 | `web/icons/Icon-192.png` | 图标文件路径 |
| `--appiconbg` | `-B` | 字符串 | 自动检测 | 图标背景图片路径（覆盖 ico/iconb.png 自动检测） |
| `--appidentifier` | `-I` | 字符串 | 自动推导 | macOS Bundle ID |
| `--appmacoscategory` | `-m` | 字符串 | `public.app-category.utilities` | macOS 应用分类 |
| `--project-dir` | `-r` | 字符串 | 当前目录 | Flutter 项目根目录 |

## 配置文件

所有参数均可通过 `.ini` 配置文件设定，命令行参数始终优先。将 `build-all.ini` 放置于项目根目录，或通过 `--config` 指定自定义路径：

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
; Web 构建的 base href（如 "/"、"/myapp/"）
web-base-href = /
; 字体下载代理（支持 http:// 与 socks5:// 格式）
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

命令行参数可临时覆盖配置文件的任意设定：

```bash
dart flutter-build-all/bin/build_all.dart -f my-config.ini -p "macos"
```

## 编译流程

1. 读取 `pubspec.yaml`，获取应用名和版本号
2. 自动检测 `ico/iconf.png`、`ico/icon.png` 等图标源文件，若存在则调用 flutter-icon-creator 生成全平台图标（`--icon=off` 跳过）
3. 检测 `lib/l10n/app_*.arb`，若存在则执行 `flutter gen-l10n`（`--l10n=off` 跳过）
4. 执行 `flutter analyze`（`--analyze=off` 跳过）
5. 根据当前 OS 枚举可编译平台
5. 查找项目根目录下的 README 和 LICENSE 文件
6. 逐个（或并行）执行 `flutter build`
7. 将构建产物、资源文件、安装脚本复制到 `bin/` 目录

## 输出结构

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

目录命名规则：`{name}_v{ver}_{platform}`（有版本号时）或 `{name}_{platform}`。

## 平台特殊处理

- **Windows** — 自动检测 `ico/`、`windows/runner/resources/` 下的图标文件；生成 `install_app.ps1`（UTF-8-BOM + CRLF）
- **Linux** — 生成 `install_app.sh`，支持 `install` / `uninstall` / `install_menu` / `install_desktop` 子命令
- **macOS** — Flutter 自动生成 `.app` Bundle；额外生成 `install_app.sh` 用于复制到 `/Applications`

## 注意事项

- **必须在 Flutter 项目根目录下运行**（或使用 `--project-dir` 指定）
- 并非所有平台都能在当前 OS 上编译（如 iOS 需要 macOS）
- 每次运行会清空 `bin/` 目录
- `--test` 不执行编译，仅检测环境

## 许可证

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

## 参见

- [go-build-all](https://github.com/kagurazakayashi/go-build-all) — Go 全平台交叉编译工具，采用相同参数风格
