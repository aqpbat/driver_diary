import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layer rules of PLAN.md §3.1, checked on the import lines of every
/// file under `lib/`. A violation fails the build instead of waiting for a
/// reviewer to notice it.
void main() {
  const package = 'package:driver_app_demo/';
  final importLine = RegExp(
    r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  final lib = Directory('lib');
  final files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  /// Every import of [file]: package and `dart:` URIs as written, project
  /// files as paths from the repository root (`lib/core/...`).
  List<String> importsOf(File file) => [
    for (final match in importLine.allMatches(file.readAsStringSync()))
      if (match[1]!.startsWith(package))
        'lib/${match[1]!.substring(package.length)}'
      else if (match[1]!.contains(':'))
        match[1]!
      else
        Uri.file(file.path).resolve(match[1]!).path,
  ];

  /// `lib/features/day/...` → `day`; null outside `features/`.
  String? featureOf(String path) =>
      RegExp(r'^lib/features/([^/]+)/').firstMatch(path)?[1];

  List<String> violations(
    bool Function(String path) applies,
    bool Function(String path, String import) forbidden,
  ) => [
    for (final file in files)
      if (applies(file.path))
        for (final import in importsOf(file))
          if (forbidden(file.path, import)) '${file.path} imports $import',
  ];

  test('the checks see the project', () {
    expect(files.length, greaterThan(30));
    expect(
      importsOf(File('lib/features/day/data/models/day_dto.dart')),
      contains('lib/core/network/trip_dto.dart'),
    );
  });

  test('no Material anywhere in lib/', () {
    expect(
      violations((_) => true, (_, import) => import.contains('material')),
      isEmpty,
    );
    final usesIcons = [
      for (final file in files)
        if (RegExp(r'\bIcons\.').hasMatch(file.readAsStringSync())) file.path,
    ];
    expect(usesIcons, isEmpty, reason: 'Icons.* is the Material icon font');
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('uses-material-design: false'),
    );
  });

  test('Cupertino is used only as an engine inside the design system', () {
    expect(
      violations(
        (path) =>
            !path.startsWith('lib/core/design/') && path != 'lib/app/app.dart',
        (_, import) => import.contains('cupertino'),
      ),
      isEmpty,
    );
  });

  test('domain is pure Dart', () {
    bool isDomain(String path) =>
        path.contains('/domain/') || path.startsWith('lib/core/error/');

    expect(
      violations(isDomain, (_, import) {
        if (import.startsWith('dart:')) {
          return !const {
            'dart:async',
            'dart:math',
            'dart:core',
          }.contains(import);
        }
        if (import.startsWith('package:')) {
          return !import.startsWith('package:equatable/');
        }
        return false;
      }),
      isEmpty,
      reason: 'no flutter, http, bloc, JSON or I/O in domain',
    );
  });

  test('domain depends on nothing but domain and core/error', () {
    expect(
      violations(
        (path) =>
            path.contains('/domain/') || path.startsWith('lib/core/error/'),
        (_, import) =>
            import.startsWith('lib/') &&
            !import.contains('/domain/') &&
            !import.startsWith('lib/core/error/'),
      ),
      isEmpty,
    );
  });

  test('presentation does not import data', () {
    expect(
      violations(
        (path) => path.contains('/presentation/'),
        (_, import) =>
            import.contains('/data/') || import.startsWith('lib/core/network/'),
      ),
      isEmpty,
    );
  });

  test('blocs and cubits do not see widgets, HTTP or JSON', () {
    expect(
      violations(
        (path) => path.contains('/bloc/') || path.contains('/cubit/'),
        (_, import) =>
            import.startsWith('package:flutter/') ||
            import.startsWith('package:http/') ||
            import == 'dart:convert' ||
            import.contains('/data/'),
      ),
      isEmpty,
    );
  });

  test('data does not import presentation', () {
    expect(
      violations(
        (path) =>
            path.contains('/data/') || path.startsWith('lib/core/network/'),
        (_, import) =>
            import.contains('/presentation/') ||
            import.startsWith('package:flutter/') ||
            import.contains('bloc'),
      ),
      isEmpty,
    );
  });

  test('features do not import each other', () {
    expect(
      violations((path) => featureOf(path) != null, (path, import) {
        final other = featureOf(import);
        return other != null && other != featureOf(path);
      }),
      isEmpty,
    );
  });

  test('core does not import features or the app', () {
    expect(
      violations(
        (path) => path.startsWith('lib/core/'),
        (_, import) =>
            import.startsWith('lib/features/') || import.startsWith('lib/app/'),
      ),
      isEmpty,
    );
  });

  test('only the composition root knows every layer', () {
    expect(
      violations(
        (path) => featureOf(path) != null || path.startsWith('lib/core/'),
        (_, import) => import.startsWith('lib/app/'),
      ),
      isEmpty,
    );
  });
}
