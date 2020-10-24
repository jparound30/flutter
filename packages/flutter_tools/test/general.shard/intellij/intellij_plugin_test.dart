// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/intellij/intellij_plugin.dart';

import '../../src/common.dart';

final Platform macPlatform = FakePlatform(
    operatingSystem: 'macos',
    environment: <String, String>{'HOME': '/foo/bar'});

final Platform linuxPlatform = FakePlatform(
    operatingSystem: 'linux',
    environment: <String, String>{'HOME': '/foo/bar'});

final Platform windowsPlatform =
    FakePlatform(operatingSystem: 'windows', environment: <String, String>{
  'USERPROFILE': 'C:\\Users\\foo',
  'APPDATA': 'C:\\Users\\foo\\AppData\\Roaming',
  'LOCALAPPDATA': 'C:\\Users\\foo\\AppData\\Local'
});

void main() {
  void writeFileCreatingDirectories(
      FileSystem fileSystem, String path, List<int> bytes) {
    final File file = fileSystem.file(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }

  group('Parse vmoptions file', () {
    testWithoutContext('can read idea.plugins.path', () async {
      final FileSystem fileSystem = MemoryFileSystem.test(style: FileSystemStyle.posix);
      final Platform platform = linuxPlatform;
      final FileSystemUtils fileSystemUtils =
          FileSystemUtils(fileSystem: fileSystem, platform: platform);

      const vmoptionsContent = '''-Xms128m
-Xmx8000m
-XX:ReservedCodeCacheSize=240m
-XX:+UseConcMarkSweepGC
-XX:SoftRefLRUPolicyMSPerMB=50
-ea
-XX:CICompilerCount=2
-Dsun.io.useCanonPrefixCache=false
-Djdk.http.auth.tunneling.disabledSchemes=""
-XX:+HeapDumpOnOutOfMemoryError
-XX:-OmitStackTraceInFastThrow
-Djdk.attach.allowAttachSelf=true
-Dkotlinx.coroutines.debug=off
-Djdk.module.illegalAccess.silent=true
-Dawt.useSystemAAFontSettings=lcd
-Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine
-Dsun.tools.attach.tmp.only=true
-Dide.no.platform.update=true
-Dsun.io.useCanonCaches=false
-XX:ReservedCodeCacheSize=512m
-Didea.plugins.path=/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-0/203.4818.26.plugins
''';

      writeFileCreatingDirectories(fileSystem, '/foo/bar/vmoptions', utf8.encode(vmoptionsContent));

      final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
          'CLion', '2020.3',
          fileSystem: fileSystem,
          fileSystemUtils: fileSystemUtils,
          platform: platform);
      expect(intelliJPluginsDir.readIdePluginsPath('/foo/bar/vmoptions'), '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-0/203.4818.26.plugins');
    });

    testWithoutContext('idea.plugins.path property not found ', () async {
      final FileSystem fileSystem = MemoryFileSystem.test(style: FileSystemStyle.posix);
      final Platform platform = linuxPlatform;
      final FileSystemUtils fileSystemUtils =
      FileSystemUtils(fileSystem: fileSystem, platform: platform);

      const vmoptionsContent = '''-Xms128m
-Xmx8000m
-XX:ReservedCodeCacheSize=240m
-XX:+UseConcMarkSweepGC
-XX:SoftRefLRUPolicyMSPerMB=50
-ea
-XX:CICompilerCount=2
-Dsun.io.useCanonPrefixCache=false
-Djdk.http.auth.tunneling.disabledSchemes=""
-XX:+HeapDumpOnOutOfMemoryError
-XX:-OmitStackTraceInFastThrow
-Djdk.attach.allowAttachSelf=true
-Dkotlinx.coroutines.debug=off
-Djdk.module.illegalAccess.silent=true
-Dawt.useSystemAAFontSettings=lcd
-Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine
-Dsun.tools.attach.tmp.only=true
-Dide.no.platform.update=true
-Dsun.io.useCanonCaches=false
-XX:ReservedCodeCacheSize=512m
''';

      writeFileCreatingDirectories(fileSystem, '/foo/bar/vmoptions', utf8.encode(vmoptionsContent));

      final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
          'CLion', '2020.3',
          fileSystem: fileSystem,
          fileSystemUtils: fileSystemUtils,
          platform: platform);
      expect(intelliJPluginsDir.readIdePluginsPath('/foo/bar/vmoptions'), null);
    });

    testWithoutContext('vmoptions file is empty', () async {
      final FileSystem fileSystem = MemoryFileSystem.test(style: FileSystemStyle.posix);
      final Platform platform = linuxPlatform;
      final FileSystemUtils fileSystemUtils =
      FileSystemUtils(fileSystem: fileSystem, platform: platform);

      const vmoptionsContent = '';

      writeFileCreatingDirectories(fileSystem, '/foo/bar/vmoptions', utf8.encode(vmoptionsContent));

      final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
          'CLion', '2020.3',
          fileSystem: fileSystem,
          fileSystemUtils: fileSystemUtils,
          platform: platform);
      expect(intelliJPluginsDir.readIdePluginsPath('/foo/bar/vmoptions'), null);
    });

    testWithoutContext('vmoptions file does not exist', () async {
      final FileSystem fileSystem = MemoryFileSystem.test(style: FileSystemStyle.posix);
      final Platform platform = linuxPlatform;
      final FileSystemUtils fileSystemUtils =
      FileSystemUtils(fileSystem: fileSystem, platform: platform);

      final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
          'CLion', '2020.3',
          fileSystem: fileSystem,
          fileSystemUtils: fileSystemUtils,
          platform: platform);
      expect(intelliJPluginsDir.readIdePluginsPath('/foo/bar/vmoptions'), null);
    });

  });
  group('IntelliJPluginsDir on Linux', () {
    final Platform platform = linuxPlatform;
    FileSystem fileSystem;
    FileSystemUtils fileSystemUtils;

    setUp(() {
      fileSystem = MemoryFileSystem.test(style: FileSystemStyle.posix);
      fileSystemUtils =
          FileSystemUtils(fileSystem: fileSystem, platform: platform);
    });

    testWithoutContext('return null for invalid product', () async {
      final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
          'CLion', '2020.3',
          fileSystem: fileSystem,
          fileSystemUtils: fileSystemUtils,
          platform: platform);
      expect(intelliJPluginsDir.pluginsPath, null);
    });

    group('IntelliJ2019 or earlier and idea.plugin.dir properties not specified', () {
      setUp(() {
        fileSystem = MemoryFileSystem.test(style: FileSystemStyle.posix);
        fileSystemUtils =
            FileSystemUtils(fileSystem: fileSystem, platform: platform);
      });

      testWithoutContext('for IntelliJ Ultimate', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-0/193.6821';
        const String systemDir = '/foo/bar/.IntelliJIdea2019.3/system';
        writeFileCreatingDirectories(fileSystem, fileSystem.path.join(systemDir, '.home'), utf8.encode(dotHome));
        const String expectedPluginsPath = '/foo/bar/.IntelliJIdea2019.3/config/plugins';
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'IntelliJIdea', '2019.3',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });

      testWithoutContext('for IntelliJ Community', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-C/ch-0/193.6821';
        const String systemDir = '/foo/bar/.IdeaIC2019.3/system';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String expectedPluginsPath = '/foo/bar/.IdeaIC2019.3/config/plugins';
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'IdeaIC', '2019.3',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });
    });

    group('IntelliJ2019 or earlier and idea.plugin.dir properties specified', () {
      setUp(() {
        fileSystem = MemoryFileSystem.test(style: FileSystemStyle.posix);
        fileSystemUtils =
            FileSystemUtils(fileSystem: fileSystem, platform: platform);
      });

      testWithoutContext('for IntelliJ Ultimate', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-0/193.6821';
        const String systemDir = '/foo/bar/.IntelliJIdea2019.3/system';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String vmoptionsPath = dotHome + '.vmoptions';
        const String expectedPluginsPath = '$dotHome.plugins';
        final List<int> vmoptions = utf8.encode('-Didea.plugins.path=$expectedPluginsPath\n');
        writeFileCreatingDirectories(fileSystem, vmoptionsPath, vmoptions);
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'IntelliJIdea', '2019.3',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });
      testWithoutContext('for IntelliJ Community', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-C/ch-0/193.6821';
        const String systemDir = '/foo/bar/.IdeaIC2019.3/system';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String vmoptionsPath = dotHome + '.vmoptions';
        const String expectedPluginsPath = '$dotHome.plugins';
        final List<int> vmoptions = utf8.encode('-Didea.plugins.path=$expectedPluginsPath\n');
        writeFileCreatingDirectories(fileSystem, vmoptionsPath, vmoptions);
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'IdeaIC', '2019.3',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });
    });

    group('IntelliJ2020 or later and idea.plugin.dir properties not specified', () {
      testWithoutContext('for IntelliJ Ultimate', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-0/203.6821';
        const String systemDir = '/foo/bar/.cache/JetBrains/IntelliJIdea2020.3';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String expectedPluginsPath = '/foo/bar/.local/share/JetBrains/IntelliJIdea2020.3';
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'IntelliJIdea', '2020.3',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });

      testWithoutContext('for IntelliJ Community', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-C/ch-0/203.6821';
        const String systemDir = '/foo/bar/.cache/JetBrains/IdeaIC2020.3';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String expectedPluginsPath = '/foo/bar/.local/share/JetBrains/IdeaIC2020.3';
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'IdeaIC', '2020.3',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });
    });
    group('IntelliJ2020 or later and idea.plugin.dir properties specified', () {
      testWithoutContext('for IntelliJ Ultimate', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-0/203.6821';
        const String systemDir = '/foo/bar/.cache/JetBrains/IntelliJIdea2020.3';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String vmoptionsPath = dotHome + '.vmoptions';
        const String expectedPluginsPath = '$dotHome.plugins';
        final List<int> vmoptions = utf8.encode('-Didea.plugins.path=$expectedPluginsPath\n');
        writeFileCreatingDirectories(fileSystem, vmoptionsPath, vmoptions);
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'IntelliJIdea', '2020.3',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });

      testWithoutContext('for IntelliJ Community', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-C/ch-0/203.6821';
        const String systemDir = '/foo/bar/.cache/JetBrains/IdeaIC2020.3';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String vmoptionsPath = dotHome + '.vmoptions';
        const String expectedPluginsPath = '$dotHome.plugins';
        final List<int> vmoptions = utf8.encode('-Didea.plugins.path=$expectedPluginsPath\n');
        writeFileCreatingDirectories(fileSystem, vmoptionsPath, vmoptions);
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'IdeaIC', '2020.3',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });
    });

    group('AndroidStudio 4.0 or earlier and idea.plugin.dir properties NOT specified', () {
      testWithoutContext('return path for Android Studio 4.0 (based on IDEA 193) or earlier', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/AndroidStudio/ch-0/193.6821';
        const String systemDir = '/foo/bar/.AndroidStudio4.0/system';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String expectedPluginsPath = '/foo/bar/.AndroidStudio4.0/config/plugins';
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'AndroidStudio', '4.0',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });
    });
    group('AndroidStudio 4.0 or earlier and idea.plugin.dir properties specified', () {
      testWithoutContext('return path for Android Studio 4.0 (based on IDEA 193) or earlier', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/AndroidStudio/ch-0/193.6821';
        const String systemDir = '/foo/bar/.AndroidStudio4.0/system';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String vmoptionsPath = dotHome + '.vmoptions';
        const String expectedPluginsPath = '$dotHome.plugins';
        final List<int> vmoptions = utf8.encode('-Didea.plugins.path=$expectedPluginsPath\n');
        writeFileCreatingDirectories(fileSystem, vmoptionsPath, vmoptions);
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'AndroidStudio', '4.0',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });
    });
    group('AndroidStudio 4.1(based on IDEA 202) or later and idea.plugin.dir properties NOT specified', () {
      testWithoutContext('return path for Android Studio 4.1 (based on IDEA 201) or lator', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/AndroidStudio/ch-0/203.6821';
        const String systemDir = '/foo/bar/.cache/Google/AndroidStudio4.1';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String expectedPluginsPath = '/foo/bar/.local/share/Google/AndroidStudio4.1';
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'AndroidStudio', '4.1',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });
    });
    group('AndroidStudio 4.1(based on IDEA 202) or later and idea.plugin.dir properties specified', () {
      testWithoutContext('return path for Android Studio 4.1 (based on IDEA 201) or lator', () async {
        const String dotHome = '/foo/bar/.local/share/JetBrains/Toolbox/apps/AndroidStudio/ch-0/203.6821';
        const String systemDir = '/foo/bar/.cache/Google/AndroidStudio4.1';
        writeFileCreatingDirectories(fileSystem, systemDir + '/.home', utf8.encode(dotHome));
        const String vmoptionsPath = dotHome + '.vmoptions';
        const String expectedPluginsPath = '$dotHome.plugins';
        final List<int> vmoptions = utf8.encode('-Didea.plugins.path=$expectedPluginsPath\n');
        writeFileCreatingDirectories(fileSystem, vmoptionsPath, vmoptions);
        fileSystem.directory(dotHome).createSync(recursive: true);
        fileSystem.directory(systemDir).createSync(recursive: true);
        fileSystem.directory(expectedPluginsPath).createSync(recursive: true);

        final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
            'AndroidStudio', '4.1',
            fileSystem: fileSystem,
            fileSystemUtils: fileSystemUtils,
            platform: platform);
        expect(intelliJPluginsDir.pluginsPath, expectedPluginsPath);
      });
    });


  });

  group('IntelliJPluginsDir on Windows', () {
    final Platform platform = windowsPlatform;
    FileSystem fileSystem;
    FileSystemUtils fileSystemUtils;

    setUp(() {
      fileSystem = MemoryFileSystem.test(style: FileSystemStyle.windows);
      fileSystemUtils =
          FileSystemUtils(fileSystem: fileSystem, platform: platform);
    });

    testWithoutContext('return null for invalid product', () async {
      final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
          'CLion', '2020.3',
          fileSystem: fileSystem,
          fileSystemUtils: fileSystemUtils,
          platform: platform);
      expect(intelliJPluginsDir.pluginsPath, null);
    });
  });

  group('IntelliJPluginsDir on Mac', () {
    final Platform platform = macPlatform;
    FileSystem fileSystem;
    FileSystemUtils fileSystemUtils;

    setUp(() {
      fileSystem = MemoryFileSystem.test(style: FileSystemStyle.posix);
      fileSystemUtils =
          FileSystemUtils(fileSystem: fileSystem, platform: platform);
    });

    testWithoutContext('return null for invalid product', () async {
      final IntelliJPluginsDir intelliJPluginsDir = IntelliJPluginsDir(
          'CLion', '2020.3',
          fileSystem: fileSystem,
          fileSystemUtils: fileSystemUtils,
          platform: platform);
      expect(intelliJPluginsDir.pluginsPath, null);
    });
  });
}
