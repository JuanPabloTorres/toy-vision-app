import 'dart:convert';
import 'dart:io';

import 'certification/corpus_evaluator.dart';
import 'certification/corpus_models.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.first == '--help') {
    _usage();
    return;
  }
  try {
    switch (arguments.first) {
      case 'validate':
        _require(arguments, 2);
        final corpus = CorpusDefinition.load(arguments[1]);
        final errors = corpus.validate();
        if (errors.isEmpty) {
          stdout.writeln('VALID: ${corpus.sessions.length} sessions');
        } else {
          stderr.writeln(errors.map((error) => 'BLOCKED: $error').join('\n'));
          exitCode = 2;
        }
      case 'evaluate':
        _require(arguments, 2);
        final corpus = CorpusDefinition.load(arguments[1]);
        final output = arguments.length >= 3
            ? Directory(arguments[2])
            : Directory(
                'certification/results/'
                '${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}',
              );
        final report = await CorpusEvaluator().evaluate(
          corpus,
          outputDirectory: output,
        );
        stdout.writeln(
          const JsonEncoder.withIndent('  ').convert(report.toJson()),
        );
        stdout.writeln('Evidence: ${output.absolute.path}');
        exitCode = report.isBlocked
            ? 2
            : report.passed
                ? 0
                : 1;
      case 'calibrate-embedding':
        _require(arguments, 3);
        final corpus = CorpusDefinition.load(arguments[1]);
        final report = await CorpusEvaluator().calibrateEmbedding(
          corpus,
          outputFile: File(arguments[2]),
        );
        stdout.writeln(
          const JsonEncoder.withIndent('  ').convert(report.toJson()),
        );
        exitCode = report.isBlocked ? 2 : 0;
      case 'template':
        _require(arguments, 3);
        _writeAnnotationTemplate(
          capture: Directory(arguments[1]),
          output: File(arguments[2]),
        );
      default:
        stderr.writeln('Unknown command: ${arguments.first}');
        _usage();
        exitCode = 64;
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln('CERTIFICATION_ERROR: $error');
    stderr.writeln(stackTrace);
    exitCode = 2;
  }
}

void _writeAnnotationTemplate({
  required Directory capture,
  required File output,
}) {
  final sessionFile = File('${capture.path}/session.json');
  final framesFile = File('${capture.path}/frames.jsonl');
  if (!sessionFile.existsSync() || !framesFile.existsSync()) {
    throw const FormatException(
      'capture requires session.json and frames.jsonl',
    );
  }
  final session =
      jsonDecode(sessionFile.readAsStringSync()) as Map<String, dynamic>;
  final frames = framesFile
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .map(
        (frame) => {
          'frameId': frame['frameId'],
          'cameraMoving': false,
          'objects': <Object?>[],
        },
      )
      .toList(growable: false);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'sessionId':
          output.uri.pathSegments.last.replaceAll('.annotations.json', ''),
      'capturedScenario': session['scenario'],
      'annotationStatus': 'INCOMPLETE_REQUIRES_HUMAN_LABELING',
      'frames': frames,
      'expectedCollections': <Object?>[],
      'expectCompletion': false,
    }),
  );
  stdout.writeln('Template written: ${output.absolute.path}');
}

void _require(List<String> arguments, int length) {
  if (arguments.length < length) {
    throw const FormatException('missing command arguments');
  }
}

void _usage() {
  stdout.writeln('''
Toy Vision certification harness

  flutter pub run tools/toyvision_certify.dart validate <dataset.json>
  flutter pub run tools/toyvision_certify.dart evaluate <dataset.json> [output]
  flutter pub run tools/toyvision_certify.dart calibrate-embedding <dataset.json> <output.json>
  flutter pub run tools/toyvision_certify.dart template <capture-dir> <annotations.json>

Exit codes: 0 PASS, 1 evaluated but failed gates, 2 blocked/incomplete evidence.
''');
}
