import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/glass_container.dart';

class RestoMenuTab extends StatelessWidget {
  final RestaurantModel restaurant;
  const RestoMenuTab({super.key, required this.restaurant});

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ProductDialog(restaurant: restaurant),
    );
  }

  void _showEditProductDialog(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (_) => _ProductDialog(restaurant: restaurant, product: product),
    );
  }

  Future<void> _duplicateProduct(BuildContext context, ProductModel product) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('products').doc();
      final duplicate = ProductModel(
        id: docRef.id,
        restaurantId: product.restaurantId,
        restaurantName: product.restaurantName,
        category: product.category,
        name: '${product.name} (Copie)',
        description: product.description,
        image: product.image,
        priceHT: product.priceHT,
        vatRate: product.vatRate,
        badgeText: product.badgeText,
        isAvailable: product.isAvailable,
        linkedInventoryItemId: product.linkedInventoryItemId,
        modifierGroups: product.modifierGroups,
      );
      await docRef.set(duplicate.toJson());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit dupliqué avec succès', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.emeraldGreen));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Menu & Plats', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                onPressed: () => _showAddProductDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter Plat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products')
                  .where('restaurantId', whereIn: [restaurant.id, restaurant.name])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const GlassContainer(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text("Aucun plat configuré pour ce restaurant.", style: TextStyle(color: Colors.white54))),
                  );
                }

                final products = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return ProductModel.fromJson(data);
                }).toList();

                // On regroupe par catégorie
                final grouped = <String, List<ProductModel>>{};
                for (var p in products) {
                  grouped.putIfAbsent(p.category, () => []).add(p);
                }

                return ListView.builder(
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    final category = grouped.keys.elementAt(index);
                    final catProducts = grouped[category]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(color: AppTheme.emeraldGreen, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                        ),
                        ...catProducts.map((product) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(12),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: product.image.isNotEmpty 
                                ? Image.network(product.image, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,_,_) => const Icon(Icons.fastfood, color: Colors.white54))
                                : const CircleAvatar(radius: 30, backgroundColor: Colors.white12, child: Icon(Icons.fastfood, color: AppTheme.emeraldGreen)),
                            ),
                            title: Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (product.description.isNotEmpty) 
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(product.description, style: const TextStyle(color: Colors.white54, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Disponibilité : ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    Switch(
                                      value: product.isAvailable,
                                      activeThumbColor: AppTheme.emeraldGreen,
                                      onChanged: (val) async {
                                        await FirebaseFirestore.instance.collection('products').doc(product.id).update({'isAvailable': val});
                                      },
                                    ),
                                    if (!product.isAvailable)
                                      const Text('RUPTURE', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${product.priceHT.toStringAsFixed(2)} € HT",
                                      style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      "TVA ${product.vatRate}%",
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Colors.amber),
                                  tooltip: 'Dupliquer',
                                  onPressed: () => _duplicateProduct(context, product),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                  tooltip: 'Éditer',
                                  onPressed: () => _showEditProductDialog(context, product),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  tooltip: 'Supprimer',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: AppTheme.darkBackground,
                                        title: const Text('Supprimer ?', style: TextStyle(color: Colors.white)),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Supprimer')),
                                        ],
                                      )
                                    );
                                    if (confirm == true) {
                                      await FirebaseFirestore.instance.collection('products').doc(product.id).delete();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ))),
                      ],
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

class _ProductDialog extends StatefulWidget {
  final RestaurantModel restaurant;
  final ProductModel? product;
  const _ProductDialog({required this.restaurant, this.product});

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imgCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController();
  
  String? _selectedCategoryName;
  double _currentVat = 2.1;
  bool _isLoading = false;

  // Options
  List<ProductModifierGroup> _modifierGroups = [];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameCtrl.text = widget.product!.name;
      _priceCtrl.text = widget.product!.priceHT.toString();
      _descCtrl.text = widget.product!.description;
      _imgCtrl.text = widget.product!.image;
      _badgeCtrl.text = widget.product!.badgeText;
      _selectedCategoryName = widget.product!.category;
      _currentVat = widget.product!.vatRate;
      _modifierGroups = List.from(widget.product!.modifierGroups);
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty || _selectedCategoryName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir le nom, le prix et la catégorie.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final docRef = widget.product == null 
          ? FirebaseFirestore.instance.collection('products').doc()
          : FirebaseFirestore.instance.collection('products').doc(widget.product!.id);

      final newProduct = ProductModel(
          id: docRef.id,
          restaurantId: widget.restaurant.id,
          restaurantName: widget.restaurant.name,
          category: _selectedCategoryName!,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          image: _imgCtrl.text.trim(),
          priceHT: double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
          vatRate: _currentVat,
          badgeText: _badgeCtrl.text.trim(),
          isAvailable: widget.product?.isAvailable ?? true,
          linkedInventoryItemId: widget.product?.linkedInventoryItemId,
          modifierGroups: _modifierGroups,
        );

