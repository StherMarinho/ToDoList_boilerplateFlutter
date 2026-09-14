import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example_asset.dart';

enum ExampleSyncStatus { synced, pending, syncing, failed, conflict }

class Example {
  const Example({
    required this.id,
    required this.title,
    required this.type,
    required this.priority,
    this.description,
    this.image,
    this.date,
    this.check = const [],
    this.chips = const [],
    this.files = const [],
    this.contacts = const {},
    this.tasks = const [],
    this.audio,
    this.address = const {},
    this.slider = 0,
    this.statusRadio,
    this.statusToggle = false,
    this.createdAt,
    this.lastUpdate,
    this.createdBy,
    this.updatedBy,
    this.assets = const [],
    this.syncStatus = ExampleSyncStatus.synced,
    this.syncError,
  });

  factory Example.fromMeteor(Map<String, dynamic> map) {
    DateTime? date(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return null;
    }

    List<String> strings(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return const [];
    }

    List<Map<String, dynamic>> maps(dynamic value) {
      return value is List
          ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : const [];
    }

    return Example(
      id: map['_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      image: map['image']?.toString(),
      type: map['type']?.toString() ?? '',
      priority: map['typeMulti']?.toString() ?? '',
      date: date(map['date']),
      check: strings(map['check']),
      chips: strings(map['chip']),
      files: maps(map['files']),
      contacts: map['contacts'] is Map
          ? Map<String, dynamic>.from(map['contacts'] as Map)
          : const {},
      tasks: maps(map['tasks']),
      audio: map['audio']?.toString(),
      address: map['address'] is Map
          ? Map<String, dynamic>.from(map['address'] as Map)
          : const {},
      slider: (map['slider'] as num?)?.toDouble() ?? 0,
      statusRadio: map['statusRadio']?.toString(),
      statusToggle: map['statusToggle'] == true,
      createdAt: date(map['createdat']),
      lastUpdate: date(map['lastupdate']),
      createdBy: map['createdby']?.toString(),
      updatedBy: map['updatedby']?.toString(),
      assets:
          (map['assets'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => ExampleAsset.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList() ??
          const [],
      syncStatus: ExampleSyncStatus.values.firstWhere(
        (value) => value.name == map['_syncStatus'],
        orElse: () => ExampleSyncStatus.synced,
      ),
      syncError: map['_syncError']?.toString(),
    );
  }

  final String id;
  final String title;
  final String? description;
  final String? image;
  final String type;
  final String priority;
  final DateTime? date;
  final List<String> check;
  final List<String> chips;
  final List<Map<String, dynamic>> files;
  final Map<String, dynamic> contacts;
  final List<Map<String, dynamic>> tasks;
  final String? audio;
  final Map<String, dynamic> address;
  final double slider;
  final String? statusRadio;
  final bool statusToggle;
  final DateTime? createdAt;
  final DateTime? lastUpdate;
  final String? createdBy;
  final String? updatedBy;
  final List<ExampleAsset> assets;
  final ExampleSyncStatus syncStatus;
  final String? syncError;

  Example copyWith({
    List<ExampleAsset>? assets,
    ExampleSyncStatus? syncStatus,
    String? syncError,
    bool clearSyncError = false,
  }) {
    return Example(
      id: id,
      title: title,
      description: description,
      image: image,
      type: type,
      priority: priority,
      date: date,
      check: check,
      chips: chips,
      files: files,
      contacts: contacts,
      tasks: tasks,
      audio: audio,
      address: address,
      slider: slider,
      statusRadio: statusRadio,
      statusToggle: statusToggle,
      createdAt: createdAt,
      lastUpdate: lastUpdate,
      createdBy: createdBy,
      updatedBy: updatedBy,
      assets: assets ?? this.assets,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: clearSyncError ? null : syncError ?? this.syncError,
    );
  }

  Map<String, dynamic> toMeteorDocument() {
    return <String, dynamic>{
      if (id.isNotEmpty) '_id': id,
      'title': title.trim(),
      if (description?.trim().isNotEmpty == true)
        'description': description!.trim(),
      'type': type,
      'typeMulti': priority,
      if (image?.isNotEmpty == true) 'image': image,
      if (date != null) 'date': date,
      if (check.isNotEmpty) 'check': check,
      if (chips.isNotEmpty) 'chip': chips,
      if (files.isNotEmpty) 'files': files,
      if (contacts.isNotEmpty) 'contacts': contacts,
      if (tasks.isNotEmpty) 'tasks': tasks,
      if (audio?.isNotEmpty == true) 'audio': audio,
      if (address.isNotEmpty) 'address': address,
      'slider': slider,
      if (statusRadio?.isNotEmpty == true) 'statusRadio': statusRadio,
      'statusToggle': statusToggle,
    };
  }
}
