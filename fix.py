import re

filepath = r"c:\Programas Utilidades\flutter_multibranch_proyect\lib\src\features\inventory\data\repositories.dart"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

target = """  Future<List<Branch>> fetchBranches() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.branches)
        .where('isActive', isEqualTo: true)
        .get(GetOptions(source: Source.serverAndCache));"""

replacement = """  Future<List<Branch>> fetchBranches({bool forceServer = false}) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.branches)
        .where('isActive', isEqualTo: true)
        .get(GetOptions(source: forceServer ? Source.server : Source.serverAndCache));"""

new_content = content.replace(target, replacement)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(new_content)

print("Replaced successfully")
