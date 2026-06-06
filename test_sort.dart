void main() {
  final a = DateTime.now().subtract(Duration(hours: 1)); // 1 hour ago
  final b = DateTime.now().subtract(Duration(hours: 17)); // 17 hours ago
  final dates = [b, a];
  dates.sort((x, y) => y.compareTo(x));
  print("Sorted:");
  for (final d in dates) {
    print(d);
  }
}
