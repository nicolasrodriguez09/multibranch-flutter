import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'features/inventory/application/inventory_workflow_service.dart';
import 'features/inventory/presentation/inventory_dashboard_page.dart';

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    FirebaseFirestore? firestore,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        service = InventoryWorkflowService(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  final FirebaseFirestore firestore;
  final InventoryWorkflowService service;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF005F73),
      primary: const Color(0xFF005F73),
      secondary: const Color(0xFFEE9B00),
      surface: const Color(0xFFF6F1E8),
    );

    return MaterialApp(
      title: 'Multi-Branch Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4EFE6),
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        useMaterial3: true,
      ),
      home: InventoryDashboardPage(service: service),
    );
  }
}
