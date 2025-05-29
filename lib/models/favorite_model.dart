class FavoriteModel {
  final String contactId;
  final String name;
  final String number;
  final int callCount;
  final int smsCount;
  final DateTime lastUpdated;
  final bool manuelle;

  FavoriteModel({
    required this.contactId,
    required this.name,
    required this.number,
    required this.callCount,
    required this.smsCount,
    required this.lastUpdated,
    this.manuelle = false,
  });

  factory FavoriteModel.fromMap(Map<String, dynamic> map) {
    return FavoriteModel(
      contactId: map['contactId'],
      name: map['name'],
      number: map['number'],
      callCount: map['callCount'] ?? 0,
      smsCount: map['smsCount'] ?? 0,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['lastUpdated']),
      manuelle: (map['manuelle'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contactId': contactId,
      'name': name,
      'number': number,
      'callCount': callCount,
      'smsCount': smsCount,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'manuelle': manuelle ? 1 : 0,
    };
  }

  bool isSameAs(FavoriteModel other) {
    return contactId == other.contactId &&
        name == other.name &&
        number == other.number &&
        smsCount == other.smsCount &&
        callCount == other.callCount &&
        lastUpdated == other.lastUpdated &&
        manuelle == other.manuelle;
  }
}
