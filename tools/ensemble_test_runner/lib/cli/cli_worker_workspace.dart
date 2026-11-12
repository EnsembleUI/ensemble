// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/test_timer_rewriter.dart';
import 'package:path/path.dart' as p;

/// Owns isolated Flutter worker directories used by parallel CLI runs.
///
/// A worker is a linked view of the application with its own build directory.
final class CliWorkerWorkspace {
  CliWorkerWorkspace(this.appDir);

  final String appDir;

  String prepare(
    int workerIndex,
    TestTimerRewritePlan timerPlan, {
    required String testEntryRelativePath,
    bool copyPlatformProjects = false,
  }) {
    final worker = Directory(directory(workerIndex))
      ..createSync(recursive: true);
    try {
      final sourceNames = <String>{};
      for (final entity in Directory(appDir).listSync(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name == 'build' || name == '.git' || name == '.dart_tool') {
          continue;
        }
        sourceNames.add(name);
        if (copyPlatformProjects && name == 'android') {
          _copyPlatformProject(entity.absolute.path, p.join(worker.path, name),
              excludedDirectories: const {'.gradle', '.kotlin', 'build'});
          _limitAndroidGradleMemory(p.join(worker.path, name));
          continue;
        }
        if (copyPlatformProjects && name == 'ios') {
          _copyPlatformProject(entity.absolute.path, p.join(worker.path, name),
              excludedDirectories: const {'Pods', '.symlinks', 'build'});
          continue;
        }
        _replaceWithLink(p.join(worker.path, name), entity.absolute.path);
      }
      for (final entity in worker.listSync(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name == 'build' ||
            name == '.dart_tool' ||
            sourceNames.contains(name)) {
          continue;
        }
        entity.deleteSync(recursive: true);
      }

      final sourceTool = Directory(p.join(appDir, '.dart_tool'));
      final workerToolPath = p.join(worker.path, '.dart_tool');
      // An interrupted run may leave a worker behind. Keep its reusable build
      // cache, but replace the package config directory before materializing
      // the current source snapshot; createSync on the stale directory would
      // otherwise abort every subsequent attempt to reuse this worker slot.
      _deleteEntity(workerToolPath);
      final workerTool = Directory(workerToolPath)..createSync();
      for (final name in const [
        'package_config.json',
        'package_graph.json',
        'version'
      ]) {
        final source = File(p.join(sourceTool.path, name));
        if (source.existsSync()) {
          source.copySync(p.join(workerTool.path, name));
        }
      }
      _materializePathConfiguration(worker.path);
      _materializeTestEntry(worker.path, testEntryRelativePath);
      _materializeTimerScreens(worker.path, timerPlan);
      timerPlan.applyTo(worker.path);
      return worker.path;
    } catch (error, stackTrace) {
      // Preparation owns this worker directory until it returns successfully.
      // Remove partial links/build inputs if config materialization or timer
      // rewriting fails, then let the original error reach the CLI.
      try {
        _deleteEntity(worker.path);
      } catch (_) {
        // Preserve the preparation failure if the filesystem also rejects
        // best-effort cleanup; the outer CLI teardown can retry cleanup.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  String directory(int workerIndex) => p.join(
        appDir,
        'build',
        'ensemble_test_runner',
        'workers',
        'worker${workerIndex + 1}',
      );

  void copyArtifacts(int workerIndex) {
    final source = Directory(
        p.join(directory(workerIndex), 'build', 'ensemble_test_runner'));
    if (!source.existsSync()) return;
    final target = Directory(p.join(appDir, 'build', 'ensemble_test_runner'))
      ..createSync(recursive: true);
    _copyDirectoryContents(source, target);
  }

  void clean() {
    final workers =
        Directory(p.join(appDir, 'build', 'ensemble_test_runner', 'workers'));
    if (workers.existsSync()) workers.deleteSync(recursive: true);
  }

  void _materializePathConfiguration(String workerDir) {
    for (final name in const ['pubspec.yaml', 'pubspec_overrides.yaml']) {
      final source = File(p.join(appDir, name));
      if (!source.existsSync()) continue;
      final target = File(p.join(workerDir, name));
      _deleteEntity(target.path);
      target
          .writeAsStringSync(_absolutizePathEntries(source.readAsStringSync()));
    }
    final config = File(p.join(workerDir, '.dart_tool', 'package_config.json'));
    if (!config.existsSync()) return;
    final dynamic decoded = json.decode(config.readAsStringSync());
    if (decoded is! Map<String, dynamic> || decoded['packages'] is! List)
      return;
    final sourceConfig = p.join(appDir, '.dart_tool');
    for (final dynamic raw in decoded['packages'] as List) {
      if (raw is! Map<String, dynamic> || raw['rootUri'] is! String) continue;
      final uri = Uri.parse(raw['rootUri'] as String);
      final root = uri.isAbsolute
          ? (uri.scheme == 'file' ? uri.toFilePath() : null)
          : p.normalize(p.join(sourceConfig, p.fromUri(uri)));
      // Pub normally writes relative roots, but an absolute file URI is valid
      // too. Rebase the app package in both forms so workers never compile
      // against the source checkout while external dependencies stay shared.
      if (root == null) continue;
      final packageRoot =
          p.equals(p.normalize(root), p.normalize(appDir)) ? workerDir : root;
      raw['rootUri'] = Directory(packageRoot).absolute.uri.toString();
    }
    config.writeAsStringSync(json.encode(decoded));
  }

  /// Resolves relative dependency path entries for an isolated worker.
  ///
  /// The worker receives the original project manifests verbatim; only path
  /// values need rebasing because the worker lives in a different directory.
  String _absolutizePathEntries(String contents) {
    final pathEntry = RegExp(r'^(\s*path:\s*)([^#]+?)(\s*(?:#.*)?)$');
    return contents.split('\n').map((line) {
      final match = pathEntry.firstMatch(line);
      if (match == null) return line;
      var value = match.group(2)!.trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      if (p.isAbsolute(value)) return line;
      return '${match.group(1)}${json.encode(p.normalize(p.join(appDir, value)))}${match.group(3)}';
    }).join('\n');
  }

  void _materializeTimerScreens(
    String workerDir,
    TestTimerRewritePlan timerPlan,
  ) {
    if (!timerPlan.enabled || timerPlan.testsDirRelative == null) return;
    final root = p.dirname(_withoutTrailingSlash(timerPlan.testsDirRelative!));
    final relative = p.join(root, 'screens');
    final source = Directory(p.join(appDir, relative));
    if (!source.existsSync()) return;
    _materializeCopiedSubtree(workerDir, appDir, relative);
  }

  /// Flutter resolves a test target's real path when locating the project.
  /// Linking `test/` back to the application checkout therefore sends
  /// `flutter test` build output to the checkout instead of the worker. Copy
  /// the entry directory so Flutter sees the worker-local path and all
  /// relative imports beside the entry continue to resolve.
  void _materializeTestEntry(String workerDir, String entryRelativePath) {
    final entryDirectory = p.dirname(entryRelativePath);
    if (entryDirectory == '.') return;
    final source = Directory(p.join(appDir, entryDirectory));
    if (!source.existsSync()) return;
    _materializeCopiedSubtree(workerDir, appDir, entryDirectory);
  }

  void _materializeCopiedSubtree(
      String workerDir, String sourceRoot, String relative) {
    final segments = p.split(relative.replaceAll('\\', '/'));
    var sourceParent = Directory(sourceRoot);
    var targetParent = Directory(workerDir);
    for (var i = 0; i < segments.length; i++) {
      final source = Directory(p.join(sourceParent.path, segments[i]));
      final targetPath = p.join(targetParent.path, segments[i]);
      if (i == segments.length - 1) {
        _replaceWithDirectoryCopy(targetPath, source);
        return;
      }
      _replaceWithOverlayDirectory(targetPath, source,
          skipChildName: segments[i + 1]);
      sourceParent = source;
      targetParent = Directory(targetPath);
    }
  }

  void _replaceWithOverlayDirectory(String path, Directory source,
      {required String skipChildName}) {
    _deleteEntity(path);
    final target = Directory(path)..createSync(recursive: true);
    for (final entity in source.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name != skipChildName)
        _replaceWithLink(p.join(target.path, name), entity.absolute.path);
    }
  }

  void _replaceWithDirectoryCopy(String path, Directory source) {
    _deleteEntity(path);
    final target = Directory(path)..createSync(recursive: true);
    _copyDirectoryContents(source, target);
  }

  void _replaceWithLink(String path, String target) {
    _deleteEntity(path);
    Link(path).createSync(target);
  }

  void _deleteEntity(String path) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    final entity = type == FileSystemEntityType.directory
        ? Directory(path)
        : type == FileSystemEntityType.link
            ? Link(path)
            : File(path);
    entity.deleteSync(recursive: true);
  }

