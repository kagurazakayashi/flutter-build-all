"""
Flutter 全平台建置腳本。

從 Flutter 專案根目錄執行此腳本，會自動讀取 pubspec.yaml 取得應用名稱與版本，
並針對所有可用的平台進行建置。
建置完成後會在 bin/ 目錄下產生各平台的輸出資料夾，
內含執行檔、README、LICENSE 以及平台對應的安裝腳本。

使用方法：
    python build_all.py                        # 建置所有可用平台
    python build_all.py --test                 # 自我測試（不建立專案，僅驗證環境）
    python build_all.py --target "windows,linux"   # 只建置指定平台
    python build_all.py --appver 2.0.0         # 設定版本號（會影響輸出資料夾命名）
    python build_all.py --no-web               # 跳過 Web 建置
    python build_all.py --web-renderer canvaskit  # Web 渲染器 (auto|canvaskit|html)
"""

import argparse        # 命令列參數解析
import datetime        # 時間戳記格式
import glob            # 檔案路徑展開
import os              # 檔案系統操作與環境變數
import re              # 正規表示式（解析 pubspec.yaml）
import shutil          # 高階檔案操作（複製、刪除目錄）
import subprocess      # 執行外部命令（flutter build, flutter analyze 等）
import sys             # 系統參數（平台判斷、退出碼）
import tempfile        # 建立暫存目錄
import concurrent.futures  # 平行建置（ThreadPoolExecutor）
import threading       # 執行緒鎖（保護平行建置時的計數器）

try:
    import yaml  # 選用套件：解析 pubspec.yaml（更可靠）
    _HAS_YAML = True
except ImportError:
    _HAS_YAML = False

try:
    import markdown  # 選用套件：將 Markdown 轉換為 HTML
    _HAS_MARKDOWN = True
except ImportError:
    _HAS_MARKDOWN = False

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))  # 此腳本所在的目錄絕對路徑

# 所有 Flutter 支援的平台
ALL_PLATFORMS = [
    "windows",
    "linux",
    "macos",
    "web",
    "android",
    "ios",
]

# 需要桌面安裝腳本的平台
DESKTOP_PLATFORMS = ["windows", "linux", "macos"]

# 各平台的輸出子目錄（相對於 Flutter build 目錄）
PLATFORM_BUILD_DIRS = {
    "windows": "build/windows/runner/Release",
    "linux": "build/linux/x64/release/bundle",
    "macos": "build/macos/Build/Products/Release",
    "web": "build/web",
    "android": "build/app/outputs/flutter-apk",
    "ios": "build/ios/iphoneos",
}

# 各平台的執行檔副檔名
PLATFORM_EXTENSIONS = {
    "windows": ".exe",
    "linux": "",
    "macos": "",
    "web": "",  # Web 沒有單一執行檔
    "android": ".apk",
    "ios": "",  # iOS 輸出為 Runner.app
}


def log(*args, **kwargs):
    """輸出帶有時間戳記與 [BUILD] 標籤的日誌訊息。"""
    prefix = f"[{datetime.datetime.now().strftime('%H:%M:%S')}][BUILD] "
    if args:
        first, *rest = args
        print(f"{prefix}{first}", *rest, **kwargs)
    else:
        print(prefix.strip(), **kwargs)


