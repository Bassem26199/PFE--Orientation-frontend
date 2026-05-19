import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'medecin_home.dart';
import '../services/auth_service.dart';
import '../services/medecin_service.dart';
import '../widgets/doctors_map_view.dart';
import 'patient_home.dart';
import 'secretaire_home.dart';
import 'register_screen.dart';
import 'login_screen.dart';
import 'analyser_symptomes_screen.dart';
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  List<Map<String, dynamic>> mapDoctors = [];
  bool mapLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMapDoctors();
  }

  Future<void> _loadMapDoctors() async {
    setState(() => mapLoading = true);
    try {
      final list = await MedecinService.fetchMedecins();
      if (mounted) {
        setState(() {
          mapDoctors = list;
          mapLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => mapLoading = false);
      }
    }
  }

  final List<Map<String, dynamic>> posts = [
    {
      "titre": "Quand consulter rapidement ?",
      "texte":
          "Douleur thoracique, essoufflement important ou malaise nécessitent une consultation rapide.",
      "image":
          "https://images.unsplash.com/photo-1584515933487-779824d29309?w=900",
      "icon": Icons.warning_amber_rounded,
    },
    {
      "titre": "Hydratation",
      "texte":
          "Boire suffisamment d’eau aide le corps à fonctionner correctement.",
      "image":
          "https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=900",
      "icon": Icons.water_drop,
    },
    {
      "titre": "Sommeil",
      "texte": "Un sommeil régulier améliore la récupération et le bien-être.",
      "image":
          "https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=900",
      "icon": Icons.bedtime,
    },
    {
      "titre": "Orientation médicale",
      "texte":
          "L’application aide à identifier une spécialité adaptée selon les symptômes.",
      "image":
          "https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=900",
      "icon": Icons.health_and_safety,
    },
  ];

  void goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void goToRegisterInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void goToUserSpace() {
    final role = AuthService.currentUser?["role"];

    if (role == "PATIENT") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PatientHome()),
      );
      return;
    }

    if (role == "SECRETAIRE") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SecretaireHome()),
      );
      return;
    }

    if (role == "MEDECIN") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MedecinHome()),
      );
      return;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    if (mounted) setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Déconnexion réussie")),
    );
  }

  String get _spaceLabel {
    final role = AuthService.currentUser?["role"];
    switch (role) {
      case "MEDECIN":
        return "Espace médecin";
      case "SECRETAIRE":
        return "Espace secrétaire";
      default:
        return "Espace patient";
    }
  }

  Future<void> openEmergencyInfo() async {
    final url = Uri.parse(
      "https://www.google.com/search?q=urgence+m%C3%A9dicale",
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget animatedItem(Widget child, {int delay = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 550 + delay),
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 28 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget postCard(Map<String, dynamic> p) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Image.network(
              p["image"],
              height: 125,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 125,
                color: Colors.blue.shade50,
                child: Icon(p["icon"], color: Colors.blue, size: 46),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(p["icon"], color: Colors.blue),
                const SizedBox(height: 8),
                Text(
                  p["titre"],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p["texte"],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget mapPreview() {
    if (mapLoading) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(26),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    return DoctorsMapView(doctors: mapDoctors, height: 260);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              animatedItem(
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.local_hospital,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "Orientation Médicale Intelligente",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Symptômes, médecins, conseils, avis et localisation dans une seule application.",
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(height: 20),

                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 58,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.health_and_safety,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AnalyserSymptomesScreen(),
                                        ),
                                      );
                                    },
                                    label: const Text(
                                      "Analyser",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 58,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                      ),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: Icon(
                                      AuthService.isLoggedIn
                                          ? Icons.space_dashboard_outlined
                                          : Icons.login,
                                      size: 22,
                                    ),
                                    onPressed: AuthService.isLoggedIn
                                        ? goToUserSpace
                                        : goToLogin,
                                    label: Text(
                                      AuthService.isLoggedIn
                                          ? _spaceLabel
                                          : "Se connecter",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: AuthService.isLoggedIn
                                  ? logout
                                  : goToRegisterInfo,
                              icon: Icon(
                                AuthService.isLoggedIn
                                    ? Icons.logout
                                    : Icons.person_add_alt_1,
                              ),
                              label: Text(
                                AuthService.isLoggedIn
                                    ? "Se déconnecter"
                                    : "Créer un compte patient",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                "Accès rapide",
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.medical_information,
                    color: Colors.blue,
                  ),
                  title: const Text("Analyser mes symptômes"),
                  subtitle: const Text("Obtenir une spécialité recommandée."),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnalyserSymptomesScreen(),
                      ),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: const Text("Informations d’urgence"),
                  subtitle: const Text(
                    "Accès rapide à des informations générales.",
                  ),
                  onTap: openEmergencyInfo,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "Conseils et actualités médicales",
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 285,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: posts.map(postCard).toList(),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                "Carte des médecins",
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              
              const SizedBox(height: 14),
              mapPreview(),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: const Text(
                  "Cette application propose une orientation indicative et ne remplace pas une consultation médicale. "
                  "En cas d’urgence, contactez les services médicaux compétents.",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}