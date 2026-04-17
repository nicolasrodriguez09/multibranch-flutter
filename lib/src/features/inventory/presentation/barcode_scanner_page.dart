import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({
    super.key,
    required this.service,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with WidgetsBindingObserver {
  final TextEditingController _manualBarcodeController =
      TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isResolving = false;
  bool _isStartingScanner = false;
  String? _feedbackMessage;
  MobileScannerException? _scannerError;

  bool get _supportsLiveScanner =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startScanner());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualBarcodeController.dispose();
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_supportsLiveScanner) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_startScanner());
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_stopScanner());
        return;
    }
  }

  Future<void> _startScanner() async {
    if (!_supportsLiveScanner || !mounted || _isStartingScanner) {
      return;
    }
    if (_scannerController.value.isRunning || _isResolving) {
      return;
    }

    setState(() {
      _isStartingScanner = true;
    });

    try {
      await _scannerController.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _scannerError = null;
        _feedbackMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scannerError = error is MobileScannerException
            ? error
            : MobileScannerException(
                errorCode: MobileScannerErrorCode.genericError,
                errorDetails: MobileScannerErrorDetails(
                  message: error.toString(),
                ),
              );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStartingScanner = false;
        });
      }
    }
  }

  Future<void> _stopScanner() async {
    if (_scannerController.value.isRunning) {
      await _scannerController.stop();
    }
  }

  Future<void> _lookupAndClose(String rawBarcode) async {
    if (_isResolving) {
      return;
    }

    final barcode = rawBarcode.trim();
    if (barcode.isEmpty) {
      setState(() {
        _feedbackMessage = 'Ingresa o escanea un codigo de barras valido.';
      });
      return;
    }

    setState(() {
      _isResolving = true;
      _feedbackMessage = null;
    });

    await _stopScanner();

    try {
      final result = await widget.service.findProductByBarcode(
        actorUser: widget.currentUser,
        branchId: widget.currentUser.branchId,
        barcode: barcode,
      );

      if (!mounted) {
        return;
      }

      if (result == null) {
        setState(() {
          _feedbackMessage =
              'No se encontro un producto para el codigo $barcode.';
        });
        await _startScanner();
        return;
      }

      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage = 'No se pudo resolver el codigo. $error';
      });
      await _startScanner();
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  String _scannerStatusMessage(MobileScannerException error) {
    return switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'La camara no tiene permiso. Habilitala y vuelve a intentar.',
      MobileScannerErrorCode.unsupported =>
        'Este dispositivo no soporta escaneo por camara.',
      _ => error.errorDetails?.message ?? error.errorCode.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear codigo de barras')),
      body: Container(
        color: const Color(0xFF08172D),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escaneo inmediato',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Apunta la camara al codigo de barras o ingresa el codigo manualmente para consultar existencias.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Panel(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(height: 340, child: _buildScannerPreview()),
                ),
              ),
              const SizedBox(height: 12),
              if (_feedbackMessage != null) ...[
                _Panel(
                  child: Text(
                    _feedbackMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingreso manual',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _manualBarcodeController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _lookupAndClose,
                      decoration: InputDecoration(
                        labelText: 'Codigo de barras',
                        suffixIcon: _isResolving
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                onPressed: () {
                                  unawaited(
                                    _lookupAndClose(
                                      _manualBarcodeController.text,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.arrow_forward_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: _isResolving
                              ? null
                              : () {
                                  unawaited(
                                    _lookupAndClose(
                                      _manualBarcodeController.text,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Consultar codigo'),
                        ),
                        if (_supportsLiveScanner)
                          OutlinedButton.icon(
                            onPressed: _isResolving
                                ? null
                                : () {
                                    unawaited(_startScanner());
                                  },
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Reactivar camara'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerPreview() {
    if (!_supportsLiveScanner) {
      return _ScannerFallback(
        title: 'Camara no disponible',
        message:
            'En esta plataforma no hay escaneo en vivo. Usa el ingreso manual.',
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final rawValue = capture.barcodes.isEmpty
                ? null
                : capture.barcodes.first.rawValue;
            if (rawValue == null || rawValue.isEmpty) {
              return;
            }
            _manualBarcodeController.text = rawValue;
            unawaited(_lookupAndClose(rawValue));
          },
          overlayBuilder: (context, constraints) {
            return Center(
              child: Container(
                width: constraints.maxWidth * 0.72,
                height: constraints.maxHeight * 0.28,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _scannerError = error;
              });
            });
            return _ScannerFallback(
              title: 'No se pudo iniciar la camara',
              message: _scannerStatusMessage(error),
            );
          },
          placeholderBuilder: (_) => const ColoredBox(color: Colors.black),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scannerController,
            builder: (context, state, _) {
              final torchState = state.torchState;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (torchState != TorchState.unavailable)
                    _ScannerActionButton(
                      icon: torchState == TorchState.on
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      onPressed: () {
                        unawaited(_scannerController.toggleTorch());
                      },
                    ),
                  const SizedBox(width: 8),
                  _ScannerActionButton(
                    icon: Icons.flip_camera_android_rounded,
                    onPressed: () {
                      unawaited(_scannerController.switchCamera());
                    },
                  ),
                ],
              );
            },
          ),
        ),
        if (_isResolving || _isStartingScanner)
          Container(
            color: Colors.black.withValues(alpha: 0.48),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _scannerError == null
                  ? 'Alinea el codigo dentro del marco para buscar el producto.'
                  : _scannerStatusMessage(_scannerError!),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: child,
    );
  }
}

class _ScannerFallback extends StatelessWidget {
  const _ScannerFallback({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF06152A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white70,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerActionButton extends StatelessWidget {
  const _ScannerActionButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
