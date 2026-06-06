import 'dart:io';

void main() {
  final file = File(r"c:\Programas Utilidades\flutter_multibranch_proyect\lib\src\features\inventory\data\repositories.dart");
  var content = file.readAsStringSync();

  content = content.replaceFirst(
      'Future<List<Branch>> fetchBranches() async {',
      'Future<List<Branch>> fetchBranches({bool forceServer = false}) async {');

  content = content.replaceFirst(
      'get(GetOptions(source: Source.serverAndCache));',
      'get(GetOptions(source: forceServer ? Source.server : Source.serverAndCache));');

  file.writeAsStringSync(content);
  print("Replaced with replaceFirst");
}
