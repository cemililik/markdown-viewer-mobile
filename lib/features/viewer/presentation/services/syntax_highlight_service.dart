import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:re_highlight/languages/all.dart' as reh_languages;
import 'package:re_highlight/re_highlight.dart' as reh;

const _highlightCacheCapacity = 64;

/// Highlights complete source blocks through the viewer's production
/// `re_highlight` configuration.
final class SyntaxHighlightService {
  /// Creates a highlighter with the complete built-in language registry.
  SyntaxHighlightService()
    : _highlighter =
          (reh.Highlight()
            ..registerLanguages(reh_languages.builtinAllLanguages));

  final reh.Highlight _highlighter;
  final LinkedHashMap<_HighlightCacheKey, List<SyntaxHighlightToken>>
  _syncCache = LinkedHashMap();
  final LinkedHashMap<_HighlightCacheKey, Future<List<SyntaxHighlightToken>>>
  _asyncCache = LinkedHashMap();

  /// Whether the configured registry contains [language].
  bool supports(String language) => _highlighter.getLanguage(language) != null;

  /// Highlights [source] synchronously and caches the immutable token list.
  List<SyntaxHighlightToken> highlightSynchronously(
    String source,
    String language,
  ) {
    final key = _HighlightCacheKey(source, language);
    final cached = _syncCache.remove(key);
    if (cached != null) {
      _syncCache[key] = cached;
      return cached;
    }

    final tokens = _highlight(
      highlighter: _highlighter,
      source: source,
      language: language,
    );
    _syncCache[key] = tokens;
    _trimCache(_syncCache);
    return tokens;
  }

  /// Highlights [source] on a worker isolate and caches the in-flight result.
  Future<List<SyntaxHighlightToken>> highlightInBackground(
    String source,
    String language,
  ) {
    final key = _HighlightCacheKey(source, language);
    final cached = _asyncCache.remove(key);
    if (cached != null) {
      _asyncCache[key] = cached;
      return cached;
    }

    final result = _runBackgroundHighlight(source, language);
    _asyncCache[key] = result;
    _trimCache(_asyncCache);
    return result;
  }

  Future<List<SyntaxHighlightToken>> _runBackgroundHighlight(
    String source,
    String language,
  ) async {
    try {
      final serialized = await compute(_highlightInWorker, {
        'source': source,
        'language': language,
      });
      return List.unmodifiable([
        for (final token in serialized)
          SyntaxHighlightToken(
            text: token['text'] ?? '',
            scope: token['scope'],
          ),
      ]);
    } catch (_) {
      return List.unmodifiable([SyntaxHighlightToken(text: source)]);
    }
  }

  void _trimCache<T>(LinkedHashMap<_HighlightCacheKey, T> cache) {
    while (cache.length > _highlightCacheCapacity) {
      cache.remove(cache.keys.first);
    }
  }
}

final class _HighlightCacheKey {
  const _HighlightCacheKey(this.source, this.language);

  final String source;

  final String language;

  @override
  bool operator ==(Object other) =>
      other is _HighlightCacheKey &&
      source == other.source &&
      language == other.language;

  @override
  int get hashCode => Object.hash(source, language);
}

/// One immutable token emitted by the syntax highlighter.
final class SyntaxHighlightToken {
  /// Creates a highlighted token.
  const SyntaxHighlightToken({required this.text, this.scope});

  /// Source text covered by this token.
  final String text;

  /// Optional `re_highlight` scope used to select a presentation style.
  final String? scope;
}

List<Map<String, String?>> _highlightInWorker(Map<String, String> request) {
  final highlighter =
      reh.Highlight()..registerLanguages(reh_languages.builtinAllLanguages);
  return _highlight(
    highlighter: highlighter,
    source: request['source'] ?? '',
    language: request['language'] ?? '',
  ).map((token) => {'text': token.text, 'scope': token.scope}).toList();
}

List<SyntaxHighlightToken> _highlight({
  required reh.Highlight highlighter,
  required String source,
  required String language,
}) {
  try {
    final result = highlighter.highlight(code: source, language: language);
    final renderer = _HighlightTokenRenderer();
    result.render(renderer);
    return List.unmodifiable(
      renderer.tokens.isEmpty
          ? [SyntaxHighlightToken(text: source)]
          : renderer.tokens,
    );
  } catch (_) {
    return List.unmodifiable([SyntaxHighlightToken(text: source)]);
  }
}

final class _HighlightTokenRenderer implements reh.HighlightRenderer {
  final List<String?> _scopeStack = [];
  final List<SyntaxHighlightToken> _tokens = [];

  List<SyntaxHighlightToken> get tokens => _tokens;

  @override
  void addText(String text) {
    if (text.isEmpty) return;
    final scope = _scopeStack.isEmpty ? null : _scopeStack.last;
    if (_tokens.isNotEmpty && _tokens.last.scope == scope) {
      final previous = _tokens.removeLast();
      _tokens.add(
        SyntaxHighlightToken(text: previous.text + text, scope: scope),
      );
      return;
    }
    _tokens.add(SyntaxHighlightToken(text: text, scope: scope));
  }

  @override
  void openNode(reh.DataNode node) => _scopeStack.add(node.scope);

  @override
  void closeNode(reh.DataNode node) => _scopeStack.removeLast();
}
