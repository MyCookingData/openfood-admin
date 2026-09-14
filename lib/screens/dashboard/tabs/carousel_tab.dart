import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import 'package:openfood_models/openfood_models.dart';
import 'carousel_dialog.dart';

class CarouselTab extends StatefulWidget {
  const CarouselTab({super.key});

  @override
  State<CarouselTab> createState() => _CarouselTabState();
}

class _CarouselTabState extends State<CarouselTab> {
  void _showAddCarouselDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CarouselDialog(),
    );
  }

  void _showEditCarouselDialog(BuildContext context, CarouselModel carousel) {
    showDialog(
      context: context,
      builder: (context) => CarouselDialog(carousel: carousel),
    );
  }

  Future<void> _deleteCarousel(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkBackground,
        title: const Text('Confirmer la suppression', style: TextStyle(color: Colors.white)),
        content: const Text('Voulez-vous vraiment supprimer cette bannière ?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('carousels').doc(id).delete();
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex, List<CarouselModel> carousels) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    final item = carousels.removeAt(oldIndex);
    carousels.insert(newIndex, item);
    
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < carousels.length; i++) {
      final docRef = FirebaseFirestore.instance.collection('carousels').doc(carousels[i].id);
      batch.update(docRef, {'sortOrder': i});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bannières Accueil',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCarouselDialog(context),
                icon: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.white,
                ),
                label: const Text('Nouvelle Bannière'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('carousels').orderBy('sortOrder', descending: false).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Aucune bannière trouvée.', style: TextStyle(color: Colors.white70, fontSize: 18)),
                  );
                }

                final carousels = snapshot.data!.docs.map((doc) => CarouselModel.fromFirestore(doc)).toList();

                return ReorderableListView.builder(
                  onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, List.from(carousels)),
                  itemCount: carousels.length,
                  itemBuilder: (context, index) {
                    final carousel = carousels[index];

                    return Card(
                      key: ValueKey(carousel.id),
                      color: AppTheme.lighterDarkBackground,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: carousel.isActive ? AppTheme.emeraldGreen.withValues(alpha: 0.5) : Colors.redAccent.withValues(alpha: 0.5))),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: carousel.imageUrl != null && carousel.imageUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(carousel.imageUrl!),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken),
                                )
                              : null,
                          gradient: (carousel.imageUrl == null || carousel.imageUrl!.isEmpty) && carousel.gradientColorsHex.isNotEmpty
                              ? LinearGradient(
                                  colors: carousel.gradientColorsHex.map((c) => Color(int.parse(c.replaceAll('#', '0xFF')))).toList(),
                                )
                              : null,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: carousel.logoUrl != null && carousel.logoUrl!.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(carousel.logoUrl!, width: 40, height: 40, fit: BoxFit.cover))
                              : Text(
                                  carousel.emoji,
                                  style: const TextStyle(fontSize: 40),
                                ),
                          title: Row(
                            children: [
                              Text(carousel.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                              const SizedBox(width: 8),
                              if (!carousel.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Inactif', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              if (carousel.isSponsored)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Sponsorisé', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  carousel.subtitle,
                                  style: const TextStyle(color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                ),
                                const SizedBox(height: 4),
                                Text('Action: ${carousel.actionType.name} ${carousel.actionPayload != null ? '(${carousel.actionPayload})' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 12, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white),
                                onPressed: () => _showEditCarouselDialog(context, carousel),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _deleteCarousel(carousel.id),
                              ),
                              const Icon(Icons.drag_handle, color: Colors.white54),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
