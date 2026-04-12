import 'package:logger/logger.dart';

/// Shared application-wide [Logger] instance.
///
/// Every non-test code path that wants to log should import this symbol
/// instead of constructing a fresh `Logger()` at the call site. Central
/// ownership means:
///
/// - exactly one output channel, filter, and printer — future changes
///   (JSON formatter, remote sink, quiet-in-release) are a one-line
///   edit here instead of a project-wide sweep
/// - no per-call allocations for what should be a singleton
/// - no accidental leaking of log configuration differences between
///   features
///
/// Tests that want to observe log output should not read this symbol;
/// they should inject a fake logger through the caller's own seams.
final Logger appLogger = Logger();
