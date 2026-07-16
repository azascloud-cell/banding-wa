import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Logo AZZA BIO X RED — tampil sebagai image asset dengan glow ungu.
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
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPurple.withOpacity(0.55),
            blurRadius: 32,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: AppColors.neonPurpleLight.withOpacity(0.3),
            blurRadius: 56,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/app_icon.jpg',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.neonGradient,
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
          ),
        ),
      ),
    );
  }
}
