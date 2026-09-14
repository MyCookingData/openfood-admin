import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass_container.dart';
import 'restaurant_details_page.dart';

class RestaurantsListTab extends StatelessWidget {
  const RestaurantsListTab({super.key});

  void _showAddRestaurantDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AddRestaurantDialog(),
    );
  }

  void _navigateToDetails(BuildContext context, RestaurantModel resto) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RestaurantDetailsPage(restaurant: resto),
      ),
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
                'Gestion des Restaurants',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddRestaurantDialog(context),
                icon: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.white,
                ),
                label: const Text('Nouveau Restaurant'),
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
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
                      child: Text('Aucun restaurant partenaire trouvé', style: TextStyle(color: Colors.white70, fontSize: 18)),
                    ),
                  );
                }

                final restaurants = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return RestaurantModel.fromJson(data);
                }).toList();

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    mainAxisExtent: 280,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    final resto = restaurants[index];
                    return InkWell(
                      onTap: () => _navigateToDetails(context, resto),
                      borderRadius: BorderRadius.circular(16),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: resto.imageUrl.isNotEmpty
                                    ? Image.network(
                                        resto.imageUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => _fallbackImage(),
                                      )
                                    : _fallbackImage(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    resto.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      resto.rating.toStringAsFixed(1),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white54, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    resto.zone.isNotEmpty ? resto.zone : 'Zone inconnue',
                                    style: const TextStyle(color: Colors.white70),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: resto.status == 'actif' ? AppTheme.emeraldGreen.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8)
                                  ),
                                  child: Text(resto.status, style: TextStyle(color: resto.status == 'actif' ? AppTheme.emeraldGreen : Colors.redAccent, fontSize: 10)),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Center(
                              child: Text(
                                "Appuyez pour configurer",
                                style: TextStyle(color: AppTheme.emeraldGreen, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
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
  }

  Widget _fallbackImage() {
    return Container(
      color: Colors.black26,
      child: const Icon(Icons.restaurant, color: Colors.white54, size: 50),
    );
  }
}

class _AddRestaurantDialog extends StatefulWidget {
  const _AddRestaurantDialog();

  @override
  State<_AddRestaurantDialog> createState() => _AddRestaurantDialogState();
}

class _AddRestaurantDialogState extends State<_AddRestaurantDialog> {
  final _nameCtrl = TextEditingController();
  final _imgCtrl = TextEditingController();
  final _typeCtrl = TextEditingController(text: 'Fusion');
  final _zoneCtrl = TextEditingController(text: 'Schoelcher');
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('restaurants').doc();
      final newResto = RestaurantModel(
        id: docRef.id,
        name: _nameCtrl.text.trim(),
        imageUrl: _imgCtrl.text.trim(),
        rating: 5.0,
        status: 'actif',
        type: _typeCtrl.text.trim(),
        zone: _zoneCtrl.text.trim(),
        lat: double.tryParse(_latCtrl.text) ?? 14.6415,
        lng: double.tryParse(_lngCtrl.text) ?? -61.0242,
        facebook: '',
        instagram: '',
        tiktok: '',
      );
      await docRef.set(newResto.toJson());
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
      title: const Text('Nouveau Restaurant', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField('Nom du restaurant', _nameCtrl),
              _buildField('URL Image', _imgCtrl),
              Row(
                children: [
                  Expanded(child: _buildField('Type (ex: Fusion)', _typeCtrl)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField('Zone (ex: Lamentin)', _zoneCtrl)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildField('Latitude', _latCtrl)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField('Longitude', _lngCtrl)),
                ],
              ),
            ],
          ),
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

  Widget _buildField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: ctrl,
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
