// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_quirrel_suppression.dart';

const _tracerName = 'dartastic_otel_libs_quirrel';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class QuirrelResult {
  /// Creates a result.
  const QuirrelResult({
    this.jobId,
    this.queueName,
    this.endpoint,
    this.cronExpression,
    this.scheduleType,
    this.exclusive,
    this.override,
    this.retryCount,
    this.runAtSec,
    this.statusCode,
  });

  final String? jobId;
  final String? queueName;

  /// HTTP endpoint Quirrel calls when the job is due.
  final String? endpoint;

  /// Cron expression for repeating jobs.
  final String? cronExpression;

  /// `every` / `cron` / `at` / `now` — Quirrel's schedule types.
  final String? scheduleType;

  /// `true` when the job ran with an exclusive lock (no concurrent
  /// duplicates).
  final bool? exclusive;

  /// `true` when a duplicate-id submission was overridden.
  final bool? override;

  final int? retryCount;

  /// Seconds until next scheduled run.
  final int? runAtSec;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class QuirrelCallResult<T> {
  /// Creates a call result.
  const QuirrelCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final QuirrelResult? result;
}

/// Wraps a Quirrel API call in a CLIENT span. [operation] is one of
/// `enqueue`, `invoke`, `delete`, `get`, `list`, `cron.register`,
/// `cron.invoke`.
Future<T> tracedQuirrel<T>({
  required String operation,
  required Future<QuirrelCallResult<T>> Function() invoke,
}) async {
  if (quirrelInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'quirrel',
    'rpc.method': operation,
    'quirrel.operation': operation,
  };

  final span = _tracer().startSpan(
    'quirrel $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.jobId != null) {
        extras.add(OTelAPI.attributeString('quirrel.job.id', r.result!.jobId!));
      }
      if (r.result!.queueName != null) {
        extras.add(OTelAPI.attributeString(
          'quirrel.queue.name',
          r.result!.queueName!,
        ));
      }
      if (r.result!.endpoint != null) {
        extras.add(OTelAPI.attributeString(
          'quirrel.endpoint',
          r.result!.endpoint!,
        ));
      }
      if (r.result!.cronExpression != null) {
        extras.add(OTelAPI.attributeString(
          'quirrel.cron',
          r.result!.cronExpression!,
        ));
      }
      if (r.result!.scheduleType != null) {
        extras.add(OTelAPI.attributeString(
          'quirrel.schedule.type',
          r.result!.scheduleType!,
        ));
      }
      if (r.result!.exclusive != null) {
        extras.add(OTelAPI.attributeBool(
          'quirrel.exclusive',
          r.result!.exclusive!,
        ));
      }
      if (r.result!.override != null) {
        extras.add(OTelAPI.attributeBool(
          'quirrel.override',
          r.result!.override!,
        ));
      }
      if (r.result!.retryCount != null) {
        extras.add(OTelAPI.attributeInt(
          'quirrel.retry.count',
          r.result!.retryCount!,
        ));
      }
      if (r.result!.runAtSec != null) {
        extras.add(OTelAPI.attributeInt(
          'quirrel.run_at_sec',
          r.result!.runAtSec!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Quirrel HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
