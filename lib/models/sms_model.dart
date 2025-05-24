// lib/models/sms_model.dart

import 'package:telephony/telephony.dart';

class SmsModel {
  final String id;
  final String address;      // phone number
  final String body;
  final int    date;         // millis since epoch
  final SmsType type;        // non-null, with fallback

  SmsModel({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.type,
  });

  /// Safely handle a possibly-null msg.type
  factory SmsModel.fromMessage(SmsMessage msg) {
    return SmsModel(
      id:      msg.id.toString(),
      address: msg.address  ?? '',
      body:    msg.body     ?? '',
      date:    msg.date     ?? 0,
      // Fallback to the first SmsType value if msg.type is null
      type:     msg.type    ?? SmsType.values.first,
    );
  }

  factory SmsModel.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'] as int?;
    return SmsModel(
      id:      map['id']      as String,
      address: map['address'] as String,
      body:    map['body']    as String,
      date:    map['date']    as int,
      // Try to find the matching enum by index; fallback to first value
      type:    SmsType.values.firstWhere(
                 (e) => e.index == rawType,
                 orElse: () => SmsType.values.first,
               ),
    );
  }

  Map<String, dynamic> toMap() => {
    'id':      id,
    'address': address,
    'body':    body,
    'date':    date,
    'type':    type.index,
  };
}