def get_pubspec_info():
    """從 pubspec.yaml 讀取應用名稱與版本號。回傳 (name, version) 元組。"""
    pubspec_path = "pubspec.yaml"
    if not os.path.isfile(pubspec_path):
        raise RuntimeError("pubspec.yaml not found. This directory is not a Flutter project.")

    if _HAS_YAML:
        with open(pubspec_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        name = data.get("name", "")
        version = data.get("version", "")
        return name, version
    else:
        # 回退方案：使用正規表示式解析
        name = None
        version = None
        with open(pubspec_path, "r", encoding="utf-8") as f:
            content = f.read()
        name_match = re.search(r"^name:\s*(.+)$", content, re.MULTILINE)
        if name_match:
            name = name_match.group(1).strip()
        version_match = re.search(r"^version:\s*(.+)$", content, re.MULTILINE)
        if version_match:
            version = version_match.group(1).strip()
        return name or "", version or ""


def check_platform_available(platform):
    """檢查指定平台是否可在當前環境中建置。"""
    if sys.platform == "win32" and platform not in ("windows", "web", "android"):
        return False
    elif sys.platform == "darwin" and platform not in ("macos", "ios", "web", "android"):
        return False
    elif sys.platform == "linux" and platform not in ("linux", "web", "android"):
        return False
    return True


def get_available_platforms():
    """回傳當前環境可建置的平台清單。"""
    return [p for p in ALL_PLATFORMS if check_platform_available(p)]


def filter_platforms(platforms, target_filter):
    """根據使用者指定的逗號分隔清單篩選要建置的平台。"""
    if not target_filter:
        return platforms
    targets = [t.strip().lower() for t in target_filter.split(",") if t.strip()]
    filtered = [p for p in platforms if p in targets]
    if not filtered:
        log(f"Warning: no platforms matched filter '{target_filter}'")
    return filtered


def run_flutter_clean():
    """清理 Flutter 建置暫存。"""
    log("Running flutter clean ...", end=" ", flush=True)
    result = subprocess.run(
        ["flutter", "clean"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        log("FAILED")
        log(result.stderr.strip())
        raise RuntimeError("flutter clean failed")
    log("OK")
    log()


def run_flutter_analyze():
    """執行 flutter analyze 靜態分析，若發現問題則終止。"""
    log("Running flutter analyze ...", flush=True)
    result = subprocess.run(
        ["flutter", "analyze"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        log("flutter analyze found issues:")
        log(result.stderr.strip() or result.stdout.strip())
        sys.exit(1)
    log("flutter analyze passed.")
    log()


def run_l10n_generate():
    """若專案中含有 l10n/ 目錄且包含 app_*.arb 檔案，則執行 flutter gen-l10n。"""
    if not os.path.isdir("l10n"):
        return
    arb_files = glob.glob(os.path.join("l10n", "app_*.arb"))
    if not arb_files:
        return

    log("Found l10n folder with app_*.arb files, running flutter gen-l10n ...", flush=True)
    result = subprocess.run(
        ["flutter", "gen-l10n"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        log("flutter gen-l10n failed:")
        log(result.stderr.strip() or result.stdout.strip())
        raise RuntimeError("flutter gen-l10n failed")
    log("flutter gen-l10n OK.")
    log()


def find_asset_files():
    """在專案根目錄尋找 LICENSE 與 README*.md 檔案，作為輸出資料夾內的附帶資源。"""
    assets = {}
    for f in os.listdir("."):
        if not os.path.isfile(f):
            continue
        if f == "LICENSE":
            assets["LICENSE.txt"] = f
        elif f.startswith("README") and f.endswith(".md"):
            if _HAS_MARKDOWN:
                assets[f[:-3] + ".html"] = f  # README.md → README.html
            else:
                assets[f[:-3] + ".txt"] = f   # README.md → README.txt（純文字）
    return assets


def convert_md(text):
    """將 Markdown 文字轉換為 HTML（若 markdown 套件可用），否則原樣回傳。"""
    if _HAS_MARKDOWN:
        return markdown.markdown(text, extensions=["extra", "toc"])
    return text


def write_asset_files(out_dir, platform, assets, text_cache):
    """將資源檔案（LICENSE、README）寫入指定的輸出目錄。

    Windows 平台的 .txt 檔案會使用 UTF-8-BOM 編碼與 CRLF 換行。
    """
    for out_name, src_name in assets.items():
        out_path = os.path.join(out_dir, out_name)
        text = text_cache[src_name]
        if out_name.endswith(".html"):
            with open(out_path, "w", encoding="utf-8", newline="") as f:
                f.write(text)
        elif out_name.endswith(".txt"):
            if platform == "windows":
                text = text.replace("\n", "\r\n")
                with open(out_path, "w", encoding="utf-8-sig", newline="") as f:
                    f.write(text)
            else:
                with open(out_path, "w", encoding="utf-8", newline="") as f:
                    f.write(text)


def _handle_linux_desktop(out_dir, name, ext, appicon, appdesc, appgeneric, appcategory):
    """為 Linux 輸出目錄產生 install_app.sh 安裝腳本與 .desktop 桌面捷徑。"""
    icon_file = os.path.basename(appicon)
    icon_name = os.path.splitext(icon_file)[0]

    if os.path.isfile(appicon):
        dst = os.path.join(out_dir, icon_file)
        if not os.path.isfile(dst):
            shutil.copy(appicon, dst)

    tmpl_path = os.path.join(SCRIPT_DIR, "install_app.sh.tmpl")
    if not os.path.isfile(tmpl_path):
        log(f"  Warning: install_app.sh.tmpl not found, skipping install script")
        return

    with open(tmpl_path, "r", encoding="utf-8") as f:
        template = f.read()

    replacements = {
        "{{APP_NAME}}": name,
        "{{APP_EXEC}}": f"{name}{ext}",
        "{{APP_ICON_FILE}}": icon_file,
        "{{APP_ICON_NAME}}": icon_name,
        "{{APP_COMMENT}}": appdesc or name,
        "{{APP_GENERIC_NAME}}": appgeneric or name,
        "{{APP_CATEGORIES}}": appcategory,
        "{{APP_DESKTOP_NAME}}": name,
    }
    script = template
    for key, val in replacements.items():
        script = script.replace(key, val)

    script_path = os.path.join(out_dir, "install_app.sh")
    with open(script_path, "w", encoding="utf-8", newline="") as f:
        f.write(script)
    os.chmod(script_path, 0o755)


def _handle_windows_shortcut(out_dir, name, ext, appdesc, appgeneric):
    """為 Windows 輸出目錄產生 install_app.ps1 安裝腳本並複製圖示。"""
    ico_paths = ["ico/icon.ico", "icon.ico", "windows/runner/resources/app_icon.ico"]
    icon_file = ""
    for p in ico_paths:
        if os.path.isfile(p):
            icon_file = os.path.basename(p)
            dst = os.path.join(out_dir, icon_file)
            if not os.path.isfile(dst):
                shutil.copy(p, dst)
            break

    tmpl_path = os.path.join(SCRIPT_DIR, "install_app.ps1.tmpl")
    if not os.path.isfile(tmpl_path):
        log(f"  Warning: install_app.ps1.tmpl not found, skipping install script")
        return

    with open(tmpl_path, "r", encoding="utf-8") as f:
        template = f.read()

    replacements = {
        "{{APP_NAME}}": name,
        "{{APP_EXEC}}": f"{name}{ext}",
        "{{APP_ICON}}": icon_file,
        "{{APP_COMMENT}}": appdesc or name,
        "{{APP_DESKTOP_NAME}}": name,
    }
    script = template
    for key, val in replacements.items():
        script = script.replace(key, val)

    script_path = os.path.join(out_dir, "install_app.ps1")
    with open(script_path, "w", encoding="utf-8-sig", newline="") as f:
        f.write(script)


def _handle_macos_bundle(out_dir, name, appver, appdesc, appgeneric,
                           appidentifier, appmacoscategory):
    """為 macOS 輸出目錄產生 install_app 腳本（.app 由 Flutter 自動產生）。"""
    # Flutter 已自動產生 .app bundle，此處生成安裝腳本
    tmpl_path = os.path.join(SCRIPT_DIR, "install_app.sh.tmpl")
    if not os.path.isfile(tmpl_path):
        return

    with open(tmpl_path, "r", encoding="utf-8") as f:
        template = f.read()

    icon_file = "AppIcon.icns"
    icon_name = "AppIcon"

    replacements = {
        "{{APP_NAME}}": name,
        "{{APP_EXEC}}": f"{name}.app",
        "{{APP_ICON_FILE}}": icon_file,
        "{{APP_ICON_NAME}}": icon_name,
        "{{APP_COMMENT}}": appdesc or name,
        "{{APP_GENERIC_NAME}}": appgeneric or name,
        "{{APP_CATEGORIES}}": "",
        "{{APP_DESKTOP_NAME}}": name,
    }
    script = template
    for key, val in replacements.items():
        script = script.replace(key, val)

    # macOS 上建立 .app 安裝到此目錄的腳本
    script = script.replace(
        'APP_EXEC="{{APP_EXEC}}"',
        f'APP_EXEC="{name}.app"'
    )
    # 簡化 macOS 安裝腳本，改為複製 .app 到 /Applications
    install_script = f"""#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="{name}"
APP_BUNDLE="$SCRIPT_DIR/${{APP_NAME}}.app"
DEST="/Applications/${{APP_NAME}}.app"

case "${{1:-}}" in
    install)
        echo "[install] Installing ${{APP_NAME}} to /Applications ..."
        if [ -d "${{DEST}}" ]; then
            rm -rf "${{DEST}}"
        fi
        cp -R "${{APP_BUNDLE}}" "${{DEST}}"
        echo "[install] Done. ${{APP_NAME}} installed to /Applications."
        ;;
    uninstall)
        echo "[uninstall] Removing ${{APP_NAME}} ..."
        rm -rf "${{DEST}}"
        echo "[uninstall] Done."
        ;;
    *)
        echo "Usage: $0 {{install|uninstall}}"
        echo "  install   - Copy .app to /Applications"
        echo "  uninstall - Remove from /Applications"
        exit 1
        ;;
esac
"""
    script_path = os.path.join(out_dir, "install_app.sh")
    with open(script_path, "w", encoding="utf-8", newline="") as f:
        f.write(install_script)
    os.chmod(script_path, 0o755)


def _build_one_platform(platform, name, appver, assets, text_cache,
                        appicon, appdesc, appgeneric, appcategory,
                        appidentifier, appmacoscategory, web_renderer):
    """針對單一平台執行 Flutter 建置。

    回傳 (狀態字串, 錯誤訊息) 的元組。
    """
    ext = PLATFORM_EXTENSIONS.get(platform, "")

    if appver:
        out_dir = os.path.join("bin", f"{name}_v{appver}_{platform}")
    else:
        out_dir = os.path.join("bin", f"{name}_{platform}")

    # 建置命令
    if platform == "web":
        cmd = ["flutter", "build", "web", "--web-renderer", web_renderer]
    elif platform == "android":
        cmd = ["flutter", "build", "apk"]
    elif platform == "ios":
        cmd = ["flutter", "build", "ios", "--no-codesign"]
    else:
        cmd = ["flutter", "build", platform]

    log(f"Building {platform} ...", end=" ", flush=True)
    result = subprocess.run(
        cmd,
        capture_output=True, text=True,
    )

    if result.returncode != 0:
        return "FAILED", result.stderr.strip() or result.stdout.strip()

    # 收集建置產物
    os.makedirs(out_dir, exist_ok=True)

    build_src = PLATFORM_BUILD_DIRS.get(platform)
    if build_src and os.path.isdir(build_src):
        # 複製建置產物
        for item in os.listdir(build_src):
            src = os.path.join(build_src, item)
            dst = os.path.join(out_dir, item)
            if os.path.isdir(src):
                if not os.path.exists(dst):
                    shutil.copytree(src, dst)
                else:
                    # 合併目錄
                    for root, dirs, files in os.walk(src):
                        rel = os.path.relpath(root, src)
                        target = os.path.join(dst, rel) if rel != "." else dst
                        os.makedirs(target, exist_ok=True)
                        for f in files:
                            shutil.copy2(os.path.join(root, f), os.path.join(target, f))
            else:
                shutil.copy2(src, dst)

    # 寫入資源檔案
    if assets:
        write_asset_files(out_dir, platform, assets, text_cache)

    # 平台特定後處理
    if platform == "linux":
        _handle_linux_desktop(out_dir, name, ext, appicon, appdesc,
                              appgeneric, appcategory)
    elif platform == "windows":
        _handle_windows_shortcut(out_dir, name, ext, appdesc, appgeneric)
    elif platform == "macos":
        _handle_macos_bundle(out_dir, name, appver, appdesc,
                             appgeneric, appidentifier, appmacoscategory)

    return "OK", ""


def build_all(name_override=None, target_filter=None, appver=None,
              appdesc="", appgeneric="", appcategory="Utility",
              appicon="web/icons/Icon-192.png", appidentifier="",
              appmacoscategory="public.app-category.utilities",
              project_dir=None, jobs=None, web_renderer="auto",
              skip_analyze=False, skip_web=False):
    """主要建置流程入口：檢測專案、執行前置步驟、對所有平台進行序列或平行建置。

    流程依序為：
    1. 驗證 Flutter 專案（pubspec.yaml 存在）
    2. 執行 flutter gen-l10n（若有多語系資源）
    3. 執行 flutter analyze 靜態檢查
    4. 讀取應用名稱與版本
    5. 篩選目標平台
    6. 準備資源檔案（LICENSE、README）
    7. 對每個平台執行 flutter build，支援平行建置（--jobs）
    """
    saved_cwd = None
    if project_dir:
        project_dir = os.path.abspath(project_dir)
        if not os.path.isdir(project_dir):
            raise RuntimeError(f"Project directory not found: {project_dir}")
        saved_cwd = os.getcwd()
        os.chdir(project_dir)
        log(f"Project directory: {project_dir}")
    try:
        # 驗證 Flutter 專案
        name, detected_ver = get_pubspec_info()
        if not name:
            raise RuntimeError(
                "Cannot find 'name' in pubspec.yaml. This directory is not a Flutter project."
            )
        log(f"pubspec.yaml found, this is a Flutter project.")
        log()

        # 版本號：優先使用命令列參數，其次 pubspec.yaml
        if not appver:
            appver = detected_ver
            if appver:
                log(f"Version from pubspec.yaml: {appver}")

        name = name_override or name

        # 多語系生成
        run_l10n_generate()

        # 靜態分析
        if not skip_analyze:
            run_flutter_analyze()

        # 取得可用平台
        platforms = get_available_platforms()
        if skip_web:
            platforms = [p for p in platforms if p != "web"]
        if target_filter:
            platforms = filter_platforms(platforms, target_filter)

        # 檢查是否有可用平台
        unavailable = [p for p in (target_filter.split(",") if target_filter else ALL_PLATFORMS)
                       if p in ALL_PLATFORMS and not check_platform_available(p)]
        for p in unavailable:
            log(f"Note: platform '{p}' cannot be built on this OS ({sys.platform}), skipped.")

        log(f"App: {name}")
        if appver:
            log(f"Version: {appver}")
        log(f"Platforms: {len(platforms)} -> {', '.join(platforms)}")
        log(f"Web renderer: {web_renderer}")
        log()

        # 準備資源檔案
        assets = find_asset_files()
        if not _HAS_MARKDOWN and any(v.endswith(".md") for v in assets.values()):
            log("markdown library not installed.")
            log("  Install it: pip install markdown")
            log("  README files will be copied as plain text (.txt).")
            log()

        text_cache = {}
        for src_name in assets.values():
            with open(src_name, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            if src_name.endswith(".md"):
                text_cache[src_name] = convert_md(content)
            else:
                text_cache[src_name] = content

        if assets:
            log("Asset files to include in each output:")
            for out_name in sorted(assets):
                log(f"  {out_name}")
            log()

        # 清除舊的 bin/ 目錄，確保輸出乾淨
        if os.path.isdir("bin"):
            shutil.rmtree("bin")
            log("Removed old bin directory.")
        os.makedirs("bin")

        if jobs is not None:
            # 平行建置模式
            max_workers = os.cpu_count() if jobs == 0 else jobs
            log(f"Building with {max_workers} parallel workers")
            log()
            lock = threading.Lock()
            counters = {"success": 0, "skipped": 0, "failed": 0}

            def build_and_log(platform):
                if appver:
                    label = f"{name}_v{appver}_{platform}"
                else:
                    label = f"{name}_{platform}"
                status, err = _build_one_platform(
                    platform, name, appver, assets, text_cache,
                    appicon, appdesc, appgeneric, appcategory,
                    appidentifier, appmacoscategory, web_renderer,
                )
                with lock:
                    log(f"Building {label} ... {status}")
                    if err:
                        log(f"  {err[:500]}")
                    if status == "FAILED":
                        counters["failed"] += 1
                    else:
                        counters["success"] += 1

            with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
                futures = [executor.submit(build_and_log, p) for p in platforms]
                concurrent.futures.wait(futures)

            success = counters["success"]
            failed = counters["failed"]
            skipped = 0
        else:
            # 序列建置模式
            success = 0
            failed = 0
            skipped = 0

            for platform in platforms:
                if appver:
                    label = f"{name}_v{appver}_{platform}"
                else:
                    label = f"{name}_{platform}"
                log(f"Building {label} ...", end=" ", flush=True)
                status, err = _build_one_platform(
                    platform, name, appver, assets, text_cache,
                    appicon, appdesc, appgeneric, appcategory,
                    appidentifier, appmacoscategory, web_renderer,
                )
                print(status)
                if err:
                    log(f"  {err[:500]}")
                if status == "FAILED":
                    failed += 1
                else:
                    success += 1

        log()
        log(f"Done. Success: {success}, Failed: {failed}")

    finally:
        if saved_cwd is not None:
            os.chdir(saved_cwd)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Flutter 全平台建置腳本")
    parser.add_argument("--test", action="store_true",
                        help="Test the script environment (no actual build)")
    parser.add_argument("--name",
                        help="Custom name for output folders (default: from pubspec.yaml)")
    parser.add_argument("--target",
                        help="Comma-separated platforms to build, e.g. \"windows,linux,web\"")
    parser.add_argument("--project-dir",
                        help="Flutter project root directory (default: current directory)")
    parser.add_argument("--appver",
                        help="Application version for output folder naming "
                             "(auto-detected from pubspec.yaml if not specified)")
    parser.add_argument("--appdesc",
                        help="Application description for desktop entries")
    parser.add_argument("--appgeneric",
                        help="Generic name for desktop entries")
    parser.add_argument("--appcategory",
                        help="Desktop entry categories (default: Utility)",
                        default="Utility")
    parser.add_argument("--appicon",
                        help="Path to app icon file within the project "
                             "(default: web/icons/Icon-192.png)",
                        default="web/icons/Icon-192.png")
    parser.add_argument("--appidentifier",
                        help="Bundle identifier for macOS "
                             "(auto-derived from pubspec name if not specified)")
    parser.add_argument("--appmacoscategory",
                        help="macOS app category for Info.plist "
                             "(default: public.app-category.utilities)",
                        default="public.app-category.utilities")
    parser.add_argument("--jobs", type=int,
                        help="Number of parallel build jobs (0=CPU cores, default: sequential)")
    parser.add_argument("--web-renderer",
                        help="Web renderer: auto, canvaskit, or html (default: auto)",
                        default="auto",
                        choices=["auto", "canvaskit", "html"])
    parser.add_argument("--skip-analyze", action="store_true",
                        help="Skip flutter analyze step")
    parser.add_argument("--no-web", action="store_true",
                        help="Skip web platform build")
    args = parser.parse_args()

    if args.test:
        # 自我測試模式：驗證環境
        log("=== Test Mode ===")
        log("Checking environment ...")
        log()

        # 檢查 Python 版本
        log(f"Python: {sys.version}")

        # 檢查 Flutter 是否可用
        try:
            result = subprocess.run(
                ["flutter", "--version"],
                capture_output=True, text=True,
            )
            if result.returncode == 0:
                log("Flutter: available")
                log("  " + result.stdout.strip().split("\n")[0])
            else:
                log("Flutter: NOT available")
                sys.exit(1)
        except FileNotFoundError:
            log("Flutter: NOT found in PATH")
            sys.exit(1)

        # 列出可用平台
        log()
        log("Available platforms on this OS:")
        for p in ALL_PLATFORMS:
            ok = check_platform_available(p)
            mark = "OK" if ok else "SKIP (not supported on this OS)"
            log(f"  {p}: {mark}")

        # 檢查可選依賴
        log()
        if _HAS_YAML:
            log("yaml library: available")
        else:
            log("yaml library: NOT installed (pip install pyyaml) - will use regex fallback")
        if _HAS_MARKDOWN:
            log("markdown library: available")
        else:
            log("markdown library: NOT installed (pip install markdown) - README will be plain text")

        log()
        log("=== Test completed ===")
    else:
        # 一般建置模式
        build_all(name_override=args.name, target_filter=args.target,
                  appver=args.appver,
                  appdesc=args.appdesc or "", appgeneric=args.appgeneric or "",
                  appcategory=args.appcategory, appicon=args.appicon,
                  appidentifier=args.appidentifier or "",
                  appmacoscategory=args.appmacoscategory,
                  project_dir=args.project_dir,
                  jobs=args.jobs, web_renderer=args.web_renderer,
                  skip_analyze=args.skip_analyze, skip_web=args.no_web)
