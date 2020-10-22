// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/android/android_studio.dart';
import 'package:flutter_tools/src/base/config.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/version.dart';
import 'package:flutter_tools/src/ios/plist_parser.dart';
import 'package:mockito/mockito.dart';

import '../../src/common.dart';
import '../../src/context.dart';

const String homeLinux = '/home/me';
const String homeMac = '/Users/me';

const Map<String, dynamic> macStudioInfoPlist = <String, dynamic>{
  'CFBundleGetInfoString': 'Android Studio 3.3, build AI-182.5107.16.33.5199772. Copyright JetBrains s.r.o., (c) 2000-2018',
  'CFBundleShortVersionString': '3.3',
  'CFBundleVersion': 'AI-182.5107.16.33.5199772',
  'JVMOptions': <String, dynamic>{
    'Properties': <String, dynamic>{
      'idea.paths.selector': 'AndroidStudio3.3',
      'idea.platform.prefix': 'AndroidStudio',
    },
  },
};

final Platform linuxPlatform = FakePlatform(
  operatingSystem: 'linux',
  environment: <String, String>{'HOME': homeLinux},
);

final Platform windowsPlatform = FakePlatform(
  operatingSystem: 'windows',
  environment: <String, String>{
    'LOCALAPPDATA': 'C:\\Users\\Dash\\AppData\\Local',
  }
);

class MockPlistUtils extends Mock implements PlistParser {}

Platform macPlatform() {
  return FakePlatform(
    operatingSystem: 'macos',
    environment: <String, String>{'HOME': homeMac},
  );
}

