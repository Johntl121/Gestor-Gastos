import 'package:flutter/material.dart';

class GoalCard extends StatelessWidget {
  final String name;
  final double currentAmount;
  final double targetAmount;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const GoalCard({
    super.key,
    required this.name,
    required this.currentAmount,
    required this.targetAmount,
    required this.color,
    required this.icon,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentAmount / targetAmount).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();
    final isCompleted = progress >= 1.0;

    // Colores para el estado normal vs completado
    final displayColor = isCompleted
        ? const Color(0xFFFFD700)
        : color; // Oro brillante si completado

    // Base dark color
    const baseColor = Color(0xFF1E2435);
    // Subtle tint mix
    final tintColor =
        Color.alphaBlend(displayColor.withValues(alpha: 0.08), baseColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(24),
        border: isCompleted
            ? Border.all(color: const Color(0xFFFFD700), width: 2.0)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, tintColor],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header: Icon + Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: displayColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCompleted ? Icons.emoji_events : icon,
                            color: displayColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Body: Amounts + Large Percentage
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "S/ ${currentAmount.toStringAsFixed(0)} / S/ ${targetAmount.toStringAsFixed(0)}",
                          style: TextStyle(
                            color:
                                isCompleted ? displayColor : Colors.grey[400],
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "$percentage%",
                          style: TextStyle(
                            color: displayColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Footer: Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: Colors.black26,
                        valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                      ),
                    ),

                    // Mensaje de Victoria
                    if (isCompleted) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star,
                              color: Color(0xFFFFD700), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "¡Meta Alcanzada!",
                            style: TextStyle(
                              color: displayColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.star,
                              color: Color(0xFFFFD700), size: 18),
                        ],
                      )
                    ]
                  ],
                ),
              ),

              // Menu (Top Right)
              Positioned(
                top: 8,
                right: 4,
                child: _buildActionMenu(context),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: 20, color: Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: const Color(0xFF1E293B), // Dark menu background
      onSelected: (value) {
        if (value == 'edit' && onEdit != null) onEdit!();
        if (value == 'delete' && onDelete != null) onDelete!();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 10),
              Text("Editar", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.redAccent, size: 20),
              SizedBox(width: 10),
              Text("Eliminar", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}
