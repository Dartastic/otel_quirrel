// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_quirrel/otel_quirrel.dart';

/// Traces Quirrel calls with OpenTelemetry.
///
/// `otel_quirrel` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Quirrel call in
/// [tracedQuirrel]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'quirrel-example');

  // Wraps a Quirrel API call in a CLIENT span.
  final quirrelId = await tracedQuirrel<String>(
    operation: 'cron.register',
    invoke: () async {
      // Make the Quirrel call here, then report what it returned.
      const id = 'quirrel_8f3a2c';
      return const QuirrelCallResult(
          value: id,
          result: QuirrelResult(
              jobId: 'job_8f3a2c',
              queueName: 'orders',
              endpoint: 'example',
              cronExpression: 'example',
              scheduleType: 'every',
              exclusive: true,
              override: true,
              retryCount: 3,
              runAtSec: 1,
              statusCode: 200));
    },
  );
  OTelLog.info('tracedQuirrel cron.register returned $quirrelId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutQuirrelInstrumentationAsync.
  await runWithoutQuirrelInstrumentationAsync(
    () => tracedQuirrel<String>(
      operation: 'cron.register',
      invoke: () async {
        const id = 'quirrel_8f3a2c';
        return const QuirrelCallResult(
            value: id,
            result: QuirrelResult(
                jobId: 'job_8f3a2c',
                queueName: 'orders',
                endpoint: 'example',
                cronExpression: 'example',
                scheduleType: 'every',
                exclusive: true,
                override: true,
                retryCount: 3,
                runAtSec: 1,
                statusCode: 200));
      },
    ),
  );

  await OTel.shutdown();
}
