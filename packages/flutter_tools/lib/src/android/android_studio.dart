// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/config.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/intellij/intellij_plugin.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import '../base/context.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/process.dart';
import '../base/utils.dart';
import '../base/version.dart';
import '../globals.dart' as globals show printTrace;
import '../ios/plist_parser.dart';

AndroidStudio get androidStudio => context.get<AndroidStudio>();

// Android Studio layout:

// Linux/Windows:
// $HOME/.AndroidStudioX.Y/system/.home

// macOS:
// /Applications/Android Studio.app/Contents/
// $HOME/Applications/Android Studio.app/Contents/

final RegExp _dotHomeStudioVersionMatcher =
    RegExp(r'^\.(AndroidStudio[^\d]*)([\d.]+)');

String get javaPath => androidStudio?.javaPath;

class AndroidStudio implements Comparable<AndroidStudio> {
  AndroidStudio(this.directory,
      {Version version,
      this.configured,
      this.studioAppName = 'AndroidStudio',
      this.presetPluginsPath,
      @required FileSystem fileSystem,
      @required FileSystemUtils fileSystemUtils,
      @required Platform platform,
      @required ProcessManager processManager,
      @required ProcessUtils processUtils})
      : version = version ?? Version.unknown,
        _fileSystem = fileSystem,
        _fileSystemUtils = fileSystemUtils,
        _platform = platform,
        _processManager = processManager,
        _processUtils = processUtils {
    _init();
  }

  final FileSystem _fileSystem;
  final FileSystemUtils _fileSystemUtils;
  final Platform _platform;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;

  factory AndroidStudio.fromMacOSBundle(
    String bundlePath, {
    @required FileSystem fileSystem,
    @required FileSystemUtils fileSystemUtils,
    @required Platform platform,
    @required PlistParser plistParser,
    @required ProcessManager processManager,
    @required ProcessUtils processUtils,
  }) {
    String studioPath = fileSystem.path.join(bundlePath, 'Contents');
    String plistFile = fileSystem.path.join(studioPath, 'Info.plist');
    Map<String, dynamic> plistValues = plistParser.parseFile(plistFile);
    // As AndroidStudio managed by JetBrainsToolbox could have a wrapper pointing to the real Android Studio.
    // Check if we've found a JetBrainsToolbox wrapper and deal with it properly.
    final String jetBrainsToolboxAppBundlePath = plistValues['JetBrainsToolboxApp'] as String;
    if (jetBrainsToolboxAppBundlePath != null) {
      studioPath = fileSystem.path.join(jetBrainsToolboxAppBundlePath, 'Contents');
      plistFile = fileSystem.path.join(studioPath, 'Info.plist');
      plistValues = plistParser.parseFile(plistFile);
    }

    final String versionString = plistValues[PlistParser.kCFBundleShortVersionStringKey] as String;

    Version version;
    if (versionString != null) {
      version = Version.parse(versionString);
    }

    String pathsSelectorValue;
    final Map<String, dynamic> jvmOptions = castStringKeyedMap(plistValues['JVMOptions']);
    if (jvmOptions != null) {
      final Map<String, dynamic> jvmProperties = castStringKeyedMap(jvmOptions['Properties']);
      if (jvmProperties != null) {
        pathsSelectorValue = jvmProperties['idea.paths.selector'] as String;
      }
    }
    final String presetPluginsPath = pathsSelectorValue == null
      ? null
      : fileSystem.path.join(
        fileSystemUtils.homeDirPath,
        'Library',
        'Application Support',
        pathsSelectorValue,
      );
    return AndroidStudio(
      studioPath,
      version: version,
      presetPluginsPath: presetPluginsPath,
      fileSystem: fileSystem,
      fileSystemUtils: fileSystemUtils,
      platform: platform,
      processManager: processManager,
      processUtils: processUtils,
    );
  }

