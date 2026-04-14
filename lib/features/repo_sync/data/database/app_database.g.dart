// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SyncedReposTable extends SyncedRepos
    with TableInfo<$SyncedReposTable, SyncedRepoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncedReposTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repoMeta = const VerificationMeta('repo');
  @override
  late final GeneratedColumn<String> repo = GeneratedColumn<String>(
    'repo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refMeta = const VerificationMeta('ref');
  @override
  late final GeneratedColumn<String> ref = GeneratedColumn<String>(
    'ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subPathMeta = const VerificationMeta(
    'subPath',
  );
  @override
  late final GeneratedColumn<String> subPath = GeneratedColumn<String>(
    'sub_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _localRootMeta = const VerificationMeta(
    'localRoot',
  );
  @override
  late final GeneratedColumn<String> localRoot = GeneratedColumn<String>(
    'local_root',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileCountMeta = const VerificationMeta(
    'fileCount',
  );
  @override
  late final GeneratedColumn<int> fileCount = GeneratedColumn<int>(
    'file_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ok'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    owner,
    repo,
    ref,
    subPath,
    localRoot,
    lastSyncedAt,
    fileCount,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'synced_repos';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncedRepoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('repo')) {
      context.handle(
        _repoMeta,
        repo.isAcceptableOrUnknown(data['repo']!, _repoMeta),
      );
    } else if (isInserting) {
      context.missing(_repoMeta);
    }
    if (data.containsKey('ref')) {
      context.handle(
        _refMeta,
        ref.isAcceptableOrUnknown(data['ref']!, _refMeta),
      );
    } else if (isInserting) {
      context.missing(_refMeta);
    }
    if (data.containsKey('sub_path')) {
      context.handle(
        _subPathMeta,
        subPath.isAcceptableOrUnknown(data['sub_path']!, _subPathMeta),
      );
    }
    if (data.containsKey('local_root')) {
      context.handle(
        _localRootMeta,
        localRoot.isAcceptableOrUnknown(data['local_root']!, _localRootMeta),
      );
    } else if (isInserting) {
      context.missing(_localRootMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    if (data.containsKey('file_count')) {
      context.handle(
        _fileCountMeta,
        fileCount.isAcceptableOrUnknown(data['file_count']!, _fileCountMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncedRepoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncedRepoRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      provider:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}provider'],
          )!,
      owner:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}owner'],
          )!,
      repo:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}repo'],
          )!,
      ref:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}ref'],
          )!,
      subPath:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}sub_path'],
          )!,
      localRoot:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}local_root'],
          )!,
      lastSyncedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}last_synced_at'],
          )!,
      fileCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}file_count'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
    );
  }

  @override
  $SyncedReposTable createAlias(String alias) {
    return $SyncedReposTable(attachedDatabase, alias);
  }
}

class SyncedRepoRow extends DataClass implements Insertable<SyncedRepoRow> {
  final int id;
  final String provider;
  final String owner;
  final String repo;
  final String ref;
  final String subPath;
  final String localRoot;

  /// Milliseconds since epoch (UTC).
  final int lastSyncedAt;
  final int fileCount;

