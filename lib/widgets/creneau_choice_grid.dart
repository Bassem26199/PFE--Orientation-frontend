import 'package:flutter/material.dart';

class CreneauChoiceGrid extends StatelessWidget {
  final List<Map<String, dynamic>> creneaux;
  final String? selectedHeure;
  final ValueChanged<String> onHeureSelected;

  const CreneauChoiceGrid({
    super.key,
    required this.creneaux,
    required this.selectedHeure,
    required this.onHeureSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: creneaux.length,
      itemBuilder: (context, index) {
        final slot = creneaux[index];
        final heure = slot['heure']?.toString() ?? '';
        final label = slot['label']?.toString() ?? heure.substring(0, 5);
        final disponible = slot['disponible'] != false && slot['occupe'] != true;
        final selected = selectedHeure == heure;

        return ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              color: disponible
                  ? (selected ? Colors.white : Colors.black87)
                  : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: selected && disponible,
          selectedColor: Colors.green.shade600,
          backgroundColor: disponible ? null : Colors.red.shade400,
          disabledColor: Colors.red.shade300,
          onSelected: disponible ? (_) => onHeureSelected(heure) : null,
        );
      },
    );
  }
}
