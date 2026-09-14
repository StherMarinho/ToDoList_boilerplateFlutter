/// Perfil funcional do usuário autenticado.
///
/// Diferentemente da sessão Meteor (token e expiração), este objeto contém os
/// dados que a interface precisa em qualquer módulo: identidade, organização,
/// papéis e, quando publicados pelo servidor, recursos de autorização.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.photo,
    this.phone,
    this.lowercaseName,
    this.companyId,
    this.companyName,
    this.company,
    this.roles = const [],
    this.resources = const [],
    this.status,
    this.inactive = false,
    this.createdAt,
    this.lastUpdate,
    this.syncedAt,
    this.needsSync = false,
    this.createdBy,
    this.updatedBy,
  });

  factory UserProfile.fromMeteor(Map<String, dynamic> map) {
    List<String> strings(dynamic value) {
      if (value is! List) return const [];
      return value.map((item) => item.toString()).toList(growable: false);
    }

    DateTime? date(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value is Map && value[r'$date'] != null) {
        return DateTime.tryParse(value[r'$date'].toString());
      }
      return null;
    }

    String? scalarString(dynamic value) {
      if (value is List) {
        return value.isEmpty ? null : value.first?.toString();
      }
      return value?.toString();
    }

    return UserProfile(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      photo: map['photo']?.toString(),
      phone: map['phone']?.toString(),
      lowercaseName: map['nome_minusculo']?.toString(),
      companyId: map['empresaId']?.toString(),
      companyName: map['nomeEmpresa']?.toString() ?? map['empresa']?.toString(),
      company: map['empresa']?.toString(),
      roles: strings(map['roles']),
      resources: strings(map['resources'] ?? map['permissions']),
      status: scalarString(map['status']),
      inactive: map['inativo'] == true,
      createdAt: date(map['createdat']),
      lastUpdate: date(map['lastupdate']),
      syncedAt: date(map['sincronizadoEm']),
      needsSync: map['needSync'] == true,
      createdBy: map['createdby']?.toString(),
      updatedBy: map['updatedby']?.toString(),
    );
  }

  factory UserProfile.fromCache(Map<String, dynamic> map) =>
      UserProfile.fromMeteor(map);

  factory UserProfile.placeholder(String userId) =>
      UserProfile(id: userId, username: '', email: '');

  final String id;
  final String username;
  final String email;
  final String? photo;
  final String? phone;
  final String? lowercaseName;
  final String? companyId;
  final String? companyName;
  final String? company;
  final List<String> roles;
  final List<String> resources;
  final String? status;
  final bool inactive;
  final DateTime? createdAt;
  final DateTime? lastUpdate;
  final DateTime? syncedAt;
  final bool needsSync;
  final String? createdBy;
  final String? updatedBy;

  String get displayName => username.trim().isNotEmpty
      ? username
      : email.trim().isNotEmpty
      ? email
      : 'Usuário';

  bool hasRole(String role) => roles.contains(role);

  bool get isDisabled => inactive || status == 'disabled';

  /// Documento no formato do contrato `IUserProfile` do backend Meteor.
  Map<String, dynamic> toMeteorDocument() {
    final document = <String, dynamic>{
      '_id': id.isEmpty ? null : id,
      'photo': photo,
      'username': username,
      'email': email,
      'phone': phone,
      'roles': roles,
      'status': status,
      'createdat': createdAt,
      'lastupdate': lastUpdate,
      'sincronizadoEm': syncedAt,
      'needSync': needsSync,
      'createdby': createdBy,
      'updatedby': updatedBy,
    };
    document.removeWhere((_, value) => value == null);
    return document;
  }

  /// Versão pequena persistida para bootstrap offline. A foto não é incluída
  /// para evitar gravar base64 grande no armazenamento seguro.
  Map<String, dynamic> toCacheMap() => <String, dynamic>{
    '_id': id,
    'username': username,
    'email': email,
    'phone': phone,
    'nome_minusculo': lowercaseName,
    'empresaId': companyId,
    'nomeEmpresa': companyName,
    'empresa': company,
    'roles': roles,
    'resources': resources,
    'status': status,
    'inativo': inactive,
    'createdat': createdAt?.toUtc().toIso8601String(),
    'lastupdate': lastUpdate?.toUtc().toIso8601String(),
    'sincronizadoEm': syncedAt?.toUtc().toIso8601String(),
    'needSync': needsSync,
    'createdby': createdBy,
    'updatedby': updatedBy,
  };
}