void main() {
  FileSystem fileSystem;
  FileSystemUtils fileSystemUtils;
  final ProcessManager processManager = FakeProcessManager.any();
  final ProcessUtils processUtils = MockProcessUtils();

  setUp(() {
    fileSystem = MemoryFileSystem.test();
  });

  testWithoutContext('pluginsPath on Linux extracts custom paths from home dir', () {
    const String installPath = '/opt/android-studio-with-cheese-5.0';
    const String studioHome = '$homeLinux/.AndroidStudioWithCheese5.0';
    const String homeFile = '$studioHome/system/.home';
    fileSystem.directory(installPath).createSync(recursive: true);
    fileSystem.file(homeFile).createSync(recursive: true);
    fileSystem.file(homeFile).writeAsStringSync(installPath);
    fileSystemUtils = FileSystemUtils(fileSystem: fileSystem, platform: linuxPlatform);

    final AndroidStudio studio = AndroidStudio.fromHomeDot(
        fileSystem.directory(studioHome),
        fileSystem: fileSystem,
        fileSystemUtils: fileSystemUtils,
        platform: linuxPlatform,
        processManager: processManager,
        processUtils: processUtils);
    expect(studio, isNotNull);
    expect(studio.pluginsPath,
        equals('/home/me/.AndroidStudioWithCheese5.0/config/plugins'));
  });

  group('pluginsPath on Mac', () {
    FileSystemUtils fsUtils;
    Platform platform;
    MockPlistUtils plistUtils;

    setUp(() {
      plistUtils = MockPlistUtils();
      platform = macPlatform();
      fsUtils = FileSystemUtils(
        fileSystem: fileSystem,
        platform: platform,
      );
    });

    testWithoutContext('extracts custom paths for directly downloaded Android Studio on Mac', () {
      final String studioInApplicationPlistFolder = fileSystem.path.join(
        '/',
        'Application',
        'Android Studio.app',
        'Contents',
      );
      fileSystem.directory(studioInApplicationPlistFolder).createSync(recursive: true);

      final String plistFilePath = fileSystem.path.join(studioInApplicationPlistFolder, 'Info.plist');
      when(plistUtils.parseFile(plistFilePath)).thenReturn(macStudioInfoPlist);
      final AndroidStudio studio = AndroidStudio.fromMacOSBundle(
        fileSystem.directory(studioInApplicationPlistFolder)?.parent?.path,
        fileSystem: fileSystem,
        fileSystemUtils: fsUtils,
        platform: macPlatform(),
        plistParser: plistUtils,
        processManager: processManager,
        processUtils: processUtils,
      );
      expect(studio, isNotNull);
      expect(studio.pluginsPath, equals(fileSystem.path.join(
        homeMac,
        'Library',
        'Application Support',
        'AndroidStudio3.3',
      )));
    });

    testWithoutContext('extracts custom paths for Android Studio downloaded by JetBrainsToolbox on Mac', () {
      final String jetbrainsStudioInApplicationPlistFolder = fileSystem.path.join(
        homeMac,
        'Application',
        'JetBrains Toolbox',
        'Android Studio.app',
        'Contents',
      );
      fileSystem.directory(jetbrainsStudioInApplicationPlistFolder).createSync(recursive: true);
      const Map<String, dynamic> jetbrainsInfoPlist = <String, dynamic>{
        'CFBundleLongVersionString': '3.3',
        'CFBundleShortVersionString': '3.3',
        'CFBundleVersion': '3.3',
        'JetBrainsToolboxApp': '$homeMac/Library/Application Support/JetBrains/Toolbox/apps/AndroidStudio/ch-0/183.5256920/Android Studio 3.3.app',
      };
      final String jetbrainsPlistFilePath = fileSystem.path.join(
        jetbrainsStudioInApplicationPlistFolder,
        'Info.plist',
      );
      when(plistUtils.parseFile(jetbrainsPlistFilePath)).thenReturn(jetbrainsInfoPlist);

      final String studioInApplicationPlistFolder = fileSystem.path.join(
        fileSystem.path.join(homeMac,'Library','Application Support'),
        'JetBrains',
        'Toolbox',
        'apps',
        'AndroidStudio',
        'ch-0',
        '183.5256920',
        fileSystem.path.join('Android Studio 3.3.app', 'Contents'),
      );
      fileSystem.directory(studioInApplicationPlistFolder).createSync(recursive: true);
      final String studioPlistFilePath = fileSystem.path.join(
        studioInApplicationPlistFolder,
        'Info.plist',
      );
      when(plistUtils.parseFile(studioPlistFilePath)).thenReturn(macStudioInfoPlist);

      final AndroidStudio studio = AndroidStudio.fromMacOSBundle(
        fileSystem.directory(jetbrainsStudioInApplicationPlistFolder)?.parent?.path,
        fileSystem: fileSystem,
        fileSystemUtils: fsUtils,
        platform: macPlatform(),
        plistParser: plistUtils,
        processManager: processManager,
        processUtils: processUtils,
      );
      expect(studio, isNotNull);
      expect(studio.pluginsPath, equals(fileSystem.path.join(
        homeMac,
        'Library',
        'Application Support',
        'AndroidStudio3.3',
      )));
    });
  });

  FileSystem windowsFileSystem;

  setUp(() {
    windowsFileSystem = MemoryFileSystem.test(style: FileSystemStyle.windows);
    fileSystemUtils = FileSystemUtils(fileSystem: windowsFileSystem, platform: windowsPlatform);
  });

  testWithoutContext('Can discover Android Studio 4.1 location on Windows', () {
    final MockPlistUtils plistUtils = MockPlistUtils();

    windowsFileSystem.file('C:\\Users\\Dash\\AppData\\Local\\Google\\AndroidStudio4.1\\.home')
      ..createSync(recursive: true)
      ..writeAsStringSync('C:\\Program Files\\AndroidStudio');
    windowsFileSystem
      .directory('C:\\Program Files\\AndroidStudio')
      .createSync(recursive: true);

    final MockConfig config = MockConfig();
    when<String>(config.getValue('android-studio-dir') as String).thenReturn('C:\\Program Files\\AndroidStudio');
    final AndroidStudio studio = AndroidStudio.allInstalled(
      config: config,
      fileSystem: windowsFileSystem,
      fileSystemUtils: fileSystemUtils,
      platform: windowsPlatform,
      plistParser: plistUtils,
      processManager: processManager,
      processUtils: processUtils,
    ).single;

    expect(studio.version, Version(4, 1, 0));
    expect(studio.studioAppName, 'Android Studio 4.1');
  });
}

class MockConfig extends Mock implements Config {}
class MockProcessUtils extends Mock implements ProcessUtils {}
