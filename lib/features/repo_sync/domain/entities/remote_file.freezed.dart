// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'remote_file.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RemoteFile {

/// Path relative to the repository root, e.g. `docs/api/ref.md`.
 String get path;/// Git blob SHA used for change detection on re-sync.
 String get sha;/// File size in bytes (0 when not provided by the API).
 int get size;/// Direct download URL for the raw file bytes.
 String get rawUrl;
/// Create a copy of RemoteFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteFileCopyWith<RemoteFile> get copyWith => _$RemoteFileCopyWithImpl<RemoteFile>(this as RemoteFile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteFile&&(identical(other.path, path) || other.path == path)&&(identical(other.sha, sha) || other.sha == sha)&&(identical(other.size, size) || other.size == size)&&(identical(other.rawUrl, rawUrl) || other.rawUrl == rawUrl));
}


@override
int get hashCode => Object.hash(runtimeType,path,sha,size,rawUrl);

@override
String toString() {
  return 'RemoteFile(path: $path, sha: $sha, size: $size, rawUrl: $rawUrl)';
}


}

/// @nodoc
abstract mixin class $RemoteFileCopyWith<$Res>  {
  factory $RemoteFileCopyWith(RemoteFile value, $Res Function(RemoteFile) _then) = _$RemoteFileCopyWithImpl;
@useResult
$Res call({
 String path, String sha, int size, String rawUrl
});




}
/// @nodoc
class _$RemoteFileCopyWithImpl<$Res>
    implements $RemoteFileCopyWith<$Res> {
  _$RemoteFileCopyWithImpl(this._self, this._then);

  final RemoteFile _self;
  final $Res Function(RemoteFile) _then;

/// Create a copy of RemoteFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? sha = null,Object? size = null,Object? rawUrl = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sha: null == sha ? _self.sha : sha // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,rawUrl: null == rawUrl ? _self.rawUrl : rawUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RemoteFile].
extension RemoteFilePatterns on RemoteFile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RemoteFile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RemoteFile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RemoteFile value)  $default,){
final _that = this;
switch (_that) {
case _RemoteFile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RemoteFile value)?  $default,){
final _that = this;
switch (_that) {
case _RemoteFile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String sha,  int size,  String rawUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RemoteFile() when $default != null:
return $default(_that.path,_that.sha,_that.size,_that.rawUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String sha,  int size,  String rawUrl)  $default,) {final _that = this;
switch (_that) {
case _RemoteFile():
return $default(_that.path,_that.sha,_that.size,_that.rawUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String sha,  int size,  String rawUrl)?  $default,) {final _that = this;
switch (_that) {
case _RemoteFile() when $default != null:
return $default(_that.path,_that.sha,_that.size,_that.rawUrl);case _:
  return null;

}
}

}

/// @nodoc


class _RemoteFile implements RemoteFile {
  const _RemoteFile({required this.path, required this.sha, this.size = 0, required this.rawUrl});
  

/// Path relative to the repository root, e.g. `docs/api/ref.md`.
@override final  String path;
/// Git blob SHA used for change detection on re-sync.
@override final  String sha;
/// File size in bytes (0 when not provided by the API).
@override@JsonKey() final  int size;
/// Direct download URL for the raw file bytes.
@override final  String rawUrl;

/// Create a copy of RemoteFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RemoteFileCopyWith<_RemoteFile> get copyWith => __$RemoteFileCopyWithImpl<_RemoteFile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RemoteFile&&(identical(other.path, path) || other.path == path)&&(identical(other.sha, sha) || other.sha == sha)&&(identical(other.size, size) || other.size == size)&&(identical(other.rawUrl, rawUrl) || other.rawUrl == rawUrl));
}


@override
int get hashCode => Object.hash(runtimeType,path,sha,size,rawUrl);

@override
String toString() {
  return 'RemoteFile(path: $path, sha: $sha, size: $size, rawUrl: $rawUrl)';
}


}

/// @nodoc
abstract mixin class _$RemoteFileCopyWith<$Res> implements $RemoteFileCopyWith<$Res> {
  factory _$RemoteFileCopyWith(_RemoteFile value, $Res Function(_RemoteFile) _then) = __$RemoteFileCopyWithImpl;
@override @useResult
$Res call({
 String path, String sha, int size, String rawUrl
});




}
/// @nodoc
class __$RemoteFileCopyWithImpl<$Res>
    implements _$RemoteFileCopyWith<$Res> {
  __$RemoteFileCopyWithImpl(this._self, this._then);

  final _RemoteFile _self;
  final $Res Function(_RemoteFile) _then;

/// Create a copy of RemoteFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? sha = null,Object? size = null,Object? rawUrl = null,}) {
  return _then(_RemoteFile(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sha: null == sha ? _self.sha : sha // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,rawUrl: null == rawUrl ? _self.rawUrl : rawUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
