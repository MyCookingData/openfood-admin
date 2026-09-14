import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';
import 'package:openfood_models/openfood_models.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  String? _selectedRestaurantId;

  void _showAddInventoryItemDialog(BuildContext context, String restaurantId) {
    showDialog(
      context: context,
      builder: (context) => _AddInventoryItemDialog(restaurantId: restaurantId),
    );
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
                'Inventaire Global',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_selectedRestaurantId != null)
                ElevatedButton.icon(
                  onPressed: () => _showAddInventoryItemDialog(context, _selectedRestaurantId!),
                  icon: const Icon(Icons.add),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldGreen,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('Nouvel Article'),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _runMigration(context),
                icon: const Icon(Icons.sync),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                label: const Text('Migrer Options'),
              )
            ],
          ),
          const SizedBox(height: 24),
          // Restaurant selector
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('Aucun restaurant trouvé', style: TextStyle(color: Colors.white54));
              }

              final restaurants = snapshot.data!.docs;
              if (_selectedRestaurantId == null && restaurants.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() => _selectedRestaurantId = restaurants.first.id);
                });
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRestaurantId,
                    dropdownColor: AppTheme.darkBackground,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.emeraldGreen),
                    isExpanded: true,
                    items: restaurants.map((doc) {
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(doc['name'] ?? 'Restaurant Inconnu'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRestaurantId = val);
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _selectedRestaurantId == null
                ? const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('inventory_items')
                        .where('restaurantId', isEqualTo: _selectedRestaurantId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const GlassContainer(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Aucun article en inventaire pour ce restaurant.', style: TextStyle(color: Colors.white70, fontSize: 18)),
                          ),
                        );
                      }

                      final items = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        data['id'] = doc.id;
                        return InventoryItemModel.fromJson(data);
                      }).toList();

                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 250,
                          mainAxisExtent: 150,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                      onPressed: () {
                                        FirebaseFirestore.instance.collection('inventory_items').doc(item.id).delete();
                                      },
                                    )
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.isAvailable ? 'En Stock' : 'Rupture',
                                      style: TextStyle(
                                        color: item.isAvailable ? AppTheme.emeraldGreen : Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Switch(
                                      value: item.isAvailable,
                                      activeThumbColor: AppTheme.emeraldGreen,
                                      onChanged: (val) async {
                                        // 1. Update Inventory Item
                                        await FirebaseFirestore.instance.collection('inventory_items').doc(item.id).update({'isAvailable': val});
                                        
                                        // 2. Sync to all products containing this linkedInventoryItemId
                                        final prods = await FirebaseFirestore.instance.collection('products')
                                            .where('restaurantId', isEqualTo: _selectedRestaurantId)
                                            .get();
                                        
                                        for (var doc in prods.docs) {
                                          final data = doc.data();
                                          data['id'] = doc.id;
                                          final product = ProductModel.fromJson(data);
                                          
                                          bool changed = false;
                                          final newGroups = <ProductModifierGroup>[];
                                          for (var group in product.modifierGroups) {
                                            final newOpts = <ProductModifierOption>[];
                                            for (var opt in group.options) {
                                              if (opt.linkedInventoryItemId == item.id && opt.isAvailable != val) {
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
                                            await FirebaseFirestore.instance.collection('products').doc(doc.id).update({
                                              'modifierGroups': newGroups.map((e) => e.toJson()).toList(),
                                            });
                                          }
                                        }
                                      },
                                    )
                                  ],
                                ),
                              ],
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

  Future<void> _runMigration(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final restaurants = await FirebaseFirestore.instance.collection('restaurants').get();
      
      for (var rDoc in restaurants.docs) {
        final rId = rDoc.id;
        final rName = rDoc.data()['name']?.toString() ?? 'Inconnu';

        final pSnap = await FirebaseFirestore.instance.collection('products')
            .where('restaurantId', whereIn: [rId, rName])
            .get();
        
        // Cache inventory items by name
        final iSnap = await FirebaseFirestore.instance.collection('inventory_items')
            .where('restaurantId', whereIn: [rId, rName])
            .get();
        
        final inventoryByName = <String, String>{};
        for (var iDoc in iSnap.docs) {
          inventoryByName[iDoc.data()['name']] = iDoc.id;
        }

        for (var pDoc in pSnap.docs) {
          final data = pDoc.data();
          data['id'] = pDoc.id;
          final product = ProductModel.fromJson(data);

          bool changed = false;
          final newGroups = <ProductModifierGroup>[];

          for (var group in product.modifierGroups) {
            final newOpts = <ProductModifierOption>[];
            for (var opt in group.options) {
              String? invId = opt.linkedInventoryItemId;

              if (invId == null) {
                // Check if an inventory item already exists
                if (inventoryByName.containsKey(opt.name)) {
                  invId = inventoryByName[opt.name];
                } else {
                  // Create it
                  final newRef = FirebaseFirestore.instance.collection('inventory_items').doc();
                  await newRef.set({
                    'id': newRef.id,
                    'restaurantId': rId, // Use the correct ID
                    'name': opt.name,
                    'isAvailable': opt.isAvailable,
                  });
                  invId = newRef.id;
                  inventoryByName[opt.name] = invId;
                }
                changed = true;
              }

              newOpts.add(ProductModifierOption(
                id: opt.id,
                name: opt.name,
                extraPrice: opt.extraPrice,
                isAvailable: opt.isAvailable,
                linkedInventoryItemId: invId,
              ));
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
            await FirebaseFirestore.instance.collection('products').doc(pDoc.id).update({
              'modifierGroups': newGroups.map((e) => e.toJson()).toList(),
            });
          }
        }
      }
      if (context.mounted) Navigator.pop(context); // Close loading
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Migration terminée avec succès !', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    }
  }
}

class _AddInventoryItemDialog extends StatefulWidget {
  final String restaurantId;
  const _AddInventoryItemDialog({required this.restaurantId});

  @override
  State<_AddInventoryItemDialog> createState() => _AddInventoryItemDialogState();
}

class _AddInventoryItemDialogState extends State<_AddInventoryItemDialog> {
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('inventory_items').doc();
      final newItem = InventoryItemModel(
        id: docRef.id,
        restaurantId: widget.restaurantId,
        name: _nameCtrl.text.trim(),
        isAvailable: true,
      );
      await docRef.set(newItem.toJson());
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkBackground,
      title: const Text('Nouvel Article', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _nameCtrl,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'Nom de l\'article (ex: Coca Cola 33cl)',
          labelStyle: TextStyle(color: Colors.white54),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.emeraldGreen)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Ajouter'),
        ),
      ],
    );
  }
}

