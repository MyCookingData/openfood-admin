import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/glass_container.dart';

class RestoInventoryTab extends StatelessWidget {
  final RestaurantModel restaurant;
  const RestoInventoryTab({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final padding = isMobile ? 14.0 : 24.0;

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestion de l\'Inventaire (Stock Synchronisé)',
                style: TextStyle(color: Colors.white, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Les modifications ici impactent tous les plats qui utilisent cet article en option.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('inventory_items')
                      .where('restaurantId', whereIn: [restaurant.id, restaurant.name])
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const GlassContainer(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text("Aucun article dans l'inventaire pour ce restaurant.", style: TextStyle(color: Colors.white54))),
                      );
                    }
                    
                    final items = snapshot.data!.docs;
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white12),
                      itemBuilder: (context, index) {
                        final doc = items[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'Inconnu';
                        final isAvailable = data['isAvailable'] ?? true;
                        
                        return GlassContainer(
                          padding: const EdgeInsets.all(12),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12),
                            leading: Icon(
                              Icons.inventory_2, 
                              color: isAvailable ? AppTheme.emeraldGreen : Colors.redAccent,
                              size: isMobile ? 26 : 32,
                            ),
                            title: Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isMobile ? 15 : 18)),
                            subtitle: Text(isAvailable ? 'En stock' : 'Rupture de stock', style: TextStyle(color: isAvailable ? AppTheme.emeraldGreen : Colors.redAccent, fontSize: isMobile ? 12 : 14)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isMobile)
                                  const Text('Disponibilité : ', style: TextStyle(color: Colors.white70)),
                                Switch(
                                  value: isAvailable,
                                  activeThumbColor: AppTheme.emeraldGreen,
                                  onChanged: (val) async {
                                    // 1. Update Inventory Item
                                    await FirebaseFirestore.instance.collection('inventory_items').doc(doc.id).update({'isAvailable': val});

                                    // 2. Sync to products
                                    final prods = await FirebaseFirestore.instance.collection('products')
                                        .where('restaurantId', whereIn: [restaurant.id, restaurant.name])
                                        .get();
                                    
                                    final batch = FirebaseFirestore.instance.batch();
                                    
                                    for (var pDoc in prods.docs) {
                                      final pData = pDoc.data();
                                      pData['id'] = pDoc.id;
                                      final product = ProductModel.fromJson(pData);
                                      
                                      bool changed = false;
                                      final newGroups = <ProductModifierGroup>[];
                                      
                                      for (var group in product.modifierGroups) {
                                        final newOpts = <ProductModifierOption>[];
                                        for (var opt in group.options) {
                                          if (opt.linkedInventoryItemId == doc.id && opt.isAvailable != val) {
                                            newOpts.add(ProductModifierOption(
                                              id: opt.id,
                                              name: opt.name,
                                              extraPrice: opt.extraPrice,
                                              isAvailable: val, // Sync state
                                              linkedInventoryItemId: opt.linkedInventoryItemId,
                                            ));
                                            changed = true;
                                          } else {
                                            newOpts.add(opt);
                                          }
                                        }
                                        newGroups.add(ProductModifierGroup(
                                          id: group.id,
                                          name: group.name,
                                          minSelections: group.minSelections,
                                          maxSelections: group.maxSelections,
                                          options: newOpts,
                                        ));
                                      }
                                      
                                      if (changed) {
                                        batch.update(pDoc.reference, {
                                          'modifierGroups': newGroups.map((e) => e.toJson()).toList(),
                                        });
                                      }
                                    }
                                    
                                    await batch.commit();
                                  },
                                ),
                              ],
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
      },
    );
  }
}
