import 'package:flutter/material.dart';

/// Limite la largeur du contenu sur grand écran (navigateur web, tablette paysage).
class ResponsiveContent extends StatelessWidget {
  static const double patientDashboardMaxWidth = 1000;
  static const double patientListMaxWidth = 720;

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = patientDashboardMaxWidth,
    this.padding = const EdgeInsets.all(16),
    this.alignment = Alignment.topCenter,
  });

  const ResponsiveContent.list({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  })  : maxWidth = patientListMaxWidth,
        alignment = Alignment.topCenter;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Grille de menu patient : cartes de taille raisonnable sur web et mobile.
class PatientMenuGrid extends StatelessWidget {
  final List<Widget> children;

  const PatientMenuGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxExtent = width >= 900 ? 200.0 : (width >= 600 ? 220.0 : 280.0);
        final aspectRatio = width >= 600 ? 1.08 : 1.35;

        return GridView.extent(
          maxCrossAxisExtent: maxExtent,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: aspectRatio,
          children: children,
        );
      },
    );
  }
}

/// Carte d'action du tableau de bord patient.
class PatientDashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const PatientDashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.blue),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
