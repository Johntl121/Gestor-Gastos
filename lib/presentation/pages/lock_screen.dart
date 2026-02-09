import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';

/// LockScreen: Bloquea el acceso a la app hasta validar el PIN.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _inputPin = "";

  @override
  void initState() {
    super.initState();
  }

  void _onKeyPress(String val) {
    if (val == 'DEL') {
      if (_inputPin.isNotEmpty) {
        setState(
            () => _inputPin = _inputPin.substring(0, _inputPin.length - 1));
      }
      return;
    }

    if (_inputPin.length < 4) {
      setState(() {
        _inputPin += val;
      });

      // Auto-validate check must happen AFTER the update
      if (_inputPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 150), () {
          _validatePin();
        });
      }
    }
  }

  void _validatePin() {
    if (!mounted) return;
    final provider = Provider.of<DashboardProvider>(context, listen: false);

    // Verify
    if (provider.verifyPin(_inputPin)) {
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PIN Incorrecto"),
          backgroundColor: Colors.redAccent,
          duration: Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(top: 50, left: 20, right: 20),
        ),
      );
      setState(() => _inputPin = "");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        Provider.of<DashboardProvider>(context, listen: false).isDarkMode;
    final backgroundColor =
        isDarkMode ? const Color(0xFF15202B) : const Color(0xFFF5F7FA);
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            const Icon(Icons.lock_outline, size: 60, color: Colors.cyan),
            const SizedBox(height: 20),
            Text("Gestor de Gastos",
                style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Ingresa tu PIN",
                style: TextStyle(
                    color: isDarkMode ? Colors.grey : Colors.blueGrey)),
            const Spacer(),

            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _inputPin.length
                          ? Colors.cyan
                          : (isDarkMode ? Colors.white10 : Colors.black12),
                      border: Border.all(
                          color: index < _inputPin.length
                              ? Colors.transparent
                              : Colors.grey.withOpacity(0.5))),
                );
              }),
            ),

            const Spacer(flex: 2),

            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3'], textColor, isDarkMode),
                  const SizedBox(height: 20),
                  _buildRow(['4', '5', '6'], textColor, isDarkMode),
                  const SizedBox(height: 20),
                  _buildRow(['7', '8', '9'], textColor, isDarkMode),
                  const SizedBox(height: 20),
                  _buildRow(['', '0', 'DEL'], textColor, isDarkMode),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys, Color textColor, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox(width: 70, height: 70);

        return SizedBox(
          width: 70,
          height: 70,
          child: TextButton(
            onPressed: () => _onKeyPress(key),
            style: TextButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor:
                  isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
              elevation: 0,
            ),
            child: key == 'DEL'
                ? Icon(Icons.backspace_outlined, color: textColor)
                : Text(key,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
          ),
        );
      }).toList(),
    );
  }
}
