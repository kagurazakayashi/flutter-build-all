/// build_all.dart — flutter_build_all 套件的公開 API 匯出
library;

export 'src/assets.dart' show getPubspecInfo;
export 'src/build_runner.dart' show buildAll;
export 'src/constants.dart'
    show
        allPlatforms,
        desktopPlatforms,
        platformBuildDirs,
        platformExtensions,
        isPlatformAvailable;
