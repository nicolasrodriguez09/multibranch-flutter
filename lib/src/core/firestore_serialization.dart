import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? readDateTime(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

Timestamp? writeDateTime(DateTime? value) {
  if (value == null) {
    return null;
  }
  return Timestamp.fromDate(value.toUtc());
}

String readString(Map<String, dynamic> data, String key, {String fallback = ''}) {
  final value = data[key];
  if (value is String) {
    return value;
  }
  return fallback;
}

bool readBool(Map<String, dynamic> data, String key, {bool fallback = false}) {
  final value = data[key];
  if (value is bool) {
    return value;
  }
  return fallback;
}

int readInt(Map<String, dynamic> data, String key, {int fallback = 0}) {
  final value = data[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

double readDouble(Map<String, dynamic> data, String key, {double fallback = 0}) {
  final value = data[key];
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

List<String> readStringList(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }
  return const [];
}
