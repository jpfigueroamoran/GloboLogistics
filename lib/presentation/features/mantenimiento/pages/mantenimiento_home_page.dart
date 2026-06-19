import 'package:flutter/material.dart';

import '../../auth/widgets/rol_home_scaffold.dart';
import '../../torre_control/pages/mantenimiento_page.dart';

/// Pantalla del rol Mantenimiento: ve la flota que requiere servicio y la
/// atiende. Reutiliza el tablero predictivo de Torre, sin el resto del menú.
class MantenimientoHomePage extends StatelessWidget {
  const MantenimientoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RolHomeScaffold(
      titulo: 'Taller y Mantenimiento',
      subtitulo: 'Unidades que requieren servicio',
      body: MantenimientoPage(),
    );
  }
}
