import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Riverpod-managed application logger.
///
/// Every non-test code path that wants to log obtains its [Logger] from
/// this provider rather than constructing one at the call site or
/// reaching for a top-level singleton. Centralising the instance gives
/// us:
///
/// - exactly one output channel, filter, and printer — future changes
///   (remote sink, Sentry breadcrumb integration) are a one-line edit
///   to the factory below instead of a project-wide sweep
/// - no per-call allocations for what should be a single object
/// - clean test seams: a test can call
///   `ProviderScope(overrides: [appLoggerProvider.overrideWithValue(
///   FakeLogger())])` to capture or assert log output without
///   touching production code
/// - parity with the rest of the project's "Riverpod is the only DI
///   container" rule from architecture-standards.md
///
/// ## Output format (ADR-0014)
///
/// - **Debug / profile builds:** [PrettyPrinter] — human-friendly,
///   coloured output that reads well in a terminal or IDE console.
/// - **Release builds:** [LogfmtPrinter] — structured key=value
///   output ready for future remote-sink ingestion (Sentry
///   breadcrumbs, file persistence, etc.) without a format migration.
///
/// The filter is set to [ProductionFilter] which only emits
/// messages at the configured level or above. In release mode we
/// suppress everything below [Level.warning] so only actionable
/// entries (warnings, errors, fatals) reach the output.
///
/// Library/feature code accesses the logger via
/// `ref.read(appLoggerProvider)` for one-shot reads (typical inside
/// callbacks and async handlers) or `ref.watch(appLoggerProvider)`
/// inside widgets that should rebuild on override changes.
///
/// The provider registers `logger.close()` with `ref.onDispose` so
/// that any output sinks (file handles, remote transports, etc.)
/// added in the future — or plugged in by test overrides — are
/// released when the container tears the provider down, not left
/// dangling until the VM exits.
final appLoggerProvider = Provider<Logger>((ref) {
  final logger = Logger(
    printer: kReleaseMode ? LogfmtPrinter() : PrettyPrinter(),
    level: kReleaseMode ? Level.warning : Level.debug,
  );
  ref.onDispose(logger.close);
  return logger;
});
