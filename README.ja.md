# flutter-build-all — Flutter 全プラットフォームビルドスクリプト

[English](README.md) | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md) | **日本語**

Flutter プロジェクトのルートに配置するスタンドアロン Python 3 スクリプト（`build_all.py`）です。実行すると、全サポートプラットフォーム向けにプロジェクトを一括ビルドし、リソースファイルとインストールスクリプトを自動的にバンドルします。

## 目次

- [概要](#概要)
- [サードパーティライブラリ](#サードパーティライブラリ)
- [導入方法](#導入方法)
  - [方法1：ファイルのコピー](#方法1ファイルのコピー)
  - [方法2：Git サブモジュール](#方法2git-サブモジュール)
- [使用方法](#使用方法)
  - [クイックスタート](#クイックスタート)
  - [プラットフォームフィルター](#プラットフォームフィルター)
  - [Web レンダラー](#web-レンダラー)
- [オプション一覧](#オプション一覧)
- [ビルドプロセス](#ビルドプロセス)
- [出力ディレクトリ構造](#出力ディレクトリ構造)
- [注意事項](#注意事項)

## 概要

- `pubspec.yaml` からアプリ名とバージョンを読み取り
- 利用可能な全 Flutter プラットフォームを列挙（`windows`、`linux`、`macos`、`web`、`android`、`ios`）
- `l10n/app_*.arb` ファイルを自動検出し、ビルド前に `flutter gen-l10n` を実行
- ビルド前に `flutter analyze` で静的解析を実行
- README ファイル（Markdown → HTML 変換、オプションのサードパーティライブラリ）と LICENSE を各出力にバンドル
- **Linux**：`install_app.sh` を生成（デスクトップショートカット・`.desktop` メニュー管理）
- **Windows**：`install_app.ps1` を生成（スタートメニュー・デスクトップショートカット管理）
- **macOS**：`install_app.sh` を生成（`.app` を `/Applications` にインストール）
- **並列ビルド**：`--jobs` で複数プラットフォームを同時ビルド

## サードパーティライブラリ

| ライブラリ     | 目的                                                     | インストール方法         | 必須？                                      |
| -------------- | -------------------------------------------------------- | ------------------------ | ------------------------------------------- |
| `pyyaml`       | `pubspec.yaml` の解析                                    | `pip install pyyaml`     | いいえ。正規表現によるフォールバックあり    |
| `markdown`     | README.md を HTML に変換                                 | `pip install markdown`   | いいえ。未インストール時は `.txt` で出力    |

## 導入方法

### 方法1：ファイルのコピー

```
your-project/
├── build_all.py          # メインスクリプト（必須）
├── install_app.sh.tmpl   # Linux インストールスクリプトテンプレート
├── install_app.ps1.tmpl  # Windows インストールスクリプトテンプレート
└── Info.plist.tmpl       # macOS App Bundle テンプレート（予約）
```

### 方法2：Git サブモジュール

```bash
git submodule add git@github.com:kagurazakayashi/flutter-build-all.git tools/build-all
git submodule update --init --recursive
```

## 使用方法

### クイックスタート

```bash
cd /path/to/your-flutter-project
python build_all.py
```

### プラットフォームフィルター

```bash
python build_all.py --target "windows,linux"
python build_all.py --no-web
```

### Web レンダラー

```bash
python build_all.py --target "web" --web-renderer canvaskit
```

### 並列ビルド

```bash
python build_all.py --jobs 0
```

## オプション一覧

### 基本オプション

| オプション       | 型     | デフォルト               | 説明                                   |
| ---------------- | ------ | ------------------------ | -------------------------------------- |
| `--test`         | フラグ | —                        | 環境チェックのみ（ビルドなし）         |
| `--name`         | 文字列 | `pubspec.yaml` から自動  | 出力ディレクトリ名                     |
| `--target`       | 文字列 | —（全プラットフォーム）  | カンマ区切りプラットフォームフィルター |
| `--appver`       | 文字列 | 自動検出                 | アプリバージョン                       |
| `--web-renderer` | 文字列 | `auto`                   | Web レンダラー                         |
| `--no-web`       | フラグ | —                        | Web ビルドをスキップ                   |
| `--skip-analyze` | フラグ | —                        | `flutter analyze` をスキップ           |
| `--jobs`         | 整数   | —（シーケンシャル）      | 並列ビルドジョブ数                     |

## ビルドプロセス

1. プロジェクトチェック（`pubspec.yaml`）
2. ローカライゼーション生成（`flutter gen-l10n`）
3. 静的解析（`flutter analyze`）
4. プロジェクト情報の読み取り
5. 利用可能プラットフォームの列挙
6. リソースファイルの検索
7. プラットフォームごとのビルド
8. 後処理（ビルド成果物・リソース・スクリプトのコピー）

## 出力ディレクトリ構造

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

- Flutter プロジェクトルート（`pubspec.yaml` がある場所）で実行する必要があります
- Python 3.6 以降が必要です
- 全プラットフォームが全 OS でビルドできるわけではありません（例：iOS は macOS が必要）
- `bin/` ディレクトリは毎回クリアされます

## ライセンス

```LICENSE
Copyright (c) 2026 KagurazakaYashi
flutter-build-all is licensed under Mulan PSL v2.
```