  void _copyDirectoryContents(Directory source, Directory target) {
    for (final entity in source.listSync(followLinks: false)) {
      final destination = p.join(target.path, p.basename(entity.path));
      if (entity is Directory) {
        _copyDirectoryContents(
            entity, Directory(destination)..createSync(recursive: true));
      } else if (entity is File) {
        entity.copySync(destination);
      }
    }
  }

  /// Integration builds must run their platform tooling from the worker path.
  /// Symlinking `android/` or `ios/` makes Gradle/Xcode canonicalize the
  /// project back to the source checkout, so Flutter looks for an APK or app
  /// bundle under the worker while the native build writes it under the host.
  /// Copy only platform project inputs; generated build and dependency caches
  /// remain worker-local and are cleaned with the workspace.
  void _copyPlatformProject(
    String sourcePath,
    String targetPath, {
    required Set<String> excludedDirectories,
  }) {
    _deleteEntity(targetPath);
    final source = Directory(sourcePath);
    final target = Directory(targetPath)..createSync(recursive: true);
    for (final entity in source.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory && excludedDirectories.contains(name)) continue;
      final destination = p.join(target.path, name);
      if (entity is Directory) {
        _copyPlatformProject(
          entity.path,
          destination,
          excludedDirectories: excludedDirectories,
        );
      } else if (entity is File) {
        entity.copySync(destination);
      } else if (entity is Link) {
        // Keep source controlled symlinks (for example Flutter plugin links),
        // but never traverse them into host build outputs.
        Link(destination).createSync(entity.targetSync());
      }
    }
  }

  /// Keep native integration builds within the same conservative memory
  /// budget as Flutter test workers. This only changes the worker copy, never
  /// the app's checked-in Gradle configuration used for normal builds.
  void _limitAndroidGradleMemory(String androidDirectory) {
    final properties = File(p.join(androidDirectory, 'gradle.properties'));
    if (!properties.existsSync()) return;
    final lines = properties.readAsLinesSync();
    const key = 'org.gradle.jvmargs';
    final index =
        lines.indexWhere((line) => line.trimLeft().startsWith('$key='));
    if (index < 0) {
      lines.add(
          '$key=-Xmx3G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError');
    } else {
      final match = RegExp(r'^\s*org\.gradle\.jvmargs\s*=\s*(.*)$')
          .firstMatch(lines[index]);
      final args = match?.group(1) ?? '';
      final bounded = args.replaceAll(RegExp(r'-Xmx\S+'), '-Xmx3G').replaceAll(
          RegExp(r'-XX:MaxMetaspaceSize=\S+'), '-XX:MaxMetaspaceSize=1G');
      lines[index] =
          bounded.contains('-Xmx') ? '$key=$bounded' : '$key=-Xmx3G $bounded';
    }
    properties.writeAsStringSync('${lines.join('\n')}\n');
  }
}

String _withoutTrailingSlash(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
}
