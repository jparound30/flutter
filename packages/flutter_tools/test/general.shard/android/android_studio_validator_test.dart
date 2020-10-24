// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/android/android_studio_validator.dart';
import 'package:flutter_tools/src/base/config.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/user_messages.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/ios/plist_parser.dart';
import 'package:matcher/matcher.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';

import '../../src/common.dart';
import '../../src/context.dart';

const String home = '/home/me';

final Platform linuxPlatform = FakePlatform(
  operatingSystem: 'linux',
  environment: <String, String>{'HOME': home}
);

void main() {
  FileSystem fileSystem;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
  });

  testWithoutContext('NoAndroidStudioValidator shows Android Studio as "not available" when not available.', () async {
    final Config config = Config.test(
      'test',
      directory: fileSystem.currentDirectory,
      logger: BufferLogger.test(),
    );
    final NoAndroidStudioValidator validator = NoAndroidStudioValidator(
      config: config,
      platform: linuxPlatform,
      userMessages: UserMessages(),
    );

    expect((await validator.validate()).type, equals(ValidationType.notAvailable));
  });

  testWithoutContext('AndroidStudioValidator gives doctor error on java crash', () async {
    final ProcessManager processManager = MockProcessManager();
    when(processManager.canRun(any)).thenReturn(true);
    final ProcessUtils processUtils = MockProcessUtils();
    when(processUtils.runSync(any)).thenThrow(const ProcessException('java', <String>['--version']));

    const String installPath = '/opt/android-studio-with-cheese-4.0';
    const String studioHome = '$home/.AndroidStudio4.0';
    const String homeFile = '$studioHome/system/.home';
    fileSystem.directory(installPath).createSync(recursive: true);
    fileSystem.file(homeFile).createSync(recursive: true);
    fileSystem.file(homeFile).writeAsStringSync(installPath);

    final Config config = Config.test(
      'test',
      directory: fileSystem.currentDirectory,
      logger: BufferLogger.test(),
    );

    // This checks that running the validator doesn't throw an unhandled
    // exception and that the ProcessException makes it into the error
    // message list.
    for (final DoctorValidator validator in AndroidStudioValidator.allValidators(
      config: config,
      fileSystem: fileSystem,
      fileSystemUtils: FileSystemUtils(fileSystem: fileSystem, platform: linuxPlatform),
      platform: linuxPlatform,
      plistParser: MockPlistParser(),
      processManager: processManager,
      processUtils: processUtils,
      userMessages: UserMessages(),
    )) {
      final ValidationResult result = await validator.validate();
      expect(result.messages.where((ValidationMessage message) {
        return message.isError && message.message.contains('ProcessException');
      }).isNotEmpty, true);
    }
  });
}

class MockPlistParser extends Mock implements PlistParser {}
class MockProcessManager extends Mock implements ProcessManager {}
class MockProcessUtils extends Mock implements ProcessUtils {}
