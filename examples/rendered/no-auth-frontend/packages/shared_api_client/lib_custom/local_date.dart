/// Represents a date-only value (no time, no timezone) from an ISO 8601 date
/// string like "2024-01-15".
///
/// Map OpenAPI `format: date` fields to this with vendor extensions on the
/// schema property, so the generated client uses LocalDate instead of DateTime
/// (DateTime introduces timezone shifts that break backend date validation):
///
///   someDate:
///     type: string
///     format: date
///     x-dart-type: LocalDate
///     x-dart-import: package:shared_api_client/local_date.dart
class LocalDate implements Comparable<LocalDate> {
  final int year;
  final int month;
  final int day;

  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime dt) =>
      LocalDate(dt.year, dt.month, dt.day);

  factory LocalDate.today() => LocalDate.fromDateTime(DateTime.now());

  factory LocalDate.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 3) throw FormatException('Invalid date: $value');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static LocalDate? tryParse(String? value) {
    if (value == null) return null;
    try {
      return LocalDate.parse(value);
    } catch (_) {
      return null;
    }
  }

  factory LocalDate.fromJson(String value) => LocalDate.parse(value);

  String toJson() => toString();

  DateTime toDateTime() => DateTime(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  int compareTo(LocalDate other) {
    final y = year.compareTo(other.year);
    if (y != 0) return y;
    final m = month.compareTo(other.month);
    if (m != 0) return m;
    return day.compareTo(other.day);
  }

  bool operator <(LocalDate other) => compareTo(other) < 0;
  bool operator <=(LocalDate other) => compareTo(other) <= 0;
  bool operator >(LocalDate other) => compareTo(other) > 0;
  bool operator >=(LocalDate other) => compareTo(other) >= 0;
}