  factory AndroidStudio.fromHomeDot(
    Directory homeDotDir, {
    @required FileSystem fileSystem,
    @required FileSystemUtils fileSystemUtils,
    @required Platform platform,
    @required ProcessManager processManager,
    @required ProcessUtils processUtils,
  }) {
    final Match versionMatch =
        _dotHomeStudioVersionMatcher.firstMatch(homeDotDir.basename);
    if (versionMatch?.groupCount != 2) {
      return null;
    }
    final Version version = Version.parse(versionMatch[2]);
    final String studioAppName = versionMatch[1];
    if (studioAppName == null || version == null) {
      return null;
    }
    String installPath;
    try {
      installPath = fileSystem
          .file(fileSystem.path.join(homeDotDir.path, 'system', '.home'))
          .readAsStringSync();
    } on Exception {
      // ignored, installPath will be null, which is handled below
    }
    if (installPath != null && fileSystem.isDirectorySync(installPath)) {
      return AndroidStudio(
        installPath,
        version: version,
        studioAppName: studioAppName,
        fileSystem: fileSystem,
        fileSystemUtils: fileSystemUtils,
        platform: platform,
        processManager: processManager,
        processUtils: processUtils,
      );
    }
    return null;
  }

  final String directory;
  final String studioAppName;
  final Version version;
  final String configured;
  final String presetPluginsPath;

  String _javaPath;
  bool _isValid = false;
  final List<String> _validationMessages = <String>[];

  String get javaPath => _javaPath;

  bool get isValid => _isValid;

