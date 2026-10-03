import 'package:flutter/material.dart';

class BotonAlerta extends StatelessWidget {
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback? onTap;

  const BotonAlerta({
    super.key,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$titulo. $subtitulo',
    child: SizedBox(
      width: double.infinity,
      height: 96,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(subtitulo, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    ),
  );
}
