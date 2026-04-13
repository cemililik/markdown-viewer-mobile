/// Bounded in-memory LRU cache keyed by [String], generic value.
///
/// Designed for the mermaid renderer where the key is the hex
/// SHA-256 of a `(initDirective + source)` pair and the value is
/// the rasterised bitmap + its natural dimensions. The cache lives
/// entirely in process memory; surviving across app restarts is a
/// non-goal for v1 (see ADR-0005).
///
/// Implementation notes:
///
/// - Backed by [LinkedHashMap], whose insertion order is the
///   recency order. A `get` removes and re-inserts the entry to
///   move it to the most-recently-used position.
/// - Eviction is triggered on `put` when [length] exceeds
///   [capacity]: the first entry of [LinkedHashMap.keys] (the
///   least-recently-used) is removed.
/// - Pure Dart and stateless beyond the map — unit-testable in
///   isolation without pumping a widget or spinning up a WebView.
class MermaidLruCache<V> {
  MermaidLruCache({required this.capacity}) {
    if (capacity <= 0) {
      // ArgumentError (not an assert) so a release build still
      // refuses to construct an unusable cache. An assert would be
      // stripped in release mode and silently turn every put into
      // an instant eviction.
      throw ArgumentError.value(
        capacity,
        'capacity',
        'MermaidLruCache.capacity must be positive',
      );
    }
  }

  final int capacity;
  final Map<String, V> _entries = <String, V>{};

  /// Number of entries currently held.
  int get length => _entries.length;

  /// Looks up [key] and promotes it to most-recently-used. Returns
  /// `null` if absent.
  V? get(String key) {
    final value = _entries.remove(key);
    if (value == null) {
      return null;
    }
    _entries[key] = value;
    return value;
  }

  /// Inserts [value] under [key], evicting the least-recently-used
  /// entry if [capacity] would otherwise be exceeded. If [key] is
  /// already present its position is refreshed.
  void put(String key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Removes every entry. Used by tests and by
  /// `MermaidRendererImpl.dispose`.
  void clear() => _entries.clear();
}
