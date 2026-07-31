// ABOUTME: Parses Android OAuth callback routing as a structural regression test.
// ABOUTME: Pins the plugin activity and prevents MainActivity callback overlap.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _androidNamespace = 'http://schemas.android.com/apk/res/android';
const _callbackActivityName = 'com.linusu.flutter_web_auth_2.CallbackActivity';

void main() {
  group('crossposting OAuth callback manifest', () {
    test('registers one exact callback without MainActivity overlap', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(_hasSafeCallbackRegistration(manifest), isTrue);
    });

    test('structural validator rejects missing and broadened declarations', () {
      final invalidManifests = <String, String>{
        'missing activity': _validManifest.replaceFirst(
          _callbackActivityName,
          'example.MissingCallbackActivity',
        ),
        'not exported': _validManifest.replaceFirst(
          'android:exported="true"',
          'android:exported="false"',
        ),
        'missing auto verification': _validManifest.replaceFirst(
          ' android:autoVerify="true"',
          '',
        ),
        'wrong filter label': _validManifest.replaceFirst(
          'android:label="flutter_web_auth_2"',
          'android:label="oauth"',
        ),
        'missing VIEW action': _validManifest.replaceFirst(
          '<action android:name="android.intent.action.VIEW" />',
          '',
        ),
        'extra action': _validManifest.replaceFirst(
          '<action android:name="android.intent.action.VIEW" />',
          '<action android:name="android.intent.action.VIEW" />\n'
              '        <action android:name="android.intent.action.MAIN" />',
        ),
        'duplicate action': _validManifest.replaceFirst(
          '<action android:name="android.intent.action.VIEW" />',
          '<action android:name="android.intent.action.VIEW" />\n'
              '        <action android:name="android.intent.action.VIEW" />',
        ),
        'missing DEFAULT category': _validManifest.replaceFirst(
          '<category android:name="android.intent.category.DEFAULT" />',
          '',
        ),
        'extra category': _validManifest.replaceFirst(
          '<category android:name="android.intent.category.BROWSABLE" />',
          '<category android:name="android.intent.category.BROWSABLE" />\n'
              '        <category android:name="android.intent.category.LAUNCHER" />',
        ),
        'custom callback scheme': _validManifest.replaceFirst(
          'android:scheme="https"',
          'android:scheme="divine"',
        ),
        'missing callback host': _validManifest.replaceFirst(
          '          android:host="divine.video"\n',
          '',
        ),
        'broadened host': _validManifest.replaceFirst(
          'android:host="divine.video"',
          'android:host="*"',
        ),
        'missing callback path': _validManifest.replaceFirst(
          '          android:path="/app/callback" />',
          '          />',
        ),
        'path prefix instead of exact path': _validManifest.replaceFirst(
          'android:path="/app/callback"',
          'android:pathPrefix="/app"',
        ),
        'additional callback data': _validManifest.replaceFirst(
          '</intent-filter>',
          '<data android:scheme="divine" />\n'
              '      </intent-filter>',
        ),
      };

      for (final invalidManifest in invalidManifests.entries) {
        expect(
          _hasSafeCallbackRegistration(invalidManifest.value),
          isFalse,
          reason: invalidManifest.key,
        );
      }
    });

    test('structural validator rejects MainActivity callback overlap', () {
      final broadenedManifest = _validManifest.replaceFirst(
        '<data android:pathPrefix="/video" />',
        '<data android:pathPrefix="/video" />\n'
            '        <data android:path="/app/callback" />',
      );

      expect(_hasSafeCallbackRegistration(broadenedManifest), isFalse);
    });
  });
}

bool _hasSafeCallbackRegistration(String source) {
  try {
    final document = XmlDocument.parse(source);
    final applicationElements = document.rootElement.childElements.where(
      (element) => element.name.local == 'application',
    );
    if (applicationElements.length != 1) return false;

    final callbackActivities = applicationElements.single.childElements.where(
      (element) =>
          element.name.local == 'activity' &&
          _androidAttribute(element, 'name') == _callbackActivityName,
    );
    if (callbackActivities.length != 1) return false;

    final activity = callbackActivities.single;
    if (_androidAttribute(activity, 'exported') != 'true') return false;

    final intentFilters = activity.childElements.where(
      (element) => element.name.local == 'intent-filter',
    );
    if (intentFilters.length != 1) return false;

    final intentFilter = intentFilters.single;
    if (_androidAttribute(intentFilter, 'autoVerify') != 'true' ||
        _androidAttribute(intentFilter, 'label') != 'flutter_web_auth_2') {
      return false;
    }

    if (!_hasExactAndroidNames(intentFilter, 'action', const {
      'android.intent.action.VIEW',
    })) {
      return false;
    }

    if (!_hasExactAndroidNames(intentFilter, 'category', const {
      'android.intent.category.DEFAULT',
      'android.intent.category.BROWSABLE',
    })) {
      return false;
    }

    final dataElements = intentFilter.childElements.where(
      (element) => element.name.local == 'data',
    );
    if (dataElements.length != 1) return false;

    final data = dataElements.single;
    final dataAttributeNames = data.attributes
        .where((attribute) => attribute.name.namespaceUri == _androidNamespace)
        .map((attribute) => attribute.name.local)
        .toSet();
    final hasExactCallbackData =
        _hasExactValues(dataAttributeNames, const {'scheme', 'host', 'path'}) &&
        _androidAttribute(data, 'scheme') == 'https' &&
        _androidAttribute(data, 'host') == 'divine.video' &&
        _androidAttribute(data, 'path') == '/app/callback';
    return hasExactCallbackData &&
        !_mainActivityClaimsCallback(applicationElements.single);
  } on XmlParserException {
    return false;
  }
}

