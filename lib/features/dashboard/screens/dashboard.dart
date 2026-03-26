import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Tableau de bord',
          style: GoogleFonts.urbanist(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue dans Gestion Locative',
              style: GoogleFonts.urbanist(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Gérez vos biens, locataires et paiements',
              style: GoogleFonts.urbanist(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Biens',
                    amount: 3,
                    color: Colors.blue,
                    icon: Icons.apartment,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SummaryCard(
                    title: 'Locataires',
                    amount: 2,
                    color: Colors.green,
                    icon: Icons.people,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Loyers perçus',
                    amount: 2500,
                    color: Colors.orange,
                    icon: Icons.euro,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SummaryCard(
                    title: 'En attente',
                    amount: 850,
                    color: Colors.red,
                    icon: Icons.pending,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}