import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../../core/constants/app_onboarding_data.dart';

class WelcomeStep extends StatelessWidget {
  final TextEditingController nameController;
  final String selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;
  final File? profileImage;
  final String selectedAvatar;
  final VoidCallback onAvatarTap;

  const WelcomeStep({
    super.key,
    required this.nameController,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    required this.profileImage,
    required this.selectedAvatar,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildAvatarPicker(isDark),
          const SizedBox(height: 40),
          Text(
            "Bienvenido",
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Configura tu identidad financiera para empezar.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 50),
          _buildNameField(colorScheme),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Moneda Principal",
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildCurrencySelector(isDark),
        ],
      ),
    );
  }

  Widget _buildAvatarPicker(bool isDark) {
    return GestureDetector(
      onTap: onAvatarTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 4,
                )
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : Colors.grey[200],
              backgroundImage:
                  profileImage != null ? FileImage(profileImage!) : null,
              child: profileImage == null
                  ? Text(selectedAvatar, style: const TextStyle(fontSize: 50))
                  : null,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF00E5FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit, color: Colors.black, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(ColorScheme colorScheme) {
    return TextFormField(
      controller: nameController,
      style: TextStyle(fontSize: 18, color: colorScheme.onSurface),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.badge,
            color: colorScheme.onSurface.withValues(alpha: 0.5)),
        hintText: "¿Cómo te llamas?",
        hintStyle:
            TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
        filled: true,
        fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCurrencySelector(bool isDark) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        scrollDirection: Axis.horizontal,
        itemCount: AppOnboardingData.currencies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final currency = AppOnboardingData.currencies[index];
          final isSelected = selectedCurrency == currency['symbol'];

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onCurrencyChanged(currency['symbol']!);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isDark
                        ? Colors.grey.withValues(alpha: 0.1)
                        : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 0,
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currency['symbol']!,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currency['name']!,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
