import 'package:flutter/material.dart';

import '../../../../core/constants/theme_constants.dart';
import '../../auth/widgets/rol_home_scaffold.dart';
import '../../torre_control/pages/reportes_page.dart';
import '../../torre_control/pages/resumen_financiero_page.dart';

/// Pantalla de Dirección: indicadores en solo lectura, sin controles de
/// edición. Resumen ejecutivo + reportes analíticos en dos pestañas.
class DireccionHomePage extends StatefulWidget {
  const DireccionHomePage({super.key});

  @override
  State<DireccionHomePage> createState() => _DireccionHomePageState();
}

class _DireccionHomePageState extends State<DireccionHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RolHomeScaffold(
      titulo: 'Dirección',
      subtitulo: 'Indicadores ejecutivos · solo lectura',
      bottom: TabBar(
        controller: _tab,
        labelColor: Colors.white,
        unselectedLabelColor: GloboColors.textOnDarkSecondary,
        indicatorColor: GloboColors.accentGlow,
        tabs: const [
          Tab(icon: Icon(Icons.bar_chart_outlined, size: 20), text: 'Resumen'),
          Tab(icon: Icon(Icons.analytics_outlined, size: 20), text: 'Reportes'),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          ResumenFinancieroPage(),
          ReportesPage(),
        ],
      ),
    );
  }
}
