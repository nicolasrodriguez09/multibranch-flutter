# Firestore Base Setup

Flutter + Firebase con la base inicial de Firestore para el proyecto de inventario multi-sucursal.

En esta etapa se crean solamente las colecciones maestras:

- `users`
- `branches`
- `categories`
- `products`
- `inventories`

## Ejecutar

1. Verifica que `android/app/google-services.json` exista.
2. Ejecuta:

```powershell
flutter pub get
flutter run -d emulator-5554
```

3. En la app pulsa `Crear base inicial`.

Eso crea documentos base en Firestore para que la estructura quede visible en la consola.

Todavia no se usa la interfaz para reservas, traslados ni notificaciones.

## Archivos clave

- `lib/src/features/inventory/domain/models.dart`: contrato de datos Firestore
- `lib/src/features/inventory/application/inventory_workflow_service.dart`: carga base de datos y logica futura
- `lib/src/features/inventory/presentation/inventory_dashboard_page.dart`: pantalla para crear y verificar la base
- `firestore.rules`: reglas base de seguridad
- `firestore.indexes.json`: indices compuestos recomendados

## Desplegar reglas e indices

Si ya tienes Firebase CLI configurado:

```powershell
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

## Nota

La autenticacion real con Firebase Auth y la asignacion automatica de `users/{uid}` todavia no estan conectadas a la UI.