      await docRef.set(newProduct.toJson());

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addOptionGroup() {
    setState(() {
      _modifierGroups.add(ProductModifierGroup(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Nouveau Groupe',
        minSelections: 1,
        maxSelections: 1,
        options: [],
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 800,
          height: 800,
          child: Column(
            children: [
              Text(widget.product == null ? 'Nouveau Plat' : 'Modifier ${widget.product!.name}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Partie Gauche : Infos basiques
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const Text('Informations Générales', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _buildField('Nom du plat', _nameCtrl),
                            _buildField('Description', _descCtrl, maxLines: 3),
                            _buildField('URL Image', _imgCtrl),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildField('Prix HT', _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildField('Badge (ex: Populaire)', _badgeCtrl),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Sélection de catégorie depuis la base
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('categories').orderBy('order').snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const CircularProgressIndicator();
                                final cats = snapshot.data!.docs.map((d) => CategoryModel.fromJson(d.data() as Map<String, dynamic>)).toList();
                                
                                return DropdownButtonFormField<String>(
                                  initialValue: cats.any((c) => c.name == _selectedCategoryName) ? _selectedCategoryName : null,
                                  dropdownColor: AppTheme.darkBackground,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Catégorie',
                                    labelStyle: TextStyle(color: Colors.white54),
                                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  ),
                                  items: cats.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final selectedCat = cats.firstWhere((c) => c.name == val);
                                      setState(() {
                                        _selectedCategoryName = val;
                                        _currentVat = selectedCat.defaultVatRate;
                                      });
                                    }
                                  },
                                );
                              }
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text('TVA Appliquée : ', style: TextStyle(color: Colors.white70)),
                                Text('$_currentVat %', style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    const VerticalDivider(color: Colors.white24, width: 1),
                    const SizedBox(width: 24),
                    
                    // Partie Droite : Options et Modificateurs
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Groupes d\'Options', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                              TextButton.icon(
                                onPressed: _addOptionGroup,
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter un groupe'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _modifierGroups.isEmpty
                              ? const Center(child: Text("Aucune option. (ex: Choix de sauce, taille...)", style: TextStyle(color: Colors.white38)))
                              : ListView.builder(
                                  itemCount: _modifierGroups.length,
                                  itemBuilder: (context, index) {
                                    final group = _modifierGroups[index];
                                    return Card(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: group.name,
                                                    style: const TextStyle(color: Colors.white),
                                                    decoration: const InputDecoration(labelText: 'Nom du groupe (ex: Sauces)', labelStyle: TextStyle(color: Colors.white54)),
                                                    onChanged: (v) => group.name = v,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                  onPressed: () => setState(() => _modifierGroups.removeAt(index)),
                                                )
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: group.minSelections.toString(),
                                                    keyboardType: TextInputType.number,
                                                    style: const TextStyle(color: Colors.white),
                                                    decoration: const InputDecoration(labelText: 'Min Sélections', labelStyle: TextStyle(color: Colors.white54)),
                                                    onChanged: (v) => group.minSelections = int.tryParse(v) ?? 1,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: group.maxSelections.toString(),
                                                    keyboardType: TextInputType.number,
                                                    style: const TextStyle(color: Colors.white),
                                                    decoration: const InputDecoration(labelText: 'Max Sélections', labelStyle: TextStyle(color: Colors.white54)),
                                                    onChanged: (v) => group.maxSelections = int.tryParse(v) ?? 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            const Align(alignment: Alignment.centerLeft, child: Text('Options:', style: TextStyle(color: Colors.white70))),
                                            ...group.options.asMap().entries.map((entry) {
                                              int optIdx = entry.key;
                                              var opt = entry.value;
                                              return Row(
                                                children: [
                                                  Expanded(
                                                    child: TextFormField(
                                                      initialValue: opt.name,
                                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                                      decoration: const InputDecoration(hintText: 'Nom (ex: Ketchup)'),
                                                      onChanged: (v) => opt.name = v,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 80,
                                                    child: TextFormField(
                                                      initialValue: opt.extraPrice.toString(),
                                                      keyboardType: TextInputType.number,
                                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                                      decoration: const InputDecoration(hintText: 'Prix+'),
                                                      onChanged: (v) => opt.extraPrice = double.tryParse(v) ?? 0.0,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                                    onPressed: () => setState(() => group.options.removeAt(optIdx)),
                                                  )
                                                ],
                                              );
                                            }),
                                            TextButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  group.options.add(ProductModifierOption(
                                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                    name: 'Option',
                                                  ));
                                                });
                                              },
                                              icon: const Icon(Icons.add, size: 16),
                                              label: const Text('Ajouter Option', style: TextStyle(fontSize: 12)),
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                    child: _isLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enregistrer le Plat', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.emeraldGreen)),
        ),
      ),
    );
  }
}

