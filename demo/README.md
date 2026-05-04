# flutter-build-all Demo

此目录包含 `flutter-build-all` 库的使用示例。将这些脚本复制到你的 Flutter 项目根目录并修改参数即可使用。

## 脚本列表

| 脚本 | 平台 | 说明 |
|------|------|------|
| `build_all.bat` / `.sh` | Win / Unix | 构建当前 OS 上所有可用平台 |
| `build_desktop.bat` / `.sh` | Win / Unix | 仅构建桌面平台 |
| `build_web.bat` / `.sh` | Win / Unix | 构建 Web（含字体内嵌 + 自定义 base href） |
| `build_android.bat` / `.sh` | Win / Unix | 构建 Android APK |
| `build_assets.bat` / `.sh` | Win / Unix | 仅生成图标和 l10n（不构建平台） |
| `build_parallel.bat` / `.sh` | Win / Unix | 并行构建全部平台 |
| `test_env.bat` / `.sh` | Win / Unix | 测试构建环境 |

## 使用方法

1. 将这些脚本复制到你的 Flutter 项目根目录。
2. 修改脚本中的 `PUSHD` / `cd` 路径，指向 `flutter-build-all` 所在目录（或改为 `--project-dir` 参数）。
3. 修改 `--name`、`--appver`、`--appdesc` 等参数以匹配你的项目。
4. 先运行 `test_env` 验证环境，再执行其他脚本。

> **提示**：脚本中的 `PUSHD "%~dp0.."` 假设脚本位于 `flutter-build-all/demo/` 内。
> 复制到其他位置后需改为对应路径，或使用 `--project-dir` 指定项目根目录。

## 参数摘要

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--target` / `-p` | 目标平台（逗号分隔） | 所有可用平台 |
| `--name` / `-n` | 输出目录名称 | `pubspec.yaml` 中的 name |
| `--appver` / `-v` | 版本号 | `pubspec.yaml` 中的 version |
| `--jobs` / `-j` | 并行任务数（0=CPU 核数） | 串行 |
| `--icon` / `-i` | 生成图标（on/off） | on |
| `--l10n` / `-l` | 生成本地化文件（on/off） | on |
| `--analyze` / `-A` | 构建前分析（on/off） | on |
| `--web-embed-fonts` / `-f` | 内嵌 Web 回退字体（on/off） | off |
| `--web-base-href` / `-b` | Web 构建 base href | `/` |
| `--project-dir` / `-r` | Flutter 项目根目录 | 当前目录 |
| `--test` / `-t` | 仅测试环境，不构建 | — |
