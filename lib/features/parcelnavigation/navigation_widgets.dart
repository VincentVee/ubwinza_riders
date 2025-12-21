// lib/navigation/navigation_widgets.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TurnArrow extends StatelessWidget {
  final String maneuver;

  const TurnArrow({super.key, required this.maneuver});

  IconData getIcon() {
    switch (maneuver) {
      case "turn-left":
        return Icons.turn_left;
      case "turn-right":
        return Icons.turn_right;
      case "uturn-left":
      case "uturn-right":
        return Icons.u_turn_left;
      case "fork-left":
        return Icons.turn_slight_left;
      case "fork-right":
        return Icons.turn_slight_right;
      default:
        return Icons.straight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      getIcon(),
      size: 70,
      color: Colors.blueAccent,
    );
  }
}

// --------------------------------------------------------
// HIGHWAY SHIELD WIDGET (T2, M9, T4)
// --------------------------------------------------------

class HighwayShield extends StatelessWidget {
  final String code;

  const HighwayShield({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    if (code.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// TOP INSTRUCTION BANNER
// --------------------------------------------------------

class InstructionBanner extends StatelessWidget {
  final String instruction;
  final Widget? arrow;
  final Widget? shield;

  const InstructionBanner({
    super.key,
    required this.instruction,
    this.arrow,
    this.shield,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          if (arrow != null) arrow!,
          if (shield != null) const SizedBox(height: 4),
          if (shield != null) shield!,
          const SizedBox(height: 8),
          Text(
            instruction,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------
// ETA + DISTANCE BOTTOM CARD
// --------------------------------------------------------

class EtaBottomCard extends StatelessWidget {
  final String eta;
  final String distance;

  const EtaBottomCard({
    super.key,
    required this.eta,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ETA + Distance
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eta,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text("Distance: $distance"),
              ],
            ),

            // Arrival time (optional)
            Text(
              "--:--",
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade700,
              ),
            )
          ],
        ),
      ),
    );
  }
}
