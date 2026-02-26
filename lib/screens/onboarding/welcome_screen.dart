import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/ferri_logo.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onNext;

  const WelcomeScreen({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),
            const FerriLogo(size: 120),
            const SizedBox(height: 32),
            const Text(
              'Meet Ferri',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: FerriColors.text,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your AI agent. Inside your phone.',
              style: TextStyle(
                fontSize: 16,
                color: FerriColors.textSoft,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ferri runs a full AI agent inside your phone. '
              'It can read your calendar, check your health data, '
              'scan documents, search the web, and act on all of it '
              '-- from a single conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: FerriColors.textSoft,
                height: 1.5,
              ),
            ),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [FerriColors.primary, FerriColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