  String get pluginsPath {
    final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
        'AndroidStudio',
        version.toString(),
        fileSystem: _fileSystem,
        fileSystemUtils: _fileSystemUtils,
        platform: _platform);
    if (presetPluginsPath != null) {
      return presetPluginsPath;
    }
    final int major = version?.major;
    final int minor = version?.minor;
    if (_platform.isMacOS) {
      return _fileSystem.path.join(
        _fileSystemUtils.homeDirPath,
        'Library',
        'Application Support',
        'AndroidStudio$major.$minor',
      );
    } else if (_platform.isWindows){
      return _fileSystem.path.join(
        _fileSystemUtils.homeDirPath,
        '.$studioAppName$major.$minor',
        'config',
        'plugins',
      );
    } else {
      return intelliJPluginsDir.pluginsPath;
    }
  }

  List<String> get validationMessages => _validationMessages;

  @override
  int compareTo(AndroidStudio other) {
    final int result = version.compareTo(other.version);
    if (result == 0) {
      return directory.compareTo(other.directory);
    }
    return result;
  }

  /// Locates the newest, valid version of Android Studio.
  static AndroidStudio latestValid({
    @required Config config,
    @required FileSystem fileSystem,
    @required FileSystemUtils fileSystemUtils,
    @required Platform platform,
    @required PlistParser plistParser,
    @required ProcessManager processManager,
    @required ProcessUtils processUtils,
  }) {
    final String configuredStudio = config.getValue('android-studio-dir') as String;
    if (configuredStudio != null) {
      String configuredStudioPath = configuredStudio;
      if (platform.isMacOS && !configuredStudioPath.endsWith('Contents')) {
        configuredStudioPath = fileSystem.path.join(configuredStudioPath, 'Contents');
      }
      return AndroidStudio(configuredStudioPath,
          configured: configuredStudio,
          fileSystem: fileSystem,
          fileSystemUtils: fileSystemUtils,
          platform: platform,
          processManager: processManager,
          processUtils: processUtils);
    }

    // Find all available Studio installations.
    final List<AndroidStudio> studios = allInstalled(
        config: config,
        fileSystem: fileSystem,
        fileSystemUtils: fileSystemUtils,
        platform: platform,
        plistParser: plistParser,
        processManager: processManager,
        processUtils: processUtils,
    );
    if (studios.isEmpty) {
      return null;
    }
    studios.sort();
    return studios.lastWhere((AndroidStudio s) => s.isValid,
        orElse: () => null);
  }

  static List<AndroidStudio> allInstalled({
    @required Config config,
    @required FileSystem fileSystem,
    @required FileSystemUtils fileSystemUtils,
    @required Platform platform,
    @required PlistParser plistParser,
    @required ProcessManager processManager,
    @required ProcessUtils processUtils,
  }) =>
      platform.isMacOS
          ? _allMacOS(
              config: config,
              fileSystem: fileSystem,
              fileSystemUtils: fileSystemUtils,
              platform: platform,
              plistParser: plistParser,
              processManager: processManager,
              processUtils: processUtils,
            )
          : _allLinuxOrWindows(
              config: config,
              fileSystem: fileSystem,
              fileSystemUtils: fileSystemUtils,
              platform: platform,
              processManager: processManager,
              processUtils: processUtils,
            );

  static List<AndroidStudio> _allMacOS({
    @required Config config,
    @required FileSystem fileSystem,
    @required FileSystemUtils fileSystemUtils,
    @required Platform platform,
    @required PlistParser plistParser,
    @required ProcessManager processManager,
    @required ProcessUtils processUtils,
  }) {
    final List<FileSystemEntity> candidatePaths = <FileSystemEntity>[];

    void _checkForStudio(String path) {
      if (!fileSystem.isDirectorySync(path)) {
        return;
      }
      try {
        final Iterable<Directory> directories = fileSystem
            .directory(path)
            .listSync(followLinks: false)
            .whereType<Directory>();
        for (final Directory directory in directories) {
          final String name = directory.basename;
          // An exact match, or something like 'Android Studio 3.0 Preview.app'.
          if (name.startsWith('Android Studio') && name.endsWith('.app')) {
            candidatePaths.add(directory);
          } else if (!directory.path.endsWith('.app')) {
            _checkForStudio(directory.path);
          }
        }
      } on Exception catch (e) {
        globals.printTrace('Exception while looking for Android Studio: $e');
      }
    }

    _checkForStudio('/Applications');
    _checkForStudio(fileSystem.path.join(
      fileSystemUtils.homeDirPath,
      'Applications',
    ));

    final String configuredStudioDir = config.getValue('android-studio-dir') as String;
    if (configuredStudioDir != null) {
      FileSystemEntity configuredStudio = fileSystem.file(configuredStudioDir);
      if (configuredStudio.basename == 'Contents') {
        configuredStudio = configuredStudio.parent;
      }
      if (!candidatePaths
          .any((FileSystemEntity e) => e.path == configuredStudio.path)) {
        candidatePaths.add(configuredStudio);
      }
    }

    return candidatePaths
        .map<AndroidStudio>(
            (FileSystemEntity e) => AndroidStudio.fromMacOSBundle(
                  e.path,
                  fileSystem: fileSystem,
                  fileSystemUtils: fileSystemUtils,
                  platform: platform,
                  plistParser: plistParser,
                  processManager: processManager,
                  processUtils: processUtils,
                ))
        .where((AndroidStudio s) => s != null)
        .toList();
  }

  static List<AndroidStudio> _allLinuxOrWindows({
    @required Config config,
    @required FileSystem fileSystem,
    @required FileSystemUtils fileSystemUtils,
    @required Platform platform,
    @required ProcessManager processManager,
    @required ProcessUtils processUtils,
  }) {
    final List<AndroidStudio> studios = <AndroidStudio>[];

    bool _hasStudioAt(String path, { Version newerThan }) {
      return studios.any((AndroidStudio studio) {
        if (studio.directory != path) {
          return false;
        }
        if (newerThan != null) {
          return studio.version.compareTo(newerThan) >= 0;
        }
        return true;
      });
    }

    // Read all $HOME/.AndroidStudio*/system/.home files. There may be several
    // pointing to the same installation, so we grab only the latest one.
    if (fileSystemUtils.homeDirPath != null &&
        fileSystem.directory(fileSystemUtils.homeDirPath).existsSync()) {
      final Directory homeDir = fileSystem.directory(fileSystemUtils.homeDirPath);
      for (final Directory entity in homeDir.listSync(followLinks: false).whereType<Directory>()) {
        if (!entity.basename.startsWith('.AndroidStudio')) {
          continue;
        }
        final AndroidStudio studio = AndroidStudio.fromHomeDot(
          entity,
          fileSystem: fileSystem,
          fileSystemUtils: fileSystemUtils,
          platform: platform,
          processManager: processManager,
          processUtils: processUtils,
        );
        if (studio != null && !_hasStudioAt(studio.directory, newerThan: studio.version)) {
          studios.removeWhere((AndroidStudio other) => other.directory == studio.directory);
          studios.add(studio);
        }
      }
    }
    // 4.1 has a different location for AndroidStudio installs on Windows.
    if (platform.isWindows) {
      final File homeDot = fileSystem.file(fileSystem.path.join(
        platform.environment['LOCALAPPDATA'],
        'Google',
        'AndroidStudio4.1',
        '.home',
      ));
      if (homeDot.existsSync()) {
        final String installPath = homeDot.readAsStringSync();
        if (fileSystem.isDirectorySync(installPath)) {
          final AndroidStudio studio = AndroidStudio(
            installPath,
            version: Version(4, 1, null),
            studioAppName: 'Android Studio 4.1',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform,
            processManager: processManager,
            processUtils: processUtils,
          );
          if (studio != null && !_hasStudioAt(studio.directory, newerThan: studio.version)) {
            studios.removeWhere((AndroidStudio other) => other.directory == studio.directory);
            studios.add(studio);
          }
        }
      }
    } else if (platform.isLinux) {
      // TODO(jparound30): idea 201以降ベースのASではここがデフォルトと思われるので4.1以上を対応する形に変更必要
      final File homeDot = fileSystem.file(fileSystem.path.join(
        fileSystemUtils.homeDirPath,
        '.cache',
        'Google',
        'AndroidStudio4.1',
        '.home',
      ));
      if (homeDot.existsSync()) {
        final String installPath = homeDot.readAsStringSync();
        if (fileSystem.isDirectorySync(installPath)) {
          final AndroidStudio studio = AndroidStudio(
            installPath,
            version: Version(4, 1, null),
            studioAppName: 'Android Studio 4.1',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform,
            processManager: processManager,
            processUtils: processUtils,
          );
          if (studio != null && !_hasStudioAt(studio.directory, newerThan: studio.version)) {
            studios.removeWhere((AndroidStudio other) => other.directory == studio.directory);
            studios.add(studio);
          }
        }
      }
    }

    final String configuredStudioDir = config.getValue('android-studio-dir') as String;
    if (configuredStudioDir != null && !_hasStudioAt(configuredStudioDir)) {
      studios.add(AndroidStudio(configuredStudioDir,
          configured: configuredStudioDir,
          fileSystem: fileSystem,
          fileSystemUtils: fileSystemUtils,
          platform: platform,
          processManager: processManager,
          processUtils: processUtils));
    }

    if (platform.isLinux) {
      void _checkWellKnownPath(String path) {
        if (fileSystem.isDirectorySync(path) && !_hasStudioAt(path)) {
          studios.add(AndroidStudio(path,
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform,
            processManager: processManager,
            processUtils: processUtils,
          ));
        }
      }

      // Add /opt/android-studio and $HOME/android-studio, if they exist.
      _checkWellKnownPath('/opt/android-studio');
      _checkWellKnownPath('${fileSystemUtils.homeDirPath}/android-studio');
    }
    return studios;
  }

  static String extractStudioPlistValueWithMatcher(String plistValue, RegExp keyMatcher) {
    if (plistValue == null || keyMatcher == null) {
      return null;
    }
    return keyMatcher?.stringMatch(plistValue)?.split('=')?.last?.trim()?.replaceAll('"', '');
  }

  void _init() {
    _isValid = false;
    _validationMessages.clear();

    if (configured != null) {
      _validationMessages.add('android-studio-dir = $configured');
    }

    if (!_fileSystem.isDirectorySync(directory)) {
      _validationMessages.add('Android Studio not found at $directory');
      return;
    }

    final String javaPath = _platform.isMacOS ?
        _fileSystem.path.join(directory, 'jre', 'jdk', 'Contents', 'Home') :
        _fileSystem.path.join(directory, 'jre');
    final String javaExecutable = _fileSystem.path.join(javaPath, 'bin', 'java');
    if (!_processManager.canRun(javaExecutable)) {
      _validationMessages.add('Unable to find bundled Java version.');
    } else {
      RunResult result;
      try {
        result = _processUtils.runSync(<String>[javaExecutable, '-version']);
      } on ProcessException catch (e) {
        _validationMessages.add('Failed to run Java: $e');
      }
      if (result != null && result.exitCode == 0) {
        final List<String> versionLines = result.stderr.split('\n');
        final String javaVersion = versionLines.length >= 2 ? versionLines[1] : versionLines[0];
        _validationMessages.add('Java version $javaVersion');
        _javaPath = javaPath;
        _isValid = true;
      } else {
        _validationMessages.add('Unable to determine bundled Java version.');
      }
    }
  }

  @override
  String toString() => 'Android Studio ($version)';
}
