import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/patient_prochain_rdv_banner.dart';
import '../widgets/responsive_content.dart';
import 'analyser_symptomes_screen.dart';
import 'mes_rendezvous_screen.dart';
import 'historique_orientation_screen.dart';
import 'mes_ordonnances_screen.dart';
import 'mon_profil_screen.dart';
import 'public_navigation_screen.dart';

class PatientHome extends StatelessWidget {
  const PatientHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace Patient'),
        actions: [
          IconButton(
            tooltip: 'Accueil public',
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PublicNavigationScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenue, ${AuthService.displayName} 👋',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gérez votre orientation médicale facilement.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const PatientProchainRdvBanner(),
            const SizedBox(height: 8),
            Expanded(
              child: PatientMenuGrid(
                children: [
                  PatientDashboardCard(
                    icon: Icons.health_and_safety,
                    title: 'Analyser symptômes',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AnalyserSymptomesScreen(),
                        ),
                      );
                    },
                  ),
                  PatientDashboardCard(
                    icon: Icons.calendar_month,
                    title: 'Mes rendez-vous',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MesRendezVousScreen(),
                        ),
                      );
                    },
                  ),
                  PatientDashboardCard(
                    icon: Icons.history,
                    title: 'Historique',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoriqueOrientationScreen(),
                        ),
                      );
                    },
                  ),
                  PatientDashboardCard(
                    icon: Icons.receipt_long,
                    title: 'Mes ordonnances',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MesOrdonnancesScreen(),
                        ),
                      );
                    },
                  ),
                  PatientDashboardCard(
                    icon: Icons.person,
                    title: 'Mon profil',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MonProfilScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
