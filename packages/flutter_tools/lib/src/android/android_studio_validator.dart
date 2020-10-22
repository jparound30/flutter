// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/ios/plist_parser.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import '../base/config.dart';
import '../base/file_system.dart';
import '../base/platform.dart';
import '../base/user_messages.dart' hide userMessages;
import '../base/version.dart';
import '../doctor.dart';
import '../intellij/intellij.dart';
import 'android_studio.dart';

class AndroidStudioValidator extends DoctorValidator {
  AndroidStudioValidator(this._studio,
      {@required FileSystem fileSystem, @required UserMessages userMessages})
      : _fileSystem = fileSystem,
        _userMessages = userMessages,
        super('Android Studio');

  final AndroidStudio _studio;
  final FileSystem _fileSystem;
  final UserMessages _userMessages;

  static List<DoctorValidator> allValidators({
    @required Config config,
    @required FileSystem fileSystem,
    @required FileSystemUtils fileSystemUtils,
    @required Platform platform,
    @required PlistParser plistParser,
    @required ProcessManager processManager,
    @required ProcessUtils processUtils,
    @required UserMessages userMessages,
  }) {
    final List<AndroidStudio> studios = AndroidStudio.allInstalled(
      config: config,
      fileSystem: fileSystem,
      fileSystemUtils: fileSystemUtils,
      platform: platform,
      plistParser: plistParser,
      processManager: processManager,
      processUtils: processUtils,
    );
    return <DoctorValidator>[
      if (studios.isEmpty)
        NoAndroidStudioValidator(config: config, platform: platform, userMessages: userMessages)
      else
        ...studios.map<DoctorValidator>(
          (AndroidStudio studio) => AndroidStudioValidator(studio, fileSystem: fileSystem, userMessages: userMessages)
        ),
    ];
  }

  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];
    ValidationType type = ValidationType.missing;

    final String studioVersionText = _studio.version == Version.unknown
      ? null
      : _userMessages.androidStudioVersion(_studio.version.toString());
    messages.add(ValidationMessage(
      _userMessages.androidStudioLocation(_studio.directory),
    ));

    final IntelliJPlugins plugins = IntelliJPlugins(_studio.pluginsPath, fileSystem: _fileSystem);
    plugins.validatePackage(
      messages,
      <String>['flutter-intellij', 'flutter-intellij.jar'],
      'Flutter',
      IntelliJPlugins.kIntellijFlutterPluginUrl,
      minVersion: IntelliJPlugins.kMinFlutterPluginVersion,
    );
    plugins.validatePackage(
      messages,
      <String>['Dart'],
      'Dart',
      IntelliJPlugins.kIntellijDartPluginUrl,
    );

    if (_studio.isValid) {
      type = _hasIssues(messages)
        ? ValidationType.partial
        : ValidationType.installed;
      messages.addAll(_studio.validationMessages.map<ValidationMessage>(
        (String m) => ValidationMessage(m),
      ));
    } else {
      type = ValidationType.partial;
      messages.addAll(_studio.validationMessages.map<ValidationMessage>(
        (String m) => ValidationMessage.error(m),
      ));
      messages.add(ValidationMessage(_userMessages.androidStudioNeedsUpdate));
      if (_studio.configured != null) {
        messages.add(ValidationMessage(_userMessages.androidStudioResetDir));
      }
    }

    return ValidationResult(type, messages, statusInfo: studioVersionText);
  }

  bool _hasIssues(List<ValidationMessage> messages) {
    return messages.any((ValidationMessage message) => message.isError);
  }
}

class NoAndroidStudioValidator extends DoctorValidator {
  NoAndroidStudioValidator({
    @required Config config,
    @required Platform platform,
    @required UserMessages userMessages,
  }) : _config = config,
       _platform = platform,
       _userMessages = userMessages,
       super('Android Studio');

  final Config _config;
  final Platform _platform;
  final UserMessages _userMessages;

  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];

    final String cfgAndroidStudio = _config.getValue(
      'android-studio-dir',
    ) as String;
    if (cfgAndroidStudio != null) {
      messages.add(ValidationMessage.error(
        _userMessages.androidStudioMissing(cfgAndroidStudio),
      ));
    }
    messages.add(ValidationMessage(_userMessages.androidStudioInstallation(_platform)));

    return ValidationResult(
      ValidationType.notAvailable,
      messages,
      statusInfo: 'not installed',
    );
  }
}
