# flutter-build-all — Flutter 全平台编译脚本

[English](README.md) | **简体中文** | [繁體中文](README.zh-Hant.md) | [日本語](README.ja.md)

一个独立的 Python 3 脚本（`build_all.py`），放在 Flutter 项目根目录下运行，即可一键编译该 Flutter 项目到所有支持的平台，并自动附带资源文件和安装脚本。

## 目录

- [功能概览](#功能概览)
- [第三方库](#第三方库)
- [引入方式](#引入方式)
  - [方式一：复制文件](#方式一复制文件)
  - [方式二：Git 子模块](#方式二git-子模块)
- [使用方法](#使用方法)
  - [快速开始](#快速开始)
  - [按平台过滤编译](#按平台过滤编译)
  - [Web 渲染器](#web-渲染器)
- [参数详解](#参数详解)
  - [基础参数](#基础参数)
  - [应用信息参数](#应用信息参数)
  - [路径参数](#路径参数)
- [编译流程](#编译流程)
- [输出目录结构](#输出目录结构)
- [平台特殊处理](#平台特殊处理)
  - [Linux](#linux)
  - [Windows](#windows)
  - [macOS](#macos)
- [模板文件](#模板文件)
- [测试](#测试)
- [注意事项](#注意事项)

## 功能概览

- 读取 `pubspec.yaml` 获取应用名称和版本号
- 枚举所有可用的 Flutter 平台（`windows`、`linux`、`macos`、`web`、`android`、`ios`）
- 自动检测 `l10n/app_*.arb` 文件，构建前运行 `flutter gen-l10n`
- 构建前执行 `flutter analyze` 进行静态检查
- 将 README 文件（支持 Markdown 转 HTML，可选的第三方库）和 LICENSE 文件一并打包
- **Linux**：生成 `install_app.sh`，支持创建/移除桌面快捷方式和 `.desktop` 菜单项
- **Windows**：生成 `install_app.ps1`，支持创建/移除开始菜单和桌面快捷方式
- **macOS**：生成 `install_app.sh`，用于将 `.app` 安装到 `/Applications`
- **并行编译**：使用 `--jobs` 参数可并行编译多个平台

## 第三方库

| 库            | 用途                                                       | 安装方法                 | 是否必须                                      |
| ------------- | ---------------------------------------------------------- | ------------------------ | --------------------------------------------- |
| `pyyaml`      | 解析 `pubspec.yaml` 以读取应用名称和版本号                 | `pip install pyyaml`     | 否。未安装时使用正则表达式回退方案            |
| `markdown`    | 将 README.md 转换为 HTML 并随构建输出一并打包               | `pip install markdown`   | 否。未安装时 README 以纯文本 `.txt` 形式输出  |

## 引入方式

### 方式一：复制文件

将本仓库中的以下文件复制到你的 Flutter 项目根目录：

```
你的项目/
├── build_all.py          # 主脚本（必需）
├── install_app.sh.tmpl   # Linux 安装脚本模板
├── install_app.ps1.tmpl  # Windows 安装脚本模板
└── Info.plist.tmpl       # macOS App Bundle 模板（预留）
```

如果不需要某个平台的打包功能，对应的模板文件可以省略。

### 方式二：Git 子模块

```bash
# 在你的 Flutter 项目根目录下执行
git submodule add git@github.com:kagurazakayashi/flutter-build-all.git tools/build-all
git submodule update --init --recursive
```

子模块引入后，使用时需要指定 `--project-dir` 参数（或在项目目录中直接调用子模块中的脚本）：

```bash
# 在项目根目录运行
python tools/build-all/build_all.py

# 或在任意目录运行
python tools/build-all/build_all.py --project-dir /path/to/your-flutter-project
```

> **注意**：模板文件（`.tmpl`）位于子模块目录中，脚本通过 `SCRIPT_DIR`（脚本自身所在目录）查找模板，因此只要 `build_all.py` 能访问到同目录的 `.tmpl` 文件即可正常工作。

## 使用方法

### 快速开始

```bash
cd /path/to/你的Flutter项目
python build_all.py
```

> 必须确保当前目录（或 `--project-dir` 指定的目录）是一个 Flutter 项目（存在 `pubspec.yaml`）。

输出将存放在 `bin/` 目录下，每个平台一个子目录。

### 按平台过滤编译

```bash
# 仅编译 Windows
python build_all.py --target "windows"

# 仅编译 Windows 和 Linux
python build_all.py --target "windows,linux"

# 编译 Linux 和 Web
python build_all.py --target "linux,web"

# 跳过 Web 编译
python build_all.py --no-web
```

`--target` 接受逗号分隔的平台名称。当前操作系统不支持的平台会自动跳过。

### Web 渲染器

```bash
# 使用 CanvasKit 渲染器
python build_all.py --target "web" --web-renderer canvaskit

# 使用 HTML 渲染器
python build_all.py --target "web" --web-renderer html
```

可选值：`auto`（默认）、`canvaskit`、`html`。

### 并行编译

```bash
# 自动按 CPU 核心数并行编译
python build_all.py --jobs 0

# 指定 4 个并行任务
python build_all.py --jobs 4

# 结合平台过滤
python build_all.py --jobs 4 --target "linux,web"
```

## 参数详解

### 基础参数

| 参数             | 类型    | 默认值                 | 说明                                                                                                |
| ---------------- | ------- | ---------------------- | --------------------------------------------------------------------------------------------------- |
| `--test`         | 标志    | 无                     | 检查编译环境（Python、Flutter、可用平台），不执行实际编译                                           |
| `--name`         | 字符串  | 从 `pubspec.yaml` 获取 | 自定义输出目录名称。对应 `pubspec.yaml` 中的 `name` 字段                                            |
| `--target`       | 字符串  | 无（全部平台）         | 逗号分隔的平台过滤列表。例如 `"windows,linux,web"`                                                  |
| `--appver`       | 字符串  | 自动检测               | 应用版本号，会附加到输出目录名中。未指定时自动从 `pubspec.yaml` 读取                                |
| `--web-renderer` | 字符串  | `auto`                 | Web 渲染器：`auto`、`canvaskit` 或 `html`                                                           |
| `--no-web`       | 标志    | 无                     | 跳过 Web 平台编译                                                                                   |
| `--skip-analyze` | 标志    | 无                     | 跳过 `flutter analyze` 步骤（适用于快速编译）                                                       |
| `--jobs`         | 整数    | 无（串行）             | 并行编译任务数。`0` 表示按 CPU 核心数自动设置。不指定时串行编译                                     |

### 应用信息参数

| 参数                 | 类型   | 默认值                          | 说明                                                                                                                     |
| -------------------- | ------ | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `--appdesc`          | 字符串 | 空                              | 应用描述。Linux 桌面入口的 `Comment`；Windows 快捷方式的 `Description`；macOS `Info.plist` 的 `NSHumanReadableCopyright` |
| `--appgeneric`       | 字符串 | 空                              | 应用通用名称。Linux 桌面入口的 `GenericName`；macOS `Info.plist` 的 `CFBundleDisplayName`                                |
| `--appcategory`      | 字符串 | `Utility`                       | Linux 桌面入口的 `Categories`，多个分类用分号分隔。例如 `"Network;FileTransfer"`                                         |
| `--appicon`          | 字符串 | `web/icons/Icon-192.png`        | Linux 图标文件在项目内的路径。Windows 和 macOS 会自动检测对应的图标文件                                                  |
| `--appidentifier`    | 字符串 | 从 app name 推导                | macOS Bundle Identifier                                                                                                  |
| `--appmacoscategory` | 字符串 | `public.app-category.utilities` | macOS 应用分类。例如 `public.app-category.developer-tools`                                                               |

### 路径参数

| 参数            | 类型   | 默认值   | 说明                                                                    |
| --------------- | ------ | -------- | ----------------------------------------------------------------------- |
| `--project-dir` | 字符串 | 当前目录 | 指定 Flutter 项目根目录。适用于脚本不在项目根目录下的情况（如子模块）   |

## 编译流程

脚本运行后，按以下顺序执行：

1. **项目检查** — 验证 `pubspec.yaml` 存在并读取 `name` 字段
2. **本地化生成** — 检测 `l10n/app_*.arb`，若存在则运行 `flutter gen-l10n`
3. **静态检查** — 执行 `flutter analyze`，失败则终止（可用 `--skip-analyze` 跳过）
4. **读取项目信息** — 从 `pubspec.yaml` 读取应用名称和版本号
5. **枚举平台** — 根据当前操作系统确定可编译的平台
6. **查找资源** — 查找项目根目录下的 README 和 LICENSE 文件
7. **逐个编译** — 对每个平台执行 `flutter build`（指定 `--jobs` 时可并行编译）：
   - 桌面端：`flutter build windows/linux/macos`
   - Web：`flutter build web --web-renderer <renderer>`
   - Android：`flutter build apk`
   - iOS：`flutter build ios --no-codesign`
8. **后处理** — 将编译产物、资源文件、安装脚本复制到 `bin/` 目录

## 输出目录结构

```
bin/
├── myapp_v2.0.0_windows/
│   ├── myapp.exe                # 可执行文件
│   ├── data/                    # Flutter 数据
│   ├── flutter_exported.dll     # Flutter 引擎
│   ├── README.html              # 转换后的 README
│   ├── LICENSE.txt              # 许可证（UTF-8-BOM + CRLF）
│   ├── install_app.ps1          # Windows 安装脚本
│   └── app_icon.ico             # 应用图标（如果存在）
├── myapp_v2.0.0_linux/
│   ├── myapp                    # 可执行文件
│   ├── data/
│   ├── lib/
│   ├── README.html
│   ├── LICENSE.txt
│   ├── install_app.sh           # Linux 安装脚本
│   └── Icon-192.png             # 应用图标
├── myapp_v2.0.0_macos/
│   ├── myapp.app/               # macOS App Bundle
│   ├── README.html
│   ├── LICENSE.txt
│   └── install_app.sh
├── myapp_v2.0.0_web/
│   ├── index.html               # Web 入口
│   ├── main.dart.js             # 编译后的 JS
│   ├── assets/
│   └── ...
├── myapp_v2.0.0_android/
│   └── app-release.apk
└── ...
```

目录命名规则：

- 有版本号时：`{name}_v{ver}_{platform}`
- 无版本号时：`{name}_{platform}`

## 平台特殊处理

### Linux

- 从模板 `install_app.sh.tmpl` 生成 `install_app.sh`
- 将图标文件复制到输出目录
- `install_app.sh` 支持以下子命令：
  - `install` — 添加到应用菜单和桌面
  - `uninstall` — 从应用菜单和桌面移除
  - `install_menu` / `uninstall_menu` — 仅操作应用菜单
  - `install_desktop` / `uninstall_desktop` — 仅操作桌面快捷方式

### Windows

- 从模板 `install_app.ps1.tmpl` 生成 `install_app.ps1`
- 自动从常见 Flutter 路径检测图标文件
- `install_app.ps1` 支持相同的一组子命令（`install` / `uninstall` / `install_menu` 等）
- 输出文本文件使用 UTF-8-BOM 编码和 CRLF 换行符

### macOS

- Flutter 自动生成 `.app` Bundle
- 生成 `install_app.sh` 用于将应用复制到或从 `/Applications` 移除
- 支持 `install` 和 `uninstall` 子命令

## 模板文件

模板文件必须与 `build_all.py` 放在同一目录，使用 `{{变量名}}` 语法。脚本根据命令行参数自动替换这些占位符。

### `install_app.sh.tmpl` 支持的占位符

| 占位符                 | 来源                       |
| ---------------------- | -------------------------- |
| `{{APP_NAME}}`         | `--name` 或自动获取        |
| `{{APP_EXEC}}`         | `{name}`（Linux 无扩展名） |
| `{{APP_ICON_FILE}}`    | `--appicon` 的文件名       |
| `{{APP_ICON_NAME}}`    | 图标文件名（不含扩展名）   |
| `{{APP_COMMENT}}`      | `--appdesc`                |
| `{{APP_GENERIC_NAME}}` | `--appgeneric`             |
| `{{APP_CATEGORIES}}`   | `--appcategory`            |
| `{{APP_DESKTOP_NAME}}` | `--name` 的值              |

### `install_app.ps1.tmpl` 支持的占位符

| 占位符                 | 来源                          |
| ---------------------- | ----------------------------- |
| `{{APP_NAME}}`         | `--name` 或自动获取           |
| `{{APP_EXEC}}`         | `{name}.exe`                  |
| `{{APP_ICON}}`         | icon.ico 的文件名（若存在）   |
| `{{APP_COMMENT}}`      | `--appdesc`                   |
| `{{APP_DESKTOP_NAME}}` | `--name` 的值                 |

### `Info.plist.tmpl` 支持的占位符

| 占位符                   | 来源                         |
| ------------------------ | ---------------------------- |
| `{{APP_NAME}}`           | `--name`                     |
| `{{APP_DISPLAY_NAME}}`   | `--appgeneric`               |
| `{{APP_EXEC}}`           | 二进制文件名                 |
| `{{APP_ICON_NAME}}`      | 图标文件名（不含扩展名）     |
| `{{APP_IDENTIFIER}}`     | `--appidentifier` 或自动推导 |
| `{{APP_VERSION}}`        | `--appver` 或自动检测        |
| `{{APP_MACOS_CATEGORY}}` | `--appmacoscategory`         |
| `{{APP_COPYRIGHT}}`      | `--appdesc`                  |

## 测试

```bash
# 运行自检：检查环境而不执行实际编译
python build_all.py --test
```

`--test` 会：

1. 显示 Python 版本
2. 检查 Flutter 是否可用
3. 列出当前操作系统可用的平台
4. 检查可选依赖（pyyaml、markdown）

## 注意事项

- **必须在 Flutter 项目根目录下运行** — 脚本需要读取 `pubspec.yaml`。如果使用子模块方式引入，请使用 `--project-dir` 参数
- **Python 版本** — 需要 Python 3.6 及以上
- **平台可用性** — 并非所有平台都能在所有操作系统上编译（例如 iOS 需要 macOS）
- **`pyyaml` 库是可选的** — 未安装时使用正则表达式回退解析 `pubspec.yaml`
- **`markdown` 库是可选的** — 未安装时 README 以纯文本 `.txt` 形式输出
- **输出覆盖** — 每次运行会清空 `bin/` 目录
- **Windows 编码** — Windows 输出的 `.txt` 文件为 UTF-8-BOM + CRLF；其他平台为 UTF-8 + LF
- **`--test` 不执行编译** — 它仅检查环境是否就绪

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