  /// One of `'ok'`, `'partial'`, `'failed'`.
  final String status;
  const SyncedRepoRow({
    required this.id,
    required this.provider,
    required this.owner,
    required this.repo,
    required this.ref,
    required this.subPath,
    required this.localRoot,
    required this.lastSyncedAt,
    required this.fileCount,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider'] = Variable<String>(provider);
    map['owner'] = Variable<String>(owner);
    map['repo'] = Variable<String>(repo);
    map['ref'] = Variable<String>(ref);
    map['sub_path'] = Variable<String>(subPath);
    map['local_root'] = Variable<String>(localRoot);
    map['last_synced_at'] = Variable<int>(lastSyncedAt);
    map['file_count'] = Variable<int>(fileCount);
    map['status'] = Variable<String>(status);
    return map;
  }

  SyncedReposCompanion toCompanion(bool nullToAbsent) {
    return SyncedReposCompanion(
      id: Value(id),
      provider: Value(provider),
      owner: Value(owner),
      repo: Value(repo),
      ref: Value(ref),
      subPath: Value(subPath),
      localRoot: Value(localRoot),
      lastSyncedAt: Value(lastSyncedAt),
      fileCount: Value(fileCount),
      status: Value(status),
    );
  }

  factory SyncedRepoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncedRepoRow(
      id: serializer.fromJson<int>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      owner: serializer.fromJson<String>(json['owner']),
      repo: serializer.fromJson<String>(json['repo']),
      ref: serializer.fromJson<String>(json['ref']),
      subPath: serializer.fromJson<String>(json['subPath']),
      localRoot: serializer.fromJson<String>(json['localRoot']),
      lastSyncedAt: serializer.fromJson<int>(json['lastSyncedAt']),
      fileCount: serializer.fromJson<int>(json['fileCount']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'provider': serializer.toJson<String>(provider),
      'owner': serializer.toJson<String>(owner),
      'repo': serializer.toJson<String>(repo),
      'ref': serializer.toJson<String>(ref),
      'subPath': serializer.toJson<String>(subPath),
      'localRoot': serializer.toJson<String>(localRoot),
      'lastSyncedAt': serializer.toJson<int>(lastSyncedAt),
      'fileCount': serializer.toJson<int>(fileCount),
      'status': serializer.toJson<String>(status),
    };
  }

  SyncedRepoRow copyWith({
    int? id,
    String? provider,
    String? owner,
    String? repo,
    String? ref,
    String? subPath,
    String? localRoot,
    int? lastSyncedAt,
    int? fileCount,
    String? status,
  }) => SyncedRepoRow(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    owner: owner ?? this.owner,
    repo: repo ?? this.repo,
    ref: ref ?? this.ref,
    subPath: subPath ?? this.subPath,
    localRoot: localRoot ?? this.localRoot,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    fileCount: fileCount ?? this.fileCount,
    status: status ?? this.status,
  );
  SyncedRepoRow copyWithCompanion(SyncedReposCompanion data) {
    return SyncedRepoRow(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      owner: data.owner.present ? data.owner.value : this.owner,
      repo: data.repo.present ? data.repo.value : this.repo,
      ref: data.ref.present ? data.ref.value : this.ref,
      subPath: data.subPath.present ? data.subPath.value : this.subPath,
      localRoot: data.localRoot.present ? data.localRoot.value : this.localRoot,
      lastSyncedAt:
          data.lastSyncedAt.present
              ? data.lastSyncedAt.value
              : this.lastSyncedAt,
      fileCount: data.fileCount.present ? data.fileCount.value : this.fileCount,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncedRepoRow(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('owner: $owner, ')
          ..write('repo: $repo, ')
          ..write('ref: $ref, ')
          ..write('subPath: $subPath, ')
          ..write('localRoot: $localRoot, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('fileCount: $fileCount, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    owner,
    repo,
    ref,
    subPath,
    localRoot,
    lastSyncedAt,
    fileCount,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncedRepoRow &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.owner == this.owner &&
          other.repo == this.repo &&
          other.ref == this.ref &&
          other.subPath == this.subPath &&
          other.localRoot == this.localRoot &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.fileCount == this.fileCount &&
          other.status == this.status);
}

class SyncedReposCompanion extends UpdateCompanion<SyncedRepoRow> {
  final Value<int> id;
  final Value<String> provider;
  final Value<String> owner;
  final Value<String> repo;
  final Value<String> ref;
  final Value<String> subPath;
  final Value<String> localRoot;
  final Value<int> lastSyncedAt;
  final Value<int> fileCount;
  final Value<String> status;
  const SyncedReposCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.owner = const Value.absent(),
    this.repo = const Value.absent(),
    this.ref = const Value.absent(),
    this.subPath = const Value.absent(),
    this.localRoot = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.fileCount = const Value.absent(),
    this.status = const Value.absent(),
  });
  SyncedReposCompanion.insert({
    this.id = const Value.absent(),
    required String provider,
    required String owner,
    required String repo,
    required String ref,
    this.subPath = const Value.absent(),
    required String localRoot,
    required int lastSyncedAt,
    this.fileCount = const Value.absent(),
    this.status = const Value.absent(),
  }) : provider = Value(provider),
       owner = Value(owner),
       repo = Value(repo),
       ref = Value(ref),
       localRoot = Value(localRoot),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<SyncedRepoRow> custom({
    Expression<int>? id,
    Expression<String>? provider,
    Expression<String>? owner,
    Expression<String>? repo,
    Expression<String>? ref,
    Expression<String>? subPath,
    Expression<String>? localRoot,
    Expression<int>? lastSyncedAt,
    Expression<int>? fileCount,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (owner != null) 'owner': owner,
      if (repo != null) 'repo': repo,
      if (ref != null) 'ref': ref,
      if (subPath != null) 'sub_path': subPath,
      if (localRoot != null) 'local_root': localRoot,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (fileCount != null) 'file_count': fileCount,
      if (status != null) 'status': status,
    });
  }

  SyncedReposCompanion copyWith({
    Value<int>? id,
    Value<String>? provider,
    Value<String>? owner,
    Value<String>? repo,
    Value<String>? ref,
    Value<String>? subPath,
    Value<String>? localRoot,
    Value<int>? lastSyncedAt,
    Value<int>? fileCount,
    Value<String>? status,
  }) {
    return SyncedReposCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      ref: ref ?? this.ref,
      subPath: subPath ?? this.subPath,
      localRoot: localRoot ?? this.localRoot,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      fileCount: fileCount ?? this.fileCount,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (repo.present) {
      map['repo'] = Variable<String>(repo.value);
    }
    if (ref.present) {
      map['ref'] = Variable<String>(ref.value);
    }
    if (subPath.present) {
      map['sub_path'] = Variable<String>(subPath.value);
    }
    if (localRoot.present) {
      map['local_root'] = Variable<String>(localRoot.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (fileCount.present) {
      map['file_count'] = Variable<int>(fileCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncedReposCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('owner: $owner, ')
          ..write('repo: $repo, ')
          ..write('ref: $ref, ')
          ..write('subPath: $subPath, ')
          ..write('localRoot: $localRoot, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('fileCount: $fileCount, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $SyncedFilesTable extends SyncedFiles
    with TableInfo<$SyncedFilesTable, SyncedFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncedFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _repoIdMeta = const VerificationMeta('repoId');
  @override
  late final GeneratedColumn<int> repoId = GeneratedColumn<int>(
    'repo_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES synced_repos (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remotePathMeta = const VerificationMeta(
    'remotePath',
  );
  @override
  late final GeneratedColumn<String> remotePath = GeneratedColumn<String>(
    'remote_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shaMeta = const VerificationMeta('sha');
  @override
  late final GeneratedColumn<String> sha = GeneratedColumn<String>(
    'sha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repoId,
    remotePath,
    localPath,
    sha,
    size,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'synced_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncedFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('repo_id')) {
      context.handle(
        _repoIdMeta,
        repoId.isAcceptableOrUnknown(data['repo_id']!, _repoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_repoIdMeta);
    }
    if (data.containsKey('remote_path')) {
      context.handle(
        _remotePathMeta,
        remotePath.isAcceptableOrUnknown(data['remote_path']!, _remotePathMeta),
      );
    } else if (isInserting) {
      context.missing(_remotePathMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('sha')) {
      context.handle(
        _shaMeta,
        sha.isAcceptableOrUnknown(data['sha']!, _shaMeta),
      );
    } else if (isInserting) {
      context.missing(_shaMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncedFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncedFileRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      repoId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}repo_id'],
          )!,
      remotePath:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}remote_path'],
          )!,
      localPath:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}local_path'],
          )!,
      sha:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}sha'],
          )!,
      size:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}size'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
    );
  }

  @override
  $SyncedFilesTable createAlias(String alias) {
    return $SyncedFilesTable(attachedDatabase, alias);
  }
}

class SyncedFileRow extends DataClass implements Insertable<SyncedFileRow> {
  final int id;
  final int repoId;
  final String remotePath;
  final String localPath;

