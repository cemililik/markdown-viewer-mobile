// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'synced_repo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SyncedRepo {

 int get id;/// Provider identifier, e.g. `'github'`.
 String get provider;/// Repository owner (user or organisation).
 String get owner;/// Repository name.
 String get repo;/// Branch, tag, or commit SHA that was synced.
 String get ref;/// Sub-path within the repo that was synced. Empty = root.
 String get subPath;/// Absolute path to the local mirror directory on this device.
 String get localRoot;/// When the last successful (or partial) sync completed.
 DateTime get lastSyncedAt;/// Number of files in the local mirror after the last sync.
 int get fileCount;/// Health of the last sync run.
 SyncStatus get status;
/// Create a copy of SyncedRepo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncedRepoCopyWith<SyncedRepo> get copyWith => _$SyncedRepoCopyWithImpl<SyncedRepo>(this as SyncedRepo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncedRepo&&(identical(other.id, id) || other.id == id)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.owner, owner) || other.owner == owner)&&(identical(other.repo, repo) || other.repo == repo)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.subPath, subPath) || other.subPath == subPath)&&(identical(other.localRoot, localRoot) || other.localRoot == localRoot)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.fileCount, fileCount) || other.fileCount == fileCount)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,id,provider,owner,repo,ref,subPath,localRoot,lastSyncedAt,fileCount,status);

@override
String toString() {
  return 'SyncedRepo(id: $id, provider: $provider, owner: $owner, repo: $repo, ref: $ref, subPath: $subPath, localRoot: $localRoot, lastSyncedAt: $lastSyncedAt, fileCount: $fileCount, status: $status)';
}


}

