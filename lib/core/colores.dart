import 'package:flutter/material.dart';

// ===== Paleta de colores de CENTINELA =====
// Se mantienen los colores originales de la app.
class Colores {
  // Colores por nivel de alerta
  static const Color amarillo = Color(0xFFE8A100); // Nivel 1 · Médica
  static const Color naranjo = Color(0xFFD9560B); // Nivel 2 · Riña/Intruso
  static const Color rojo = Color(0xFF990011); // Nivel 3 · Riesgo vital

  // Color de fondo general
  static const Color fondo = Color(0xFFF5F5F7);

  // Devuelve el color que corresponde a un nivel de alerta ('1', '2', '3')
  static Color porNivel(String nivel) {
    switch (nivel) {
      case '1':
        return amarillo;
      case '2':
        return naranjo;
      case '3':
        return rojo;
      default:
        return rojo;
    }
  }
}