  /// Git blob SHA — used for change-detection on re-sync.
  final String sha;
  final int size;

  /// One of `'synced'`, `'failed'`, `'pending'`.
  final String status;
  const SyncedFileRow({
    required this.id,
    required this.repoId,
    required this.remotePath,
    required this.localPath,
    required this.sha,
    required this.size,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['repo_id'] = Variable<int>(repoId);
    map['remote_path'] = Variable<String>(remotePath);
    map['local_path'] = Variable<String>(localPath);
    map['sha'] = Variable<String>(sha);
    map['size'] = Variable<int>(size);
    map['status'] = Variable<String>(status);
    return map;
  }

  SyncedFilesCompanion toCompanion(bool nullToAbsent) {
    return SyncedFilesCompanion(
      id: Value(id),
      repoId: Value(repoId),
      remotePath: Value(remotePath),
      localPath: Value(localPath),
      sha: Value(sha),
      size: Value(size),
      status: Value(status),
    );
  }

  factory SyncedFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncedFileRow(
      id: serializer.fromJson<int>(json['id']),
      repoId: serializer.fromJson<int>(json['repoId']),
      remotePath: serializer.fromJson<String>(json['remotePath']),
      localPath: serializer.fromJson<String>(json['localPath']),
      sha: serializer.fromJson<String>(json['sha']),
      size: serializer.fromJson<int>(json['size']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repoId': serializer.toJson<int>(repoId),
      'remotePath': serializer.toJson<String>(remotePath),
      'localPath': serializer.toJson<String>(localPath),
      'sha': serializer.toJson<String>(sha),
      'size': serializer.toJson<int>(size),
      'status': serializer.toJson<String>(status),
    };
  }

  SyncedFileRow copyWith({
    int? id,
    int? repoId,
    String? remotePath,
    String? localPath,
    String? sha,
    int? size,
    String? status,
  }) => SyncedFileRow(
    id: id ?? this.id,
    repoId: repoId ?? this.repoId,
    remotePath: remotePath ?? this.remotePath,
    localPath: localPath ?? this.localPath,
    sha: sha ?? this.sha,
    size: size ?? this.size,
    status: status ?? this.status,
  );
  SyncedFileRow copyWithCompanion(SyncedFilesCompanion data) {
    return SyncedFileRow(
      id: data.id.present ? data.id.value : this.id,
      repoId: data.repoId.present ? data.repoId.value : this.repoId,
      remotePath:
          data.remotePath.present ? data.remotePath.value : this.remotePath,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      sha: data.sha.present ? data.sha.value : this.sha,
      size: data.size.present ? data.size.value : this.size,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncedFileRow(')
          ..write('id: $id, ')
          ..write('repoId: $repoId, ')
          ..write('remotePath: $remotePath, ')
          ..write('localPath: $localPath, ')
          ..write('sha: $sha, ')
          ..write('size: $size, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, repoId, remotePath, localPath, sha, size, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncedFileRow &&
          other.id == this.id &&
          other.repoId == this.repoId &&
          other.remotePath == this.remotePath &&
          other.localPath == this.localPath &&
          other.sha == this.sha &&
          other.size == this.size &&
          other.status == this.status);
}

class SyncedFilesCompanion extends UpdateCompanion<SyncedFileRow> {
  final Value<int> id;
  final Value<int> repoId;
  final Value<String> remotePath;
  final Value<String> localPath;
  final Value<String> sha;
  final Value<int> size;
  final Value<String> status;
  const SyncedFilesCompanion({
    this.id = const Value.absent(),
    this.repoId = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sha = const Value.absent(),
    this.size = const Value.absent(),
    this.status = const Value.absent(),
  });
  SyncedFilesCompanion.insert({
    this.id = const Value.absent(),
    required int repoId,
    required String remotePath,
    required String localPath,
    required String sha,
    this.size = const Value.absent(),
    this.status = const Value.absent(),
  }) : repoId = Value(repoId),
       remotePath = Value(remotePath),
       localPath = Value(localPath),
       sha = Value(sha);
  static Insertable<SyncedFileRow> custom({
    Expression<int>? id,
    Expression<int>? repoId,
    Expression<String>? remotePath,
    Expression<String>? localPath,
    Expression<String>? sha,
    Expression<int>? size,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repoId != null) 'repo_id': repoId,
      if (remotePath != null) 'remote_path': remotePath,
      if (localPath != null) 'local_path': localPath,
      if (sha != null) 'sha': sha,
      if (size != null) 'size': size,
      if (status != null) 'status': status,
    });
  }

  SyncedFilesCompanion copyWith({
    Value<int>? id,
    Value<int>? repoId,
    Value<String>? remotePath,
    Value<String>? localPath,
    Value<String>? sha,
    Value<int>? size,
    Value<String>? status,
  }) {
    return SyncedFilesCompanion(
      id: id ?? this.id,
      repoId: repoId ?? this.repoId,
      remotePath: remotePath ?? this.remotePath,
      localPath: localPath ?? this.localPath,
      sha: sha ?? this.sha,
      size: size ?? this.size,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repoId.present) {
      map['repo_id'] = Variable<int>(repoId.value);
    }
    if (remotePath.present) {
      map['remote_path'] = Variable<String>(remotePath.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (sha.present) {
      map['sha'] = Variable<String>(sha.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncedFilesCompanion(')
          ..write('id: $id, ')
          ..write('repoId: $repoId, ')
          ..write('remotePath: $remotePath, ')
          ..write('localPath: $localPath, ')
          ..write('sha: $sha, ')
          ..write('size: $size, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SyncedReposTable syncedRepos = $SyncedReposTable(this);
  late final $SyncedFilesTable syncedFiles = $SyncedFilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncedRepos,
    syncedFiles,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'synced_repos',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('synced_files', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SyncedReposTableCreateCompanionBuilder =
    SyncedReposCompanion Function({
      Value<int> id,
      required String provider,
      required String owner,
      required String repo,
      required String ref,
      Value<String> subPath,
      required String localRoot,
      required int lastSyncedAt,
      Value<int> fileCount,
      Value<String> status,
    });
typedef $$SyncedReposTableUpdateCompanionBuilder =
    SyncedReposCompanion Function({
      Value<int> id,
      Value<String> provider,
      Value<String> owner,
      Value<String> repo,
      Value<String> ref,
      Value<String> subPath,
      Value<String> localRoot,
      Value<int> lastSyncedAt,
      Value<int> fileCount,
      Value<String> status,
    });

final class $$SyncedReposTableReferences
    extends BaseReferences<_$AppDatabase, $SyncedReposTable, SyncedRepoRow> {
  $$SyncedReposTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SyncedFilesTable, List<SyncedFileRow>>
  _syncedFilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.syncedFiles,
    aliasName: $_aliasNameGenerator(db.syncedRepos.id, db.syncedFiles.repoId),
  );

  $$SyncedFilesTableProcessedTableManager get syncedFilesRefs {
    final manager = $$SyncedFilesTableTableManager(
      $_db,
      $_db.syncedFiles,
    ).filter((f) => f.repoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncedFilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SyncedReposTableFilterComposer
    extends Composer<_$AppDatabase, $SyncedReposTable> {
  $$SyncedReposTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repo => $composableBuilder(
    column: $table.repo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subPath => $composableBuilder(
    column: $table.subPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localRoot => $composableBuilder(
    column: $table.localRoot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileCount => $composableBuilder(
    column: $table.fileCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> syncedFilesRefs(
    Expression<bool> Function($$SyncedFilesTableFilterComposer f) f,
  ) {
    final $$SyncedFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncedFiles,
      getReferencedColumn: (t) => t.repoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncedFilesTableFilterComposer(
            $db: $db,
            $table: $db.syncedFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SyncedReposTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncedReposTable> {
  $$SyncedReposTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repo => $composableBuilder(
    column: $table.repo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subPath => $composableBuilder(
    column: $table.subPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localRoot => $composableBuilder(
    column: $table.localRoot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileCount => $composableBuilder(
    column: $table.fileCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncedReposTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncedReposTable> {
  $$SyncedReposTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get repo =>
      $composableBuilder(column: $table.repo, builder: (column) => column);

  GeneratedColumn<String> get ref =>
      $composableBuilder(column: $table.ref, builder: (column) => column);

  GeneratedColumn<String> get subPath =>
      $composableBuilder(column: $table.subPath, builder: (column) => column);

  GeneratedColumn<String> get localRoot =>
      $composableBuilder(column: $table.localRoot, builder: (column) => column);

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileCount =>
      $composableBuilder(column: $table.fileCount, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  Expression<T> syncedFilesRefs<T extends Object>(
    Expression<T> Function($$SyncedFilesTableAnnotationComposer a) f,
  ) {
    final $$SyncedFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncedFiles,
      getReferencedColumn: (t) => t.repoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncedFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.syncedFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SyncedReposTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncedReposTable,
          SyncedRepoRow,
          $$SyncedReposTableFilterComposer,
          $$SyncedReposTableOrderingComposer,
          $$SyncedReposTableAnnotationComposer,
          $$SyncedReposTableCreateCompanionBuilder,
          $$SyncedReposTableUpdateCompanionBuilder,
          (SyncedRepoRow, $$SyncedReposTableReferences),
          SyncedRepoRow,
          PrefetchHooks Function({bool syncedFilesRefs})
        > {
  $$SyncedReposTableTableManager(_$AppDatabase db, $SyncedReposTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SyncedReposTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SyncedReposTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$SyncedReposTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> owner = const Value.absent(),
                Value<String> repo = const Value.absent(),
                Value<String> ref = const Value.absent(),
                Value<String> subPath = const Value.absent(),
                Value<String> localRoot = const Value.absent(),
                Value<int> lastSyncedAt = const Value.absent(),
                Value<int> fileCount = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => SyncedReposCompanion(
                id: id,
                provider: provider,
                owner: owner,
                repo: repo,
                ref: ref,
                subPath: subPath,
                localRoot: localRoot,
                lastSyncedAt: lastSyncedAt,
                fileCount: fileCount,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String provider,
                required String owner,
                required String repo,
                required String ref,
                Value<String> subPath = const Value.absent(),
                required String localRoot,
                required int lastSyncedAt,
                Value<int> fileCount = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => SyncedReposCompanion.insert(
                id: id,
                provider: provider,
                owner: owner,
                repo: repo,
                ref: ref,
                subPath: subPath,
                localRoot: localRoot,
                lastSyncedAt: lastSyncedAt,
                fileCount: fileCount,
                status: status,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$SyncedReposTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({syncedFilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (syncedFilesRefs) db.syncedFiles],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (syncedFilesRefs)
                    await $_getPrefetchedData<
                      SyncedRepoRow,
                      $SyncedReposTable,
                      SyncedFileRow
                    >(
                      currentTable: table,
                      referencedTable: $$SyncedReposTableReferences
                          ._syncedFilesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$SyncedReposTableReferences(
                                db,
                                table,
                                p0,
                              ).syncedFilesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.repoId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SyncedReposTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncedReposTable,
      SyncedRepoRow,
      $$SyncedReposTableFilterComposer,
      $$SyncedReposTableOrderingComposer,
      $$SyncedReposTableAnnotationComposer,
      $$SyncedReposTableCreateCompanionBuilder,
      $$SyncedReposTableUpdateCompanionBuilder,
      (SyncedRepoRow, $$SyncedReposTableReferences),
      SyncedRepoRow,
      PrefetchHooks Function({bool syncedFilesRefs})
    >;
typedef $$SyncedFilesTableCreateCompanionBuilder =
    SyncedFilesCompanion Function({
      Value<int> id,
      required int repoId,
      required String remotePath,
      required String localPath,
      required String sha,
      Value<int> size,
      Value<String> status,
    });
typedef $$SyncedFilesTableUpdateCompanionBuilder =
    SyncedFilesCompanion Function({
      Value<int> id,
      Value<int> repoId,
      Value<String> remotePath,
      Value<String> localPath,
      Value<String> sha,
      Value<int> size,
      Value<String> status,
    });

final class $$SyncedFilesTableReferences
    extends BaseReferences<_$AppDatabase, $SyncedFilesTable, SyncedFileRow> {
  $$SyncedFilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SyncedReposTable _repoIdTable(_$AppDatabase db) =>
      db.syncedRepos.createAlias(
        $_aliasNameGenerator(db.syncedFiles.repoId, db.syncedRepos.id),
      );

  $$SyncedReposTableProcessedTableManager get repoId {
    final $_column = $_itemColumn<int>('repo_id')!;

    final manager = $$SyncedReposTableTableManager(
      $_db,
      $_db.syncedRepos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SyncedFilesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncedFilesTable> {
  $$SyncedFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha => $composableBuilder(
    column: $table.sha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$SyncedReposTableFilterComposer get repoId {
    final $$SyncedReposTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repoId,
      referencedTable: $db.syncedRepos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncedReposTableFilterComposer(
            $db: $db,
            $table: $db.syncedRepos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncedFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncedFilesTable> {
  $$SyncedFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha => $composableBuilder(
    column: $table.sha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$SyncedReposTableOrderingComposer get repoId {
    final $$SyncedReposTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repoId,
      referencedTable: $db.syncedRepos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncedReposTableOrderingComposer(
            $db: $db,
            $table: $db.syncedRepos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncedFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncedFilesTable> {
  $$SyncedFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get sha =>
      $composableBuilder(column: $table.sha, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$SyncedReposTableAnnotationComposer get repoId {
    final $$SyncedReposTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repoId,
      referencedTable: $db.syncedRepos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncedReposTableAnnotationComposer(
            $db: $db,
            $table: $db.syncedRepos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncedFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncedFilesTable,
          SyncedFileRow,
          $$SyncedFilesTableFilterComposer,
          $$SyncedFilesTableOrderingComposer,
          $$SyncedFilesTableAnnotationComposer,
          $$SyncedFilesTableCreateCompanionBuilder,
          $$SyncedFilesTableUpdateCompanionBuilder,
          (SyncedFileRow, $$SyncedFilesTableReferences),
          SyncedFileRow,
          PrefetchHooks Function({bool repoId})
        > {
  $$SyncedFilesTableTableManager(_$AppDatabase db, $SyncedFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SyncedFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SyncedFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$SyncedFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> repoId = const Value.absent(),
                Value<String> remotePath = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String> sha = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => SyncedFilesCompanion(
                id: id,
                repoId: repoId,
                remotePath: remotePath,
                localPath: localPath,
                sha: sha,
                size: size,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int repoId,
                required String remotePath,
                required String localPath,
                required String sha,
                Value<int> size = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => SyncedFilesCompanion.insert(
                id: id,
                repoId: repoId,
                remotePath: remotePath,
                localPath: localPath,
                sha: sha,
                size: size,
                status: status,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$SyncedFilesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({repoId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (repoId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.repoId,
                            referencedTable: $$SyncedFilesTableReferences
                                ._repoIdTable(db),
                            referencedColumn:
                                $$SyncedFilesTableReferences
                                    ._repoIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SyncedFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncedFilesTable,
      SyncedFileRow,
      $$SyncedFilesTableFilterComposer,
      $$SyncedFilesTableOrderingComposer,
      $$SyncedFilesTableAnnotationComposer,
      $$SyncedFilesTableCreateCompanionBuilder,
      $$SyncedFilesTableUpdateCompanionBuilder,
      (SyncedFileRow, $$SyncedFilesTableReferences),
      SyncedFileRow,
      PrefetchHooks Function({bool repoId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SyncedReposTableTableManager get syncedRepos =>
      $$SyncedReposTableTableManager(_db, _db.syncedRepos);
  $$SyncedFilesTableTableManager get syncedFiles =>
      $$SyncedFilesTableTableManager(_db, _db.syncedFiles);
}
