class SmsModel {
  final String id;
  final String contactId;
  final String text;
  final String sender; // 'me' or 'them'
  final DateTime date;

  SmsModel({
    required this.id,
    required this.contactId,
    required this.text,
    required this.sender,
    required this.date,
  });

  factory SmsModel.fromMap(Map<String, dynamic> map) {
    return SmsModel(
      id: map['id'],
      contactId: map['contactId'],
      text: map['text'],
      sender: map['sender'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contactId': contactId,
      'text': text,
      'sender': sender,
      'date': date.millisecondsSinceEpoch,
    };
  }
}