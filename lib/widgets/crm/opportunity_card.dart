import 'package:flutter/material.dart';

class OpportunityCard extends StatelessWidget {
  final String partnerName;
  final String opportunityName; // "name"
  final double expectedRevenue;
  final double probability; // 0-100

  const OpportunityCard({
    super.key,
    required this.partnerName,
    required this.opportunityName,
    required this.expectedRevenue,
    required this.probability,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cliente
            Text(
              partnerName.isEmpty ? 'Cliente desconocido' : partnerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            // Nombre de la Oportunidad
            Text(
              opportunityName,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            // Monto y Probabilidad
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Barra de probabilidad
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Probabilidad: ${probability.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: probability / 100,
                        backgroundColor: Colors.grey[200],
                        color: _getProbabilityColor(probability),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Monto
                Text(
                  '\$ ${expectedRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getProbabilityColor(double prob) {
    if (prob < 30) return Colors.red;
    if (prob < 70) return Colors.amber;
    return Colors.green;
  }
}
