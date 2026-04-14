// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HeadingRef {

/// Heading level in the range `[1, 6]` inclusive, matching the
/// underlying markdown `#`–`######` syntax.
 int get level;/// Plain-text content of the heading with inline markup stripped.
 String get text;/// URL-safe slug used as the anchor target. Produced by
/// lowercasing [text] and collapsing runs of non-word characters.
 String get anchor;/// Zero-based index of the top-level markdown block that
/// contains this heading. Used by the TOC drawer to look up
/// a widget-side `GlobalKey` and drive
/// `Scrollable.ensureVisible` without measuring offsets by
/// hand. When a heading appears nested inside a container
/// block (blockquote, list item, admonition), this is the
/// index of that top-level container — scrolling to the
/// container is close enough for the reader to find the
/// heading.
 int get blockIndex;
/// Create a copy of HeadingRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HeadingRefCopyWith<HeadingRef> get copyWith => _$HeadingRefCopyWithImpl<HeadingRef>(this as HeadingRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HeadingRef&&(identical(other.level, level) || other.level == level)&&(identical(other.text, text) || other.text == text)&&(identical(other.anchor, anchor) || other.anchor == anchor)&&(identical(other.blockIndex, blockIndex) || other.blockIndex == blockIndex));
}


@override
int get hashCode => Object.hash(runtimeType,level,text,anchor,blockIndex);

@override
String toString() {
  return 'HeadingRef(level: $level, text: $text, anchor: $anchor, blockIndex: $blockIndex)';
}


}

/// @nodoc
abstract mixin class $HeadingRefCopyWith<$Res>  {
  factory $HeadingRefCopyWith(HeadingRef value, $Res Function(HeadingRef) _then) = _$HeadingRefCopyWithImpl;
@useResult
$Res call({
 int level, String text, String anchor, int blockIndex
});




}
/// @nodoc
class _$HeadingRefCopyWithImpl<$Res>
    implements $HeadingRefCopyWith<$Res> {
  _$HeadingRefCopyWithImpl(this._self, this._then);

  final HeadingRef _self;
  final $Res Function(HeadingRef) _then;

/// Create a copy of HeadingRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? level = null,Object? text = null,Object? anchor = null,Object? blockIndex = null,}) {
  return _then(_self.copyWith(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,anchor: null == anchor ? _self.anchor : anchor // ignore: cast_nullable_to_non_nullable
as String,blockIndex: null == blockIndex ? _self.blockIndex : blockIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [HeadingRef].
extension HeadingRefPatterns on HeadingRef {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HeadingRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HeadingRef() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HeadingRef value)  $default,){
final _that = this;
switch (_that) {
case _HeadingRef():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HeadingRef value)?  $default,){
final _that = this;
switch (_that) {
case _HeadingRef() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int level,  String text,  String anchor,  int blockIndex)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HeadingRef() when $default != null:
return $default(_that.level,_that.text,_that.anchor,_that.blockIndex);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int level,  String text,  String anchor,  int blockIndex)  $default,) {final _that = this;
switch (_that) {
case _HeadingRef():
return $default(_that.level,_that.text,_that.anchor,_that.blockIndex);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int level,  String text,  String anchor,  int blockIndex)?  $default,) {final _that = this;
switch (_that) {
case _HeadingRef() when $default != null:
return $default(_that.level,_that.text,_that.anchor,_that.blockIndex);case _:
  return null;

}
}

}

/// @nodoc


class _HeadingRef implements HeadingRef {
  const _HeadingRef({required this.level, required this.text, required this.anchor, required this.blockIndex});
  

/// Heading level in the range `[1, 6]` inclusive, matching the
/// underlying markdown `#`–`######` syntax.
@override final  int level;
/// Plain-text content of the heading with inline markup stripped.
@override final  String text;
/// URL-safe slug used as the anchor target. Produced by
/// lowercasing [text] and collapsing runs of non-word characters.
@override final  String anchor;
/// Zero-based index of the top-level markdown block that
/// contains this heading. Used by the TOC drawer to look up
/// a widget-side `GlobalKey` and drive
/// `Scrollable.ensureVisible` without measuring offsets by
/// hand. When a heading appears nested inside a container
/// block (blockquote, list item, admonition), this is the
/// index of that top-level container — scrolling to the
/// container is close enough for the reader to find the
/// heading.
@override final  int blockIndex;

/// Create a copy of HeadingRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HeadingRefCopyWith<_HeadingRef> get copyWith => __$HeadingRefCopyWithImpl<_HeadingRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HeadingRef&&(identical(other.level, level) || other.level == level)&&(identical(other.text, text) || other.text == text)&&(identical(other.anchor, anchor) || other.anchor == anchor)&&(identical(other.blockIndex, blockIndex) || other.blockIndex == blockIndex));
}


