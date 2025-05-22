class FavoriteModel {
  final String contactId;
  final int callCount;
  final int smsCount;
  final DateTime lastUpdated;

  FavoriteModel({
    required this.contactId,
    required this.callCount,
    required this.smsCount,
    required this.lastUpdated,
  });

  factory FavoriteModel.fromMap(Map<String, dynamic> map) {
    return FavoriteModel(
      contactId: map['contactId'],
      callCount: map['callCount'] ?? 0,
      smsCount: map['smsCount'] ?? 0,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['lastUpdated']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contactId': contactId,
      'callCount': callCount,
      'smsCount': smsCount,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }
}