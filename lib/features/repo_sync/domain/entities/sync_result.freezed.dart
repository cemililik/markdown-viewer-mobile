// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SyncResult {

/// Total usable files after this sync (downloaded + skipped via SHA match).
 int get syncedCount;/// Files actually fetched from the network on this run.
///
/// On a first sync this equals [syncedCount]. On subsequent syncs the
/// difference [syncedCount] − [downloadedCount] reveals unchanged files
/// that were skipped because their remote SHA matched the local copy.
 int get downloadedCount;/// Files that could not be downloaded (network errors, 404s).
 int get failedCount;/// The persisted [SyncedRepo] record as written to the database.
 SyncedRepo get repo;
/// Create a copy of SyncResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncResultCopyWith<SyncResult> get copyWith => _$SyncResultCopyWithImpl<SyncResult>(this as SyncResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncResult&&(identical(other.syncedCount, syncedCount) || other.syncedCount == syncedCount)&&(identical(other.downloadedCount, downloadedCount) || other.downloadedCount == downloadedCount)&&(identical(other.failedCount, failedCount) || other.failedCount == failedCount)&&(identical(other.repo, repo) || other.repo == repo));
}


@override
int get hashCode => Object.hash(runtimeType,syncedCount,downloadedCount,failedCount,repo);

@override
String toString() {
  return 'SyncResult(syncedCount: $syncedCount, downloadedCount: $downloadedCount, failedCount: $failedCount, repo: $repo)';
}


}

/// @nodoc
abstract mixin class $SyncResultCopyWith<$Res>  {
  factory $SyncResultCopyWith(SyncResult value, $Res Function(SyncResult) _then) = _$SyncResultCopyWithImpl;
@useResult
$Res call({
 int syncedCount, int downloadedCount, int failedCount, SyncedRepo repo
});


$SyncedRepoCopyWith<$Res> get repo;

}
/// @nodoc
class _$SyncResultCopyWithImpl<$Res>
    implements $SyncResultCopyWith<$Res> {
  _$SyncResultCopyWithImpl(this._self, this._then);

  final SyncResult _self;
  final $Res Function(SyncResult) _then;

/// Create a copy of SyncResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? syncedCount = null,Object? downloadedCount = null,Object? failedCount = null,Object? repo = null,}) {
  return _then(_self.copyWith(
syncedCount: null == syncedCount ? _self.syncedCount : syncedCount // ignore: cast_nullable_to_non_nullable
as int,downloadedCount: null == downloadedCount ? _self.downloadedCount : downloadedCount // ignore: cast_nullable_to_non_nullable
as int,failedCount: null == failedCount ? _self.failedCount : failedCount // ignore: cast_nullable_to_non_nullable
as int,repo: null == repo ? _self.repo : repo // ignore: cast_nullable_to_non_nullable
as SyncedRepo,
  ));
}
/// Create a copy of SyncResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SyncedRepoCopyWith<$Res> get repo {
  
  return $SyncedRepoCopyWith<$Res>(_self.repo, (value) {
    return _then(_self.copyWith(repo: value));
  });
}
}


/// Adds pattern-matching-related methods to [SyncResult].
extension SyncResultPatterns on SyncResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncResult value)  $default,){
final _that = this;
switch (_that) {
case _SyncResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncResult value)?  $default,){
final _that = this;
switch (_that) {
case _SyncResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int syncedCount,  int downloadedCount,  int failedCount,  SyncedRepo repo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncResult() when $default != null:
return $default(_that.syncedCount,_that.downloadedCount,_that.failedCount,_that.repo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int syncedCount,  int downloadedCount,  int failedCount,  SyncedRepo repo)  $default,) {final _that = this;
switch (_that) {
case _SyncResult():
return $default(_that.syncedCount,_that.downloadedCount,_that.failedCount,_that.repo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int syncedCount,  int downloadedCount,  int failedCount,  SyncedRepo repo)?  $default,) {final _that = this;
switch (_that) {
case _SyncResult() when $default != null:
return $default(_that.syncedCount,_that.downloadedCount,_that.failedCount,_that.repo);case _:
  return null;

}
}

}

/// @nodoc


class _SyncResult extends SyncResult {
  const _SyncResult({required this.syncedCount, required this.downloadedCount, this.failedCount = 0, required this.repo}): super._();
  

/// Total usable files after this sync (downloaded + skipped via SHA match).
@override final  int syncedCount;
/// Files actually fetched from the network on this run.
///
/// On a first sync this equals [syncedCount]. On subsequent syncs the
/// difference [syncedCount] − [downloadedCount] reveals unchanged files
/// that were skipped because their remote SHA matched the local copy.
@override final  int downloadedCount;
/// Files that could not be downloaded (network errors, 404s).
@override@JsonKey() final  int failedCount;
/// The persisted [SyncedRepo] record as written to the database.
@override final  SyncedRepo repo;

/// Create a copy of SyncResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncResultCopyWith<_SyncResult> get copyWith => __$SyncResultCopyWithImpl<_SyncResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncResult&&(identical(other.syncedCount, syncedCount) || other.syncedCount == syncedCount)&&(identical(other.downloadedCount, downloadedCount) || other.downloadedCount == downloadedCount)&&(identical(other.failedCount, failedCount) || other.failedCount == failedCount)&&(identical(other.repo, repo) || other.repo == repo));
}


@override
int get hashCode => Object.hash(runtimeType,syncedCount,downloadedCount,failedCount,repo);

@override
String toString() {
  return 'SyncResult(syncedCount: $syncedCount, downloadedCount: $downloadedCount, failedCount: $failedCount, repo: $repo)';
}


}

/// @nodoc
abstract mixin class _$SyncResultCopyWith<$Res> implements $SyncResultCopyWith<$Res> {
  factory _$SyncResultCopyWith(_SyncResult value, $Res Function(_SyncResult) _then) = __$SyncResultCopyWithImpl;
@override @useResult
$Res call({
 int syncedCount, int downloadedCount, int failedCount, SyncedRepo repo
});


@override $SyncedRepoCopyWith<$Res> get repo;

}
/// @nodoc
class __$SyncResultCopyWithImpl<$Res>
    implements _$SyncResultCopyWith<$Res> {
  __$SyncResultCopyWithImpl(this._self, this._then);

  final _SyncResult _self;
  final $Res Function(_SyncResult) _then;

/// Create a copy of SyncResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? syncedCount = null,Object? downloadedCount = null,Object? failedCount = null,Object? repo = null,}) {
  return _then(_SyncResult(
syncedCount: null == syncedCount ? _self.syncedCount : syncedCount // ignore: cast_nullable_to_non_nullable
as int,downloadedCount: null == downloadedCount ? _self.downloadedCount : downloadedCount // ignore: cast_nullable_to_non_nullable
as int,failedCount: null == failedCount ? _self.failedCount : failedCount // ignore: cast_nullable_to_non_nullable
as int,repo: null == repo ? _self.repo : repo // ignore: cast_nullable_to_non_nullable
as SyncedRepo,
  ));
}

/// Create a copy of SyncResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SyncedRepoCopyWith<$Res> get repo {
  
  return $SyncedRepoCopyWith<$Res>(_self.repo, (value) {
    return _then(_self.copyWith(repo: value));
  });
}
}

// dart format on