@override
int get hashCode => Object.hash(runtimeType,level,text,anchor,blockIndex);

@override
String toString() {
  return 'HeadingRef(level: $level, text: $text, anchor: $anchor, blockIndex: $blockIndex)';
}


}

/// @nodoc
abstract mixin class _$HeadingRefCopyWith<$Res> implements $HeadingRefCopyWith<$Res> {
  factory _$HeadingRefCopyWith(_HeadingRef value, $Res Function(_HeadingRef) _then) = __$HeadingRefCopyWithImpl;
@override @useResult
$Res call({
 int level, String text, String anchor, int blockIndex
});




}
/// @nodoc
class __$HeadingRefCopyWithImpl<$Res>
    implements _$HeadingRefCopyWith<$Res> {
  __$HeadingRefCopyWithImpl(this._self, this._then);

  final _HeadingRef _self;
  final $Res Function(_HeadingRef) _then;

/// Create a copy of HeadingRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? level = null,Object? text = null,Object? anchor = null,Object? blockIndex = null,}) {
  return _then(_HeadingRef(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,anchor: null == anchor ? _self.anchor : anchor // ignore: cast_nullable_to_non_nullable
as String,blockIndex: null == blockIndex ? _self.blockIndex : blockIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$Document {

/// Stable identifier for this document (currently the file path).
 DocumentId get id;/// Original markdown source exactly as read from disk, after UTF-8
/// decoding. Never mutated.
 String get source;/// Headings in document order. Empty for documents without any.
 List<HeadingRef> get headings;/// Number of newline-terminated lines in [source]. Used for
/// display (e.g. "10k lines") and for the isolate-offload threshold.
 int get lineCount;/// Byte length of the original file on disk, before UTF-8 decoding.
 int get byteSize;/// Number of top-level markdown blocks the parser produced.
/// Used by the viewer to assign one `GlobalKey` per block and
/// by the TOC drawer + in-doc search to `Scrollable.ensureVisible`
/// the correct block without pixel measuring.
///
/// When the render layer's widget count disagrees with this
/// number the viewer falls back to approximate fraction-based
/// scrolling rather than crashing — a regression in
/// `markdown_widget`'s block count per render would silently
/// produce a degraded TOC, not a broken viewer.
 int get topLevelBlockCount;
/// Create a copy of Document
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentCopyWith<Document> get copyWith => _$DocumentCopyWithImpl<Document>(this as Document, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Document&&(identical(other.id, id) || other.id == id)&&(identical(other.source, source) || other.source == source)&&const DeepCollectionEquality().equals(other.headings, headings)&&(identical(other.lineCount, lineCount) || other.lineCount == lineCount)&&(identical(other.byteSize, byteSize) || other.byteSize == byteSize)&&(identical(other.topLevelBlockCount, topLevelBlockCount) || other.topLevelBlockCount == topLevelBlockCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,source,const DeepCollectionEquality().hash(headings),lineCount,byteSize,topLevelBlockCount);

@override
String toString() {
  return 'Document(id: $id, source: $source, headings: $headings, lineCount: $lineCount, byteSize: $byteSize, topLevelBlockCount: $topLevelBlockCount)';
}


}

/// @nodoc
abstract mixin class $DocumentCopyWith<$Res>  {
  factory $DocumentCopyWith(Document value, $Res Function(Document) _then) = _$DocumentCopyWithImpl;
@useResult
$Res call({
 DocumentId id, String source, List<HeadingRef> headings, int lineCount, int byteSize, int topLevelBlockCount
});




}
/// @nodoc
class _$DocumentCopyWithImpl<$Res>
    implements $DocumentCopyWith<$Res> {
  _$DocumentCopyWithImpl(this._self, this._then);

  final Document _self;
  final $Res Function(Document) _then;

/// Create a copy of Document
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? source = null,Object? headings = null,Object? lineCount = null,Object? byteSize = null,Object? topLevelBlockCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as DocumentId,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,headings: null == headings ? _self.headings : headings // ignore: cast_nullable_to_non_nullable
as List<HeadingRef>,lineCount: null == lineCount ? _self.lineCount : lineCount // ignore: cast_nullable_to_non_nullable
as int,byteSize: null == byteSize ? _self.byteSize : byteSize // ignore: cast_nullable_to_non_nullable
as int,topLevelBlockCount: null == topLevelBlockCount ? _self.topLevelBlockCount : topLevelBlockCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Document].
extension DocumentPatterns on Document {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Document value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Document() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Document value)  $default,){
final _that = this;
switch (_that) {
case _Document():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Document value)?  $default,){
final _that = this;
switch (_that) {
case _Document() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DocumentId id,  String source,  List<HeadingRef> headings,  int lineCount,  int byteSize,  int topLevelBlockCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Document() when $default != null:
return $default(_that.id,_that.source,_that.headings,_that.lineCount,_that.byteSize,_that.topLevelBlockCount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DocumentId id,  String source,  List<HeadingRef> headings,  int lineCount,  int byteSize,  int topLevelBlockCount)  $default,) {final _that = this;
switch (_that) {
case _Document():
return $default(_that.id,_that.source,_that.headings,_that.lineCount,_that.byteSize,_that.topLevelBlockCount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DocumentId id,  String source,  List<HeadingRef> headings,  int lineCount,  int byteSize,  int topLevelBlockCount)?  $default,) {final _that = this;
switch (_that) {
case _Document() when $default != null:
return $default(_that.id,_that.source,_that.headings,_that.lineCount,_that.byteSize,_that.topLevelBlockCount);case _:
  return null;

}
}

}

/// @nodoc


class _Document implements Document {
  const _Document({required this.id, required this.source, required final  List<HeadingRef> headings, required this.lineCount, required this.byteSize, required this.topLevelBlockCount}): _headings = headings;
  

/// Stable identifier for this document (currently the file path).
@override final  DocumentId id;
/// Original markdown source exactly as read from disk, after UTF-8
/// decoding. Never mutated.
@override final  String source;
/// Headings in document order. Empty for documents without any.
 final  List<HeadingRef> _headings;
/// Headings in document order. Empty for documents without any.
@override List<HeadingRef> get headings {
  if (_headings is EqualUnmodifiableListView) return _headings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_headings);
}

/// Number of newline-terminated lines in [source]. Used for
/// display (e.g. "10k lines") and for the isolate-offload threshold.
@override final  int lineCount;
/// Byte length of the original file on disk, before UTF-8 decoding.
@override final  int byteSize;
/// Number of top-level markdown blocks the parser produced.
/// Used by the viewer to assign one `GlobalKey` per block and
/// by the TOC drawer + in-doc search to `Scrollable.ensureVisible`
/// the correct block without pixel measuring.
///
/// When the render layer's widget count disagrees with this
/// number the viewer falls back to approximate fraction-based
/// scrolling rather than crashing — a regression in
/// `markdown_widget`'s block count per render would silently
/// produce a degraded TOC, not a broken viewer.
@override final  int topLevelBlockCount;

/// Create a copy of Document
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentCopyWith<_Document> get copyWith => __$DocumentCopyWithImpl<_Document>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Document&&(identical(other.id, id) || other.id == id)&&(identical(other.source, source) || other.source == source)&&const DeepCollectionEquality().equals(other._headings, _headings)&&(identical(other.lineCount, lineCount) || other.lineCount == lineCount)&&(identical(other.byteSize, byteSize) || other.byteSize == byteSize)&&(identical(other.topLevelBlockCount, topLevelBlockCount) || other.topLevelBlockCount == topLevelBlockCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,source,const DeepCollectionEquality().hash(_headings),lineCount,byteSize,topLevelBlockCount);

@override
String toString() {
  return 'Document(id: $id, source: $source, headings: $headings, lineCount: $lineCount, byteSize: $byteSize, topLevelBlockCount: $topLevelBlockCount)';
}


}

/// @nodoc
abstract mixin class _$DocumentCopyWith<$Res> implements $DocumentCopyWith<$Res> {
  factory _$DocumentCopyWith(_Document value, $Res Function(_Document) _then) = __$DocumentCopyWithImpl;
@override @useResult
$Res call({
 DocumentId id, String source, List<HeadingRef> headings, int lineCount, int byteSize, int topLevelBlockCount
});




}
/// @nodoc
class __$DocumentCopyWithImpl<$Res>
    implements _$DocumentCopyWith<$Res> {
  __$DocumentCopyWithImpl(this._self, this._then);

  final _Document _self;
  final $Res Function(_Document) _then;

/// Create a copy of Document
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? source = null,Object? headings = null,Object? lineCount = null,Object? byteSize = null,Object? topLevelBlockCount = null,}) {
  return _then(_Document(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as DocumentId,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,headings: null == headings ? _self._headings : headings // ignore: cast_nullable_to_non_nullable
as List<HeadingRef>,lineCount: null == lineCount ? _self.lineCount : lineCount // ignore: cast_nullable_to_non_nullable
as int,byteSize: null == byteSize ? _self.byteSize : byteSize // ignore: cast_nullable_to_non_nullable
as int,topLevelBlockCount: null == topLevelBlockCount ? _self.topLevelBlockCount : topLevelBlockCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
