import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Logo "A" dengan efek neon ungu — dipakai di Home dan halaman Tentang.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.neonPurple, AppColors.neonPurpleLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPurpleLight.withOpacity(0.55),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.neonPurple.withOpacity(0.35),
            blurRadius: 48,
            spreadRadius: 6,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'A',
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}
