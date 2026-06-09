import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/factura_proveedor.dart';
import '../providers/factura_proveedor_provider.dart';

class SubirFacturaProveedorDialog extends ConsumerStatefulWidget {
  const SubirFacturaProveedorDialog({super.key});

  @override
  ConsumerState<SubirFacturaProveedorDialog> createState() =>
      _SubirFacturaProveedorDialogState();
}

class _SubirFacturaProveedorDialogState
    extends ConsumerState<SubirFacturaProveedorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _proveedorController = TextEditingController();
  final _montoController = TextEditingController();
  final _numeroFacturaController = TextEditingController();
  TipoProveedor _tipoSeleccionado = TipoProveedor.mantenimiento;
  DateTime _fechaVencimiento = DateTime.now().add(const Duration(days: 30));
  bool _archivoSubido = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _proveedorController.dispose();
    _montoController.dispose();
    _numeroFacturaController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarVencimiento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _fechaVencimiento = picked);
    }
  }

  void _simularSubidaPDF() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1)); // Simula subida
    setState(() {
      _archivoSubido = true;
      _isSubmitting = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF adjuntado correctamente.'),
          backgroundColor: GloboColors.successAccent,
        ),
      );
    }
  }

  void _guardarFactura() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_archivoSubido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe adjuntar el archivo PDF de la factura.'),
          backgroundColor: GloboColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final nuevaFactura = FacturaProveedor(
      id: const Uuid().v4(),
      proveedorId: 'prov-${_proveedorController.text.toLowerCase().replaceAll(' ', '')}',
      proveedorNombre: _proveedorController.text,
      tipoProveedor: _tipoSeleccionado,
      numeroFactura: _numeroFacturaController.text,
      fechaEmision: DateTime.now(),
      fechaVencimiento: _fechaVencimiento,
      monto: double.parse(_montoController.text),
      estatus: EstatusFacturaProveedor.pendiente,
    );

    final result = await ref.read(crearFacturaProveedorProvider)(nuevaFactura);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $failure'), backgroundColor: GloboColors.error),
        );
      },
      (id) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto/Factura registrado exitosamente.'),
            backgroundColor: GloboColors.successAccent,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: GloboColors.primary),
          const SizedBox(width: GloboSpacing.sm),
          const Text('Registrar Nuevo Gasto / Factura'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 450,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<TipoProveedor>(
                  value: _tipoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Gasto',
                    border: OutlineInputBorder(),
                  ),
                  items: TipoProveedor.values.map((tipo) {
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text(tipo.label),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _tipoSeleccionado = v!),
                ),
                const SizedBox(height: GloboSpacing.md),
                TextFormField(
                  controller: _proveedorController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Proveedor / Taller',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: GloboSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _numeroFacturaController,
                        decoration: const InputDecoration(
                          labelText: 'Folio de Factura',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: GloboSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _montoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Monto Total',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (v) {
                          if (v!.isEmpty) return 'Requerido';
                          if (double.tryParse(v) == null) return 'Monto inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GloboSpacing.md),
                InkWell(
                  onTap: _seleccionarVencimiento,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Vencimiento',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      '${_fechaVencimiento.day}/${_fechaVencimiento.month}/${_fechaVencimiento.year}',
                    ),
                  ),
                ),
                const SizedBox(height: GloboSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(GloboSpacing.md),
                  decoration: BoxDecoration(
                    color: _archivoSubido ? GloboColors.success.withAlpha(20) : GloboColors.backgroundSecondary,
                    borderRadius: GloboRadius.cardRadius,
                    border: Border.all(color: _archivoSubido ? GloboColors.success : GloboColors.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _archivoSubido ? Icons.check_circle : Icons.picture_as_pdf_outlined,
                        color: _archivoSubido ? GloboColors.success : GloboColors.primary,
                        size: 32,
                      ),
                      const SizedBox(width: GloboSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _archivoSubido ? 'Factura.pdf (245 KB)' : 'Adjuntar Archivo PDF',
                              style: GloboTypography.titleMedium,
                            ),
                            Text(
                              _archivoSubido ? 'Archivo verificado y listo.' : 'Sube la factura digitalizada (PDF/JPG)',
                              style: GloboTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      if (!_archivoSubido)
                        _isSubmitting
                            ? const CircularProgressIndicator()
                            : OutlinedButton.icon(
                                onPressed: _simularSubidaPDF,
                                icon: const Icon(Icons.upload_file, size: 16),
                                label: const Text('Subir'),
                              ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _guardarFactura,
          icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
          label: const Text('Guardar Factura'),
        ),
      ],
    );
  }
}
