// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract interface class ExternalProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]);
}

abstract interface class ProcessRunner {
  Future<ExternalProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  });
}

final class IoProcessRunner implements ProcessRunner {
  const IoProcessRunner();

  @override
  Future<ExternalProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async => _IoExternalProcess(
    await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
    ),
  );
}

final class _IoExternalProcess implements ExternalProcess {
  const _IoExternalProcess(this._process);
  final Process _process;

  @override
  Stream<List<int>> get stderr => _process.stderr;
  @override
  Stream<List<int>> get stdout => _process.stdout;
  @override
  Future<int> get exitCode => _process.exitCode;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) =>
      _process.kill(signal);
}

final class ProcessTranscript {
  const ProcessTranscript({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

Future<ProcessTranscript> collectProcess(
  ExternalProcess process, {
  int maximumLogBytes = 64 * 1024,
}) async {
  Future<String> collect(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      final remaining = maximumLogBytes - bytes.length;
      if (remaining > 0) bytes.addAll(chunk.take(remaining));
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  final output = collect(process.stdout);
  final errors = collect(process.stderr);
  return ProcessTranscript(
    exitCode: await process.exitCode,
    stdout: await output,
    stderr: await errors,
  );
}