/// @nodoc
abstract mixin class $SyncedRepoCopyWith<$Res>  {
  factory $SyncedRepoCopyWith(SyncedRepo value, $Res Function(SyncedRepo) _then) = _$SyncedRepoCopyWithImpl;
@useResult
$Res call({
 int id, String provider, String owner, String repo, String ref, String subPath, String localRoot, DateTime lastSyncedAt, int fileCount, SyncStatus status
});




}
/// @nodoc
class _$SyncedRepoCopyWithImpl<$Res>
    implements $SyncedRepoCopyWith<$Res> {
  _$SyncedRepoCopyWithImpl(this._self, this._then);

  final SyncedRepo _self;
  final $Res Function(SyncedRepo) _then;

/// Create a copy of SyncedRepo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? provider = null,Object? owner = null,Object? repo = null,Object? ref = null,Object? subPath = null,Object? localRoot = null,Object? lastSyncedAt = null,Object? fileCount = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as String,repo: null == repo ? _self.repo : repo // ignore: cast_nullable_to_non_nullable
as String,ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,subPath: null == subPath ? _self.subPath : subPath // ignore: cast_nullable_to_non_nullable
as String,localRoot: null == localRoot ? _self.localRoot : localRoot // ignore: cast_nullable_to_non_nullable
as String,lastSyncedAt: null == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime,fileCount: null == fileCount ? _self.fileCount : fileCount // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncedRepo].
extension SyncedRepoPatterns on SyncedRepo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncedRepo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncedRepo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncedRepo value)  $default,){
final _that = this;
switch (_that) {
case _SyncedRepo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncedRepo value)?  $default,){
final _that = this;
switch (_that) {
case _SyncedRepo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String provider,  String owner,  String repo,  String ref,  String subPath,  String localRoot,  DateTime lastSyncedAt,  int fileCount,  SyncStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncedRepo() when $default != null:
return $default(_that.id,_that.provider,_that.owner,_that.repo,_that.ref,_that.subPath,_that.localRoot,_that.lastSyncedAt,_that.fileCount,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String provider,  String owner,  String repo,  String ref,  String subPath,  String localRoot,  DateTime lastSyncedAt,  int fileCount,  SyncStatus status)  $default,) {final _that = this;
switch (_that) {
case _SyncedRepo():
return $default(_that.id,_that.provider,_that.owner,_that.repo,_that.ref,_that.subPath,_that.localRoot,_that.lastSyncedAt,_that.fileCount,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String provider,  String owner,  String repo,  String ref,  String subPath,  String localRoot,  DateTime lastSyncedAt,  int fileCount,  SyncStatus status)?  $default,) {final _that = this;
switch (_that) {
case _SyncedRepo() when $default != null:
return $default(_that.id,_that.provider,_that.owner,_that.repo,_that.ref,_that.subPath,_that.localRoot,_that.lastSyncedAt,_that.fileCount,_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _SyncedRepo extends SyncedRepo {
  const _SyncedRepo({required this.id, required this.provider, required this.owner, required this.repo, required this.ref, this.subPath = '', required this.localRoot, required this.lastSyncedAt, this.fileCount = 0, this.status = SyncStatus.ok}): super._();
  

@override final  int id;
/// Provider identifier, e.g. `'github'`.
@override final  String provider;
/// Repository owner (user or organisation).
@override final  String owner;
/// Repository name.
@override final  String repo;
/// Branch, tag, or commit SHA that was synced.
@override final  String ref;
/// Sub-path within the repo that was synced. Empty = root.
@override@JsonKey() final  String subPath;
/// Absolute path to the local mirror directory on this device.
@override final  String localRoot;
/// When the last successful (or partial) sync completed.
@override final  DateTime lastSyncedAt;
/// Number of files in the local mirror after the last sync.
@override@JsonKey() final  int fileCount;
/// Health of the last sync run.
@override@JsonKey() final  SyncStatus status;

/// Create a copy of SyncedRepo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncedRepoCopyWith<_SyncedRepo> get copyWith => __$SyncedRepoCopyWithImpl<_SyncedRepo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncedRepo&&(identical(other.id, id) || other.id == id)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.owner, owner) || other.owner == owner)&&(identical(other.repo, repo) || other.repo == repo)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.subPath, subPath) || other.subPath == subPath)&&(identical(other.localRoot, localRoot) || other.localRoot == localRoot)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.fileCount, fileCount) || other.fileCount == fileCount)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,id,provider,owner,repo,ref,subPath,localRoot,lastSyncedAt,fileCount,status);

@override
String toString() {
  return 'SyncedRepo(id: $id, provider: $provider, owner: $owner, repo: $repo, ref: $ref, subPath: $subPath, localRoot: $localRoot, lastSyncedAt: $lastSyncedAt, fileCount: $fileCount, status: $status)';
}


}

/// @nodoc
abstract mixin class _$SyncedRepoCopyWith<$Res> implements $SyncedRepoCopyWith<$Res> {
  factory _$SyncedRepoCopyWith(_SyncedRepo value, $Res Function(_SyncedRepo) _then) = __$SyncedRepoCopyWithImpl;
@override @useResult
$Res call({
 int id, String provider, String owner, String repo, String ref, String subPath, String localRoot, DateTime lastSyncedAt, int fileCount, SyncStatus status
});




}
/// @nodoc
class __$SyncedRepoCopyWithImpl<$Res>
    implements _$SyncedRepoCopyWith<$Res> {
  __$SyncedRepoCopyWithImpl(this._self, this._then);

  final _SyncedRepo _self;
  final $Res Function(_SyncedRepo) _then;

/// Create a copy of SyncedRepo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? provider = null,Object? owner = null,Object? repo = null,Object? ref = null,Object? subPath = null,Object? localRoot = null,Object? lastSyncedAt = null,Object? fileCount = null,Object? status = null,}) {
  return _then(_SyncedRepo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as String,repo: null == repo ? _self.repo : repo // ignore: cast_nullable_to_non_nullable
as String,ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,subPath: null == subPath ? _self.subPath : subPath // ignore: cast_nullable_to_non_nullable
as String,localRoot: null == localRoot ? _self.localRoot : localRoot // ignore: cast_nullable_to_non_nullable
as String,lastSyncedAt: null == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime,fileCount: null == fileCount ? _self.fileCount : fileCount // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncStatus,
  ));
}


}

// dart format on
