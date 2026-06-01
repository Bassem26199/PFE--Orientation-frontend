import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'analyser_symptomes_screen.dart';
import 'mes_rendezvous_screen.dart';
import 'historique_orientation_screen.dart';
import 'mes_ordonnances_screen.dart';
import 'mon_profil_screen.dart';
import 'public_navigation_screen.dart';
import '../widgets/patient_prochain_rdv_banner.dart';

class PatientHome extends StatelessWidget {
  const PatientHome({super.key});

  Widget buildCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: Colors.blue),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Espace Patient"),
        actions: [
          IconButton(
            tooltip: "Accueil",
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bienvenue, ${AuthService.displayName} 👋",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Gérez votre orientation médicale facilement.",
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const PatientProchainRdvBanner(),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  buildCard(
                    icon: Icons.health_and_safety,
                    title: "Analyser symptômes",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AnalyserSymptomesScreen(),
                        ),
                      );
                    },
                  ),
                  buildCard(
                    icon: Icons.calendar_month,
                    title: "Mes rendez-vous",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MesRendezVousScreen(),
                        ),
                      );
                    },
                  ),
                  buildCard(
                    icon: Icons.history,
                    title: "Historique",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoriqueOrientationScreen(),
                        ),
                      );
                    },
                  ),
                  buildCard(
                    icon: Icons.receipt_long,
                    title: "Mes ordonnances",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MesOrdonnancesScreen(),
                        ),
                      );
                    },
                  ),
                  buildCard(
                    icon: Icons.person,
                    title: "Mon profil",
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