import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_lru_cache.dart';

void main() {
  group('MermaidLruCache', () {
    test('should return null for a key that has never been inserted', () {
      final cache = MermaidLruCache(capacity: 4);

      expect(cache.get('absent'), isNull);
      expect(cache.length, 0);
    });

    test('should return the value for a key that was just inserted', () {
      final cache = MermaidLruCache(capacity: 4);

      cache.put('a', 'svg-a');

      expect(cache.get('a'), 'svg-a');
      expect(cache.length, 1);
    });

    test(
      'should evict the least-recently-used entry when capacity is exceeded',
      () {
        final cache = MermaidLruCache(capacity: 2);

        cache.put('a', 'svg-a');
        cache.put('b', 'svg-b');
        cache.put('c', 'svg-c');

        expect(cache.length, 2);
        expect(cache.get('a'), isNull, reason: '`a` was the LRU entry');
        expect(cache.get('b'), 'svg-b');
        expect(cache.get('c'), 'svg-c');
      },
    );

    test('should promote an entry to MRU when it is read via get', () {
      final cache = MermaidLruCache(capacity: 2);

      cache.put('a', 'svg-a');
      cache.put('b', 'svg-b');
      // Touch `a` so it becomes MRU; the next put must evict `b`.
      expect(cache.get('a'), 'svg-a');
      cache.put('c', 'svg-c');

      expect(
        cache.get('b'),
        isNull,
        reason: 'b should have been evicted, not a',
      );
      expect(cache.get('a'), 'svg-a');
      expect(cache.get('c'), 'svg-c');
    });

    test('should refresh the position of an entry that is re-inserted', () {
      final cache = MermaidLruCache(capacity: 2);

      cache.put('a', 'svg-a');
      cache.put('b', 'svg-b');
      cache.put('a', 'svg-a-v2');
      cache.put('c', 'svg-c');

      expect(cache.get('a'), 'svg-a-v2');
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), 'svg-c');
    });

    test('should drop every entry when clear is called', () {
      final cache = MermaidLruCache(capacity: 4);
      cache.put('a', 'svg-a');
      cache.put('b', 'svg-b');

      cache.clear();

      expect(cache.length, 0);
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), isNull);
    });

    test('should reject a non-positive capacity at construction', () {
      // ArgumentError (not AssertionError) so release builds also
      // refuse to construct an unusable cache; release mode strips
      // asserts entirely.
      expect(() => MermaidLruCache(capacity: 0), throwsA(isA<ArgumentError>()));
      expect(
        () => MermaidLruCache(capacity: -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
