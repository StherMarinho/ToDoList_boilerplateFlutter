enum ToDoPriority {
  low('baixa', 'Baixa'),
  medium('media', 'Média'),
  high('alta', 'Alta');

  const ToDoPriority(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ToDoPriority fromWire(dynamic value) {
    return values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () => ToDoPriority.low,
    );
  }
}

class ToDo {
  const ToDo({
    required this.id,
    required this.description,
    required this.priority,
    this.deadline,
    this.personal = false,
    this.completed = false,
    this.completedAt,
    this.authorName,
    this.createdBy,
    this.createdAt,
    this.lastUpdate,
  });

  factory ToDo.fromMeteor(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is num) {
        return DateTime.fromMicrosecondsSinceEpoch(value.toInt());
      }
      if (value is Map && value[r'$date'] != null) {
        return DateTime.tryParse(value[r'$date'].toString());
      }
      return null;
    }

    return ToDo(
      id: map['_id']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      priority: ToDoPriority.fromWire(map['priority']),
      deadline: parseDate(map['deadline']),
      personal: map['personal'] == true,
      completed: map['completed'] == true,
      completedAt: parseDate(map['completedAt']),
      authorName: map['authorName']?.toString(),
      createdBy: map['createdby']?.toString(),
      createdAt: parseDate(map['createdat']),
      lastUpdate: parseDate(map['lastupdate']),
    );
  }

  final String id;
  final String description;
  final ToDoPriority priority;
  final DateTime? deadline;
  final bool personal;
  final bool completed;
  final DateTime? completedAt;
  final String? authorName;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? lastUpdate;

  bool isOwnedBy(String? userId) {
    return userId != null && createdBy == userId;
  }

  Map<String, dynamic> toEditableMeteorDocument() {
    return {
      if (id.isNotEmpty) '_id': id,
      'description': description.trim(),
      'priority': priority.wireValue,
      'personal': personal,
      'deadline': deadline,
    };
  }
}
