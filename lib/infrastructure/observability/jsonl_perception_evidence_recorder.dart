import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/observability/session_evidence.dart';

class CaptureConfiguration {
  const CaptureConfiguration({
    required this.enabled,
    required this.includeFrames,
    required this.scenario,
  });

  factory CaptureConfiguration.fromEnvironment() => const CaptureConfiguration(
        enabled: bool.fromEnvironment('TOYVISION_CAPTURE'),
        includeFrames: bool.fromEnvironment('TOYVISION_CAPTURE_FRAMES'),
        scenario: String.fromEnvironment(
          'TOYVISION_CAPTURE_SCENARIO',
          defaultValue: 'unclassified_physical_session',
        ),
      );

  final bool enabled;
  final bool includeFrames;
  final String scenario;
}

typedef CaptureRootProvider = Future<Directory> Function();

/// Development-only evidence recorder. It is a no-op unless explicitly
/// enabled at build time. Pixel retention requires a separate explicit flag.
class JsonlPerceptionEvidenceRecorder implements PerceptionEvidenceSink {
  JsonlPerceptionEvidenceRecorder({
    CaptureConfiguration? configuration,
    CaptureRootProvider? rootProvider,
  })  : configuration = configuration ?? CaptureConfiguration.fromEnvironment(),
        _rootProvider = rootProvider ?? _defaultRoot;

  final CaptureConfiguration configuration;
  final CaptureRootProvider _rootProvider;

  Directory? _sessionDirectory;
  IOSink? _framesSink;
  Future<void> _pending = Future<void>.value();

  String? get sessionPath => _sessionDirectory?.path;

  @override
  Future<void> startSession(DateTime startedAt) {
    if (!configuration.enabled) return Future<void>.value();
    return _serialize(() async {
      await _closeSink();
      final root = await _rootProvider();
      final captures = Directory('${root.path}/toyvision_captures');
      await captures.create(recursive: true);
      final stamp = startedAt
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final safeScenario = configuration.scenario.replaceAll(
        RegExp('[^A-Za-z0-9_-]'),
        '_',
      );
      final session = Directory('${captures.path}/${stamp}_$safeScenario');
      await session.create(recursive: true);
      if (configuration.includeFrames) {
        await Directory('${session.path}/frames').create(recursive: true);
      }
      await File('${session.path}/session.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'createdAt': startedAt.toUtc().toIso8601String(),
          'scenario': configuration.scenario,
          'framesStored': configuration.includeFrames,
          'embeddingExtractor': 'recorded_per_frame',
          'privacy': configuration.includeFrames
              ? 'DEVELOPMENT_DATASET_PIXELS_EXPLICITLY_ENABLED'
              : 'metadata_only_no_pixels_retained',
          'platform': Platform.operatingSystem,
          'platformVersion': Platform.operatingSystemVersion,
        }),
        flush: true,
      );
      _sessionDirectory = session;
      _framesSink = File('${session.path}/frames.jsonl').openWrite(
        mode: FileMode.append,
      );
      developer.log(
        'TOYVISION_CAPTURE_PATH=${session.path}',
        name: 'toyvision.capture',
      );
    });
  }

  @override
  Future<void> record(SessionEvidenceFrame evidence) {
    if (!configuration.enabled) return Future<void>.value();
    return _serialize(() async {
      if (_sessionDirectory == null) {
        await _startImplicitSession(evidence.frame.timestamp);
      }
      String? imagePath;
      if (configuration.includeFrames) {
        imagePath =
            'frames/frame_${evidence.frame.frameId.toString().padLeft(8, '0')}.jpg';
        await File('${_sessionDirectory!.path}/$imagePath').writeAsBytes(
          evidence.frame.encodedImage,
          flush: false,
        );
      }
      _framesSink!.writeln(
        jsonEncode(sessionEvidenceToJson(evidence, imagePath: imagePath)),
      );
      await _framesSink!.flush();
    });
  }

  @override
  Future<void> close() => _serialize(_closeSink);

  Future<void> _startImplicitSession(DateTime timestamp) async {
    final root = await _rootProvider();
    final session = Directory(
      '${root.path}/toyvision_captures/implicit_${timestamp.microsecondsSinceEpoch}',
    );
    await session.create(recursive: true);
    if (configuration.includeFrames) {
      await Directory('${session.path}/frames').create(recursive: true);
    }
    await File('${session.path}/session.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'createdAt': timestamp.toUtc().toIso8601String(),
        'scenario': configuration.scenario,
        'framesStored': configuration.includeFrames,
        'embeddingExtractor': 'recorded_per_frame',
        'privacy': configuration.includeFrames
            ? 'DEVELOPMENT_DATASET_PIXELS_EXPLICITLY_ENABLED'
            : 'metadata_only_no_pixels_retained',
        'platform': Platform.operatingSystem,
        'platformVersion': Platform.operatingSystemVersion,
        'implicitStart': true,
      }),
      flush: true,
    );
    _sessionDirectory = session;
    _framesSink = File('${session.path}/frames.jsonl').openWrite();
  }

  Future<void> _serialize(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _closeSink() async {
    final sink = _framesSink;
    _framesSink = null;
    if (sink != null) await sink.close();
    _sessionDirectory = null;
  }

  static Future<Directory> _defaultRoot() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) return external;
    }
    return getApplicationSupportDirectory();
  }
}
