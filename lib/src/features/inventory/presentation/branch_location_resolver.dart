import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/models.dart';

enum BranchLocationAccessStatus {
  granted,
  denied,
  deniedForever,
  servicesDisabled,
  unsupported,
  error,
}

class BranchLocationAccessResult {
  const BranchLocationAccessResult({
    required this.status,
    this.location,
    required this.message,
  });

  final BranchLocationAccessStatus status;
  final BranchLocation? location;
  final String message;

  bool get hasLocation => location != null;
}

abstract class BranchLocationResolver {
  Future<BranchLocationAccessResult> resolveCurrentLocation();

  Future<bool> openLocationSettings();

  Future<bool> openAppSettings();
}

class GeolocatorBranchLocationResolver implements BranchLocationResolver {
  const GeolocatorBranchLocationResolver();

  @override
  Future<BranchLocationAccessResult> resolveCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const BranchLocationAccessResult(
          status: BranchLocationAccessStatus.servicesDisabled,
          message:
              'Los servicios de ubicacion estan desactivados. Se usa la sucursal asignada como referencia.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      switch (permission) {
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return const BranchLocationAccessResult(
            status: BranchLocationAccessStatus.denied,
            message:
                'No se concedio el permiso de ubicacion. Se usa la sucursal asignada como referencia.',
          );
        case LocationPermission.deniedForever:
          return const BranchLocationAccessResult(
            status: BranchLocationAccessStatus.deniedForever,
            message:
                'La ubicacion esta bloqueada para esta app. Se usa la sucursal asignada como referencia.',
          );
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
          return BranchLocationAccessResult(
            status: BranchLocationAccessStatus.granted,
            location: BranchLocation(
              lat: position.latitude,
              lng: position.longitude,
            ),
            message:
                'Ubicacion actual activa. Las distancias se ordenan desde el dispositivo.',
          );
      }
    } on UnsupportedError {
      return const BranchLocationAccessResult(
        status: BranchLocationAccessStatus.unsupported,
        message:
            'La ubicacion no esta soportada en este dispositivo. Se usa la sucursal asignada como referencia.',
      );
    } on TimeoutException {
      return const BranchLocationAccessResult(
        status: BranchLocationAccessStatus.error,
        message:
            'No se pudo obtener la ubicacion a tiempo. Se usa la sucursal asignada como referencia.',
      );
    } on LocationServiceDisabledException {
      return const BranchLocationAccessResult(
        status: BranchLocationAccessStatus.servicesDisabled,
        message:
            'Los servicios de ubicacion estan desactivados. Se usa la sucursal asignada como referencia.',
      );
    } catch (_) {
      return const BranchLocationAccessResult(
        status: BranchLocationAccessStatus.error,
        message:
            'No se pudo resolver la ubicacion actual. Se usa la sucursal asignada como referencia.',
      );
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
