import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/documento_vencimiento.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../injection_container.dart';

class CargarDocumentoDialog extends ConsumerStatefulWidget {
  const CargarDocumentoDialog({super.key});

  @override
  ConsumerState<CargarDocumentoDialog> createState() => _CargarDocumentoDialogState();
}

class _CargarDocumentoDialogState extends ConsumerState<CargarDocumentoDialog> {
  final _formKey = GlobalKey<FormState>();
  
  String _entidadId = '';
  String _nombreEntidad = '';
  TipoDocumento _tipo = TipoDocumento.licenciaConducir;
  DateTime _fechaVencimiento = DateTime.now().add(const Duration(days: 365));
  bool _esUnidad = false;
  File? _archivo;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _archivo = File(picked.path));
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) {
      setState(() => _fechaVencimiento = date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _archivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos y sube un archivo.')),
      );
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isUploading = true);

    try {
      // 1. Subir a Storage
      final storage = sl<StorageService>();
      final url = await storage.uploadDocumento(_archivo!, _entidadId.isEmpty ? 'unknown' : _entidadId);

      // 2. Guardar en Firestore
      final remote = sl<FirestoreDatasource>();
      await remote.crearDocumento({
        'entidad_id':        _entidadId,
        'nombre_entidad':    _nombreEntidad,
        'tipo':              _tipo.name,
        'fecha_vencimiento': _fechaVencimiento,
        'es_unidad':         _esUnidad,
        'url_archivo': url,
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento subido correctamente'), backgroundColor: GloboColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: GloboColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cargar Documento', style: GloboTypography.headlineMedium),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'ID (Operador o Unidad)'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
                onSaved: (v) => _entidadId = v!,
              ),
              const SizedBox(height: GloboSpacing.sm),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nombre o Placa'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
                onSaved: (v) => _nombreEntidad = v!,
              ),
              const SizedBox(height: GloboSpacing.sm),
              SwitchListTile(
                title: const Text('¿Es documento de unidad?'),
                value: _esUnidad,
                onChanged: (v) => setState(() => _esUnidad = v),
              ),
              const SizedBox(height: GloboSpacing.sm),
              DropdownButtonFormField<TipoDocumento>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de Documento'),
                items: TipoDocumento.values.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.name),
                )).toList(),
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: GloboSpacing.md),
              Row(
                children: [
                  Expanded(child: Text('Vence: ${_fechaVencimiento.toLocal().toString().split(' ')[0]}')),
                  TextButton(onPressed: _pickDate, child: const Text('Cambiar')),
                ],
              ),
              const SizedBox(height: GloboSpacing.md),
              _archivo == null
                ? ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Seleccionar Archivo'),
                  )
                : Row(
                    children: [
                      const Icon(Icons.check_circle, color: GloboColors.success),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Archivo seleccionado')),
                      IconButton(
                        icon: const Icon(Icons.delete, color: GloboColors.error),
                        onPressed: () => setState(() => _archivo = null),
                      )
                    ],
                  ),
              if (_isUploading) ...[
                const SizedBox(height: GloboSpacing.md),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _submit,
          child: const Text('Subir Documento'),
        ),
      ],
    );
  }
}
