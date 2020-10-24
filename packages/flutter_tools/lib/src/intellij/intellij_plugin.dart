import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:meta/meta.dart';

class _IdeaProduct {
  const _IdeaProduct(this.product, this.vendor, this.title);

  final String product;
  final String vendor;
  final String title;
}

class IntelliJPluginsDir {
  IntelliJPluginsDir(
    this.productId,
    this.version, {
    @required FileSystem fileSystem,
    @required FileSystemUtils fileSystemUtils,
    @required Platform platform,
  })  : _fileSystem = fileSystem,
        _fileSystemUtils = fileSystemUtils,
        _platform = platform {
    final List<String> split = version.split('.');
    if (split.length < 2) {
      _majorVersionNum = null;
      _minorVersionNum = null;
      return;
    }
    _majorVersionNum = int.tryParse(split[0]);
    _minorVersionNum = int.tryParse(split[1]);
  }

  final String productId;
  final String version;
  final FileSystem _fileSystem;
  final FileSystemUtils _fileSystemUtils;
  final Platform _platform;
  int _majorVersionNum;
  int _minorVersionNum;

  static const Map<String, _IdeaProduct> _supportedProduct = <String, _IdeaProduct>{
    'IntelliJIdea': _IdeaProduct('IntelliJIdea', 'JetBrains', 'IntelliJ IDEA Ultimate Edition'),
    'IdeaIC': _IdeaProduct('IdeaIC', 'JetBrains', 'IntelliJ IDEA Community Edition'),
    'AndroidStudio': _IdeaProduct('AndroidStudio', 'Google', 'Android Studio'),
  };

  _IdeaProduct get ideaProduct {
    return _supportedProduct[productId];
  }

  String get defaultSystemDirPath {
    if (_platform.isLinux) {
      if ('IntelliJIdea' == productId || 'IdeaIC' == productId) {
        if (_majorVersionNum <= 2019) {
          return _fileSystem.path.join(_fileSystemUtils.homeDirPath, '.$productId$version', 'system');
        } else {
          return _fileSystem.path.join(_fileSystemUtils.homeDirPath, '.cache', ideaProduct.vendor, '$productId$version');
        }
      } else if ('AndroidStudio' == productId) {
        if (_majorVersionNum <= 3 || (_majorVersionNum == 4 && _minorVersionNum == 0)) {
          return _fileSystem.path.join(_fileSystemUtils.homeDirPath, '.$productId$version', 'system');
        } else {
          return _fileSystem.path.join(_fileSystemUtils.homeDirPath, '.cache', ideaProduct.vendor, '$productId$version');
        }
      } else {
        return null;
      }
    }
    return null;
  }

  String get defaultPluginsDirPath {
    if (_platform.isLinux) {
      if ('IntelliJIdea' == productId || 'IdeaIC' == productId) {
        if (_majorVersionNum <= 2019) {
          return _fileSystem.path.join(_fileSystemUtils.homeDirPath, '.$productId$version', 'config', 'plugins');
        } else {
          return _fileSystem.path.join(_fileSystemUtils.homeDirPath, '.local', 'share', ideaProduct.vendor, '$productId$version');
        }
      } else if ('AndroidStudio' == productId) {
        if (_majorVersionNum <= 3 || (_majorVersionNum == 4 && _minorVersionNum == 0)) {
          return _fileSystem.path.join(_fileSystemUtils.homeDirPath, '.$productId$version', 'config', 'plugins');
        } else {
          return _fileSystem.path.join(_fileSystemUtils.homeDirPath, '.local', 'share', ideaProduct.vendor, '$productId$version');
        }
      } else {
        return null;
      }
    }
    return null;
  }

  /// Read 'idea.plugins.path' property from a vmoptions file.
  ///
  /// vmoptions file has the contents as the following example.
  ///
  /// -Xms128m
  /// -Xmx8000m
  /// -XX:ReservedCodeCacheSize=240m
  /// -XX:+UseConcMarkSweepGC
  /// -XX:SoftRefLRUPolicyMSPerMB=50
  /// -ea
  /// -XX:CICompilerCount=2
  /// -Dsun.io.useCanonPrefixCache=false
  /// -Djdk.http.auth.tunneling.disabledSchemes=""
  /// -XX:+HeapDumpOnOutOfMemoryError
  /// -XX:-OmitStackTraceInFastThrow
  /// -Djdk.attach.allowAttachSelf=true
  /// -Dkotlinx.coroutines.debug=off
  /// -Djdk.module.illegalAccess.silent=true
  /// -Dawt.useSystemAAFontSettings=lcd
  /// -Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine
  /// -Dsun.tools.attach.tmp.only=true
  /// -Dide.no.platform.update=true
  /// -Dsun.io.useCanonCaches=false
  /// -XX:ReservedCodeCacheSize=512m
  /// -Didea.plugins.path=/home/foo/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-0/203.4818.26.plugins
  ///
  String readIdePluginsPath(String vmoptionsPath) {
    String vmoptionsContents;
    try {
      vmoptionsContents = _fileSystem.file(vmoptionsPath).readAsStringSync();
    } on FileSystemException {
      return null;
    }
    final String pluginsPath = vmoptionsContents
        .split('\n')
        .firstWhere(
            (String element) => element.startsWith('-Didea.plugins.path='),
            orElse: () => '')
        .replaceFirst('-Didea.plugins.path=', '');
    return pluginsPath.isNotEmpty ? pluginsPath : null;
  }

  String get pluginsPath {
    final _IdeaProduct product = ideaProduct;
    if (product == null) {
      return null;
    }
    final String ideSystemDirPath = defaultSystemDirPath;
    if (ideSystemDirPath == null) {
      return null;
    }

    String ideHomePath;
    try {
      ideHomePath = _fileSystem.file(_fileSystem.path.join(ideSystemDirPath, '.home')).readAsStringSync();
    } on FileSystemException {
      // ignored
    }

    if (ideHomePath == null || !_fileSystem.isDirectorySync(ideHomePath)) {
      return null;
    }

    final String vmoptionsFilePath = ideHomePath + '.vmoptions';
    if (!_fileSystem.isFileSync(vmoptionsFilePath)) {
      return defaultPluginsDirPath;
    }

    final String ideaPluginsPath = readIdePluginsPath(ideHomePath + '.vmoptions');
    if (ideaPluginsPath == null) {
      return defaultPluginsDirPath;
    }

    return ideaPluginsPath;
  }

}