bool _mainActivityClaimsCallback(XmlElement application) {
  final mainActivities = application.childElements.where(
    (element) =>
        element.name.local == 'activity' &&
        _androidAttribute(element, 'name') == '.MainActivity',
  );
  if (mainActivities.length != 1) return true;

  return mainActivities.single.childElements
      .where((element) => element.name.local == 'intent-filter')
      .any(_intentFilterClaimsCallback);
}

bool _intentFilterClaimsCallback(XmlElement intentFilter) {
  final actions = _androidNames(intentFilter, 'action');
  final categories = _androidNames(intentFilter, 'category');
  if (!actions.contains('android.intent.action.VIEW') ||
      !categories.contains('android.intent.category.DEFAULT') ||
      !categories.contains('android.intent.category.BROWSABLE')) {
    return false;
  }

  final dataElements = intentFilter.childElements.where(
    (element) => element.name.local == 'data',
  );
  final schemes = _androidDataValues(dataElements, 'scheme');
  if (!schemes.contains('https')) return false;

  final hosts = _androidDataValues(dataElements, 'host');
  if (hosts.isNotEmpty && !hosts.any(_hostMatchesDivine)) return false;

  return _dataClaimsCallbackPath(dataElements);
}

bool _hostMatchesDivine(String host) {
  final normalizedHost = host.toLowerCase();
  if (normalizedHost == 'divine.video') return true;
  if (!normalizedHost.startsWith('*')) return false;
  return 'divine.video'.endsWith(normalizedHost.substring(1));
}

bool _dataClaimsCallbackPath(Iterable<XmlElement> dataElements) {
  var hasPathConstraint = false;
  for (final data in dataElements) {
    final path = _androidAttribute(data, 'path');
    if (path != null) {
      hasPathConstraint = true;
      if (path == '/app/callback') return true;
    }

    final pathPrefix = _androidAttribute(data, 'pathPrefix');
    if (pathPrefix != null) {
      hasPathConstraint = true;
      if ('/app/callback'.startsWith(pathPrefix)) return true;
    }

    final pathPattern = _androidAttribute(data, 'pathPattern');
    if (pathPattern != null) {
      hasPathConstraint = true;
      if (_patternCouldMatchCallback(pathPattern)) return true;
    }
  }
  return !hasPathConstraint;
}

bool _patternCouldMatchCallback(String pattern) {
  final firstPatternToken = pattern.indexOf(RegExp(r'[.*+?\[\]{}\\]'));
  if (firstPatternToken == -1) return pattern == '/app/callback';
  return '/app/callback'.startsWith(pattern.substring(0, firstPatternToken));
}

String? _androidAttribute(XmlElement element, String name) =>
    element.getAttribute(name, namespace: _androidNamespace);

Set<String?> _androidNames(XmlElement parent, String elementName) => parent
    .childElements
    .where((element) => element.name.local == elementName)
    .map((element) => _androidAttribute(element, 'name'))
    .toSet();

Set<String> _androidDataValues(
  Iterable<XmlElement> dataElements,
  String attributeName,
) => dataElements
    .map((element) => _androidAttribute(element, attributeName))
    .whereType<String>()
    .toSet();

bool _hasExactAndroidNames(
  XmlElement parent,
  String elementName,
  Set<String> expected,
) {
  final elements = parent.childElements.where(
    (element) => element.name.local == elementName,
  );
  final names = elements
      .map((element) => _androidAttribute(element, 'name'))
      .toSet();
  return elements.length == expected.length && _hasExactValues(names, expected);
}

bool _hasExactValues<T>(Set<T> actual, Set<T> expected) =>
    actual.length == expected.length && actual.containsAll(expected);

const _validManifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application>
    <activity
      android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
      android:exported="true">
      <intent-filter
        android:label="flutter_web_auth_2"
        android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
          android:scheme="https"
          android:host="divine.video"
          android:path="/app/callback" />
      </intent-filter>
    </activity>
    <activity
      android:name=".MainActivity"
      android:exported="true">
      <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" />
        <data android:host="divine.video" />
        <data android:pathPrefix="/video" />
      </intent-filter>
    </activity>
  </application>
</manifest>
''';
