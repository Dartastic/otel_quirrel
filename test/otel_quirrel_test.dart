// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_quirrel/otel_quirrel.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_quirrel-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('cron.register records queue + cron + endpoint', () async {
    await tracedQuirrel<String>(
      operation: 'cron.register',
      invoke: () async => const QuirrelCallResult(
        value: 'ok',
        result: QuirrelResult(
          jobId: 'job_1',
          queueName: 'reports',
          endpoint: 'https://app/api/quirrel/daily-report',
          cronExpression: '0 8 * * *',
          scheduleType: 'cron',
          exclusive: true,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('quirrel cron.register')!);
    expect(a['quirrel.queue.name'], 'reports');
    expect(a['quirrel.cron'], '0 8 * * *');
    expect(a['quirrel.schedule.type'], 'cron');
    expect(a['quirrel.exclusive'], true);
  });

  test('HTTP 422 sets span error', () async {
    await tracedQuirrel<String>(
      operation: 'enqueue',
      invoke: () async => const QuirrelCallResult(
        value: 'ok',
        result: QuirrelResult(statusCode: 422),
      ),
    );
    expect(
      spans.findSpanByName('quirrel enqueue')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutQuirrelInstrumentationAsync(() async {
      await tracedQuirrel<String>(
        operation: 'list',
        invoke: () async => const QuirrelCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('quirrel '), isEmpty);
  });
}
