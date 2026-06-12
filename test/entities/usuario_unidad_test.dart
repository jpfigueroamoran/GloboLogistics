import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/domain/entities/unidad.dart';
import 'package:globo_logistics/domain/entities/usuario_globo.dart';

void main() {
  group('Roles y acceso', () {
    test('operador no accede a Torre de Control', () {
      const u = UsuarioGlobo(
          uid: '1', email: 'a@b.c', nombre: 'Op', rol: RolUsuario.operador);
      expect(u.puedeAccederTorre, isFalse);
      expect(u.esOperador, isTrue);
    });

    test('supervisor y admin acceden a Torre de Control', () {
      const sup = UsuarioGlobo(
          uid: '2', email: 's@b.c', nombre: 'Sup', rol: RolUsuario.supervisor);
      const adm = UsuarioGlobo(
          uid: '3', email: 'd@b.c', nombre: 'Adm', rol: RolUsuario.administrador);
      expect(sup.puedeAccederTorre, isTrue);
      expect(adm.puedeAccederTorre, isTrue);
    });

    test('fromString mapea roles y cae a operador por defecto', () {
      expect(RolUsuarioExt.fromString('administrador'), RolUsuario.administrador);
      expect(RolUsuarioExt.fromString('basura'), RolUsuario.operador);
      expect(RolUsuarioExt.fromString(null), RolUsuario.operador);
    });
  });

  group('Unidad — lógica de estado', () {
    Unidad unidad({
      EstadoUnidad estado = EstadoUnidad.activa,
      String? viajeActivoId,
      double odometro = 100000,
      double? proxMant,
    }) =>
        Unidad(
          id: 'u',
          placas: 'ABC123',
          modelo: 'Kenworth',
          anio: 2022,
          estado: estado,
          odometro: odometro,
          capacidadTanqueLitros: 400,
          viajeActivoId: viajeActivoId,
          proximoMantenimientoOdometro: proxMant,
        );

    test('en ruta cuando tiene viaje activo', () {
      expect(unidad(viajeActivoId: 'v1').enRuta, isTrue);
      expect(unidad(viajeActivoId: '').enRuta, isFalse);
      expect(unidad().enRuta, isFalse);
    });

    test('disponible = activa y sin viaje', () {
      expect(unidad().estaActiva, isTrue);
      expect(unidad(estado: EstadoUnidad.mantenimiento).estaActiva, isFalse);
    });

    test('requiere servicio si faltan <500 km para el próximo', () {
      expect(unidad(odometro: 99600, proxMant: 100000).requiereServicio, isTrue);
      expect(unidad(odometro: 95000, proxMant: 100000).requiereServicio, isFalse);
      expect(unidad(proxMant: null).requiereServicio, isFalse);
    });
  });
}
