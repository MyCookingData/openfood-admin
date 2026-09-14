import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CategoryDialog(),
    );
  }

  void _showEditCategoryDialog(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(category: category),
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
                'Catégories de Produits',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(context),
                icon: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.white,
                ),
                label: const Text('Nouvelle Catégorie'),
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('categories').orderBy('order').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const GlassContainer(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Aucune catégorie trouvée. Créez-en une pour commencer.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
                  );
                }

                final categories = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return CategoryModel.fromJson(data);
                }).toList();

                return ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = categories.removeAt(oldIndex);
                    categories.insert(newIndex, item);

                    // Update order in Firestore
                    final batch = FirebaseFirestore.instance.batch();
                    for (int i = 0; i < categories.length; i++) {
                      final docRef = FirebaseFirestore.instance.collection('categories').doc(categories[i].id);
                      batch.update(docRef, {'order': i});
                    }
                    batch.commit();
                  },
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Card(
                      key: ValueKey(cat.id),
                      color: AppTheme.darkBackground,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white12),
                      ),
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle, color: Colors.white54),
                        ),
                        title: Text(cat.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('TVA par défaut : ${cat.defaultVatRate}%', style: const TextStyle(color: Colors.white54)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                              onPressed: () => _showEditCategoryDialog(context, cat),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppTheme.darkBackground,
                                    title: const Text('Supprimer ?', style: TextStyle(color: Colors.white)),
                                    content: const Text('Cette action est irréversible.', style: TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                        child: const Text('Supprimer'),
                                      ),
                                    ],
                                  )
                                );
                                if (confirm == true) {
                                  await FirebaseFirestore.instance.collection('categories').doc(cat.id).delete();
                                }
                              },
                            )
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
  }
}

class _CategoryDialog extends StatefulWidget {
  final CategoryModel? category;
  const _CategoryDialog({this.category});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _nameCtrl = TextEditingController();
  final _vatCtrl = TextEditingController(text: '2.1');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameCtrl.text = widget.category!.name;
      _vatCtrl.text = widget.category!.defaultVatRate.toString();
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final vat = double.tryParse(_vatCtrl.text.replaceAll(',', '.')) ?? 2.1;
      
      final collection = FirebaseFirestore.instance.collection('categories');
      
      if (widget.category == null) {
        // Create
        final snapshot = await collection.get();
        final order = snapshot.docs.length;
        
        final newDoc = collection.doc();
        await newDoc.set({
          'name': _nameCtrl.text.trim(),
          'defaultVatRate': vat,
          'order': order,
        });
      } else {
        // Update
        await collection.doc(widget.category!.id).update({
          'name': _nameCtrl.text.trim(),
          'defaultVatRate': vat,
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkBackground,
      title: Text(widget.category == null ? 'Nouvelle Catégorie' : 'Modifier Catégorie', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nom de la catégorie (ex: Entrées)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.emeraldGreen)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _vatCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'TVA par défaut (%)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.emeraldGreen)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen),
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
