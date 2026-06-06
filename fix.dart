
import 'dart:io';

void main() {
  final file = File(r"c:\Programas Utilidades\flutter_multibranch_proyect\lib\src\features\inventory\data\repositories.dart");
  var content = file.readAsStringSync();

  final target = '''  Future<List<Branch>> fetchBranches() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.branches)
        .where('isActive', isEqualTo: true)
        .get(GetOptions(source: Source.serverAndCache));''';

  final replacement = '''  Future<List<Branch>> fetchBranches({bool forceServer = false}) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.branches)
        .where('isActive', isEqualTo: true)
        .get(GetOptions(source: forceServer ? Source.server : Source.serverAndCache));''';

  content = content.replaceAll(target, replacement);

  file.writeAsStringSync(content);
  print("Replaced successfully");
}
