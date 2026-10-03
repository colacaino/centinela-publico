// ===== Definición de roles y reglas de recepción de alertas =====

// Los cuatro roles disponibles en CENTINELA.
class Roles {
  static const String admin = 'admin';
  static const String direccion = 'direccion';
  static const String inspector = 'inspector';
  static const String docente = 'docente';

  // Lista usada por el selector del formulario de administración.
  static const List<String> todos = [admin, direccion, inspector, docente];

  // Etiqueta legible para mostrar en la interfaz.
  static String etiqueta(String rol) {
    switch (rol) {
      case admin:
        return 'Administrador';
      case direccion:
        return 'Dirección';
      case inspector:
        return 'Inspector';
      case docente:
        return 'Docente';
      default:
        return rol;
    }
  }

  // Indica si un rol es "receptor" de alertas (ve la pantalla de recepción).
  static bool esReceptor(String rol) {
    return rol == admin || rol == direccion || rol == inspector;
  }

  // Reglas de filtrado: ¿este rol debe RECIBIR una alerta de este nivel?
  //   Nivel 1 (médica)        -> inspector y admin
  //   Nivel 2 (riña/intruso)  -> inspector, direccion y admin
  //   Nivel 3 (arma)          -> inspector, direccion y admin
  static bool recibeNivel(String rol, String nivel) {
    switch (nivel) {
      case '1':
        return rol == inspector || rol == admin;
      case '2':
      case '3':
        return rol == inspector || rol == direccion || rol == admin;
      default:
        return false;
    }
  }

  static List<String> nivelesParaRol(String rol) {
    if (rol == inspector || rol == admin) return const ['1', '2', '3'];
    if (rol == direccion) return const ['2', '3'];
    return const [];
  }
}
