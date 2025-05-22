// lib/models/contact_model.dart

class ContactModel {
  final String id;
  final String name;
  final String? photo; // base64
  final List<String> phones;
  final List<String> emails;
  final DateTime createdAt;

  ContactModel({
    required this.id,
    required this.name,
    this.photo,
    required this.phones,
    required this.emails,
    required this.createdAt,
  });

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown',
      photo: map['photo']?.toString(),
      phones: List<String>.from(
        map['phones']?.map((p) => p?.toString() ?? '') ?? [],
      ),
      emails: List<String>.from(
        map['emails']?.map((e) => e?.toString() ?? '') ?? [],
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] is int
            ? map['createdAt']
            : DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'photo': photo,
      'phones': phones,
      'emails': emails,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
