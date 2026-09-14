enum ExampleAssetKind { image, audio, attachment }

enum ExampleAssetSyncStatus {
  localOnly,
  uploading,
  available,
  downloading,
  failed,
}

/// Metadados de um arquivo associado ao Example.
///
/// O conteúdo nunca é armazenado no SQLite: apenas o caminho no sandbox do
/// aplicativo e/ou a URL remota. Isso mantém o banco pequeno e permite retomar
/// uploads e downloads sem carregar arquivos inteiros em memória.
class ExampleAsset {
  const ExampleAsset({
    required this.id,
    required this.exampleId,
    required this.kind,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.status,
    this.localPath,
    this.remoteUrl,
    this.checksum,
    this.error,
    this.createdAt,
  });

  factory ExampleAsset.fromMap(Map<String, dynamic> map) {
    return ExampleAsset(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
      exampleId: map['exampleId']?.toString() ?? '',
      kind: ExampleAssetKind.values.firstWhere(
        (value) => value.name == map['kind'],
        orElse: () => ExampleAssetKind.attachment,
      ),
      name: map['name']?.toString() ?? 'arquivo',
      mimeType:
          map['mimeType']?.toString() ??
          map['type']?.toString() ??
          'application/octet-stream',
      size: (map['size'] as num?)?.toInt() ?? 0,
      localPath: map['localPath']?.toString(),
      remoteUrl: map['url']?.toString() ?? map['remoteUrl']?.toString(),
      checksum: map['checksum']?.toString(),
      error: map['error']?.toString(),
      status: ExampleAssetSyncStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => ExampleAssetSyncStatus.available,
      ),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  final String id;
  final String exampleId;
  final ExampleAssetKind kind;
  final String name;
  final String mimeType;
  final int size;
  final String? localPath;
  final String? remoteUrl;
  final String? checksum;
  final String? error;
  final ExampleAssetSyncStatus status;
  final DateTime? createdAt;

  bool get hasLocalCopy => localPath?.isNotEmpty == true;
  bool get isRemoteOnly => !hasLocalCopy && remoteUrl?.isNotEmpty == true;
  bool get shouldAutoDownload =>
      isRemoteOnly && kind != ExampleAssetKind.attachment;

  ExampleAsset copyWith({
    String? localPath,
    String? remoteUrl,
    String? checksum,
    String? error,
    bool clearError = false,
    ExampleAssetSyncStatus? status,
  }) {
    return ExampleAsset(
      id: id,
      exampleId: exampleId,
      kind: kind,
      name: name,
      mimeType: mimeType,
      size: size,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      checksum: checksum ?? this.checksum,
      error: clearError ? null : error ?? this.error,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'exampleId': exampleId,
    'kind': kind.name,
    'name': name,
    'mimeType': mimeType,
    'size': size,
    'localPath': localPath,
    'remoteUrl': remoteUrl,
    'checksum': checksum,
    'error': error,
    'status': status.name,
    'createdAt': createdAt?.toUtc().toIso8601String(),
  };
}
