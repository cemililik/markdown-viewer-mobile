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
///   (JSON formatter, remote sink, quiet-in-release) are a one-line
///   edit to the factory below instead of a project-wide sweep
/// - no per-call allocations for what should be a single object
/// - clean test seams: a test can call
///   `ProviderScope(overrides: [appLoggerProvider.overrideWithValue(
///   FakeLogger())])` to capture or assert log output without
///   touching production code
/// - parity with the rest of the project's "Riverpod is the only DI
///   container" rule from architecture-standards.md
///
/// Library/feature code accesses the logger via
/// `ref.read(appLoggerProvider)` for one-shot reads (typical inside
/// callbacks and async handlers) or `ref.watch(appLoggerProvider)`
/// inside widgets that should rebuild on override changes.
final appLoggerProvider = Provider<Logger>((ref) => Logger());
