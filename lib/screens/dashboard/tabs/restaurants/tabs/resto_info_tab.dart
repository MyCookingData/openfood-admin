import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/glass_container.dart';

class RestoInfoTab extends StatefulWidget {
  final RestaurantModel restaurant;
  const RestoInfoTab({super.key, required this.restaurant});

  @override
  State<RestoInfoTab> createState() => _RestoInfoTabState();
}

class _RestoInfoTabState extends State<RestoInfoTab> {
  late TextEditingController _nameCtrl;
  late TextEditingController _imgCtrl;
  late TextEditingController _typeCtrl;
  late TextEditingController _zoneCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  late TextEditingController _fbCtrl;
  late TextEditingController _igCtrl;
  late TextEditingController _ttCtrl;
  late TextEditingController _stripeAccCtrl;
  late String _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.restaurant.name);
    _imgCtrl = TextEditingController(text: widget.restaurant.imageUrl);
    _typeCtrl = TextEditingController(text: widget.restaurant.type);
    _zoneCtrl = TextEditingController(text: widget.restaurant.zone);
    _latCtrl = TextEditingController(text: widget.restaurant.lat.toString());
    _lngCtrl = TextEditingController(text: widget.restaurant.lng.toString());
    _fbCtrl = TextEditingController(text: widget.restaurant.facebook);
    _igCtrl = TextEditingController(text: widget.restaurant.instagram);
    _ttCtrl = TextEditingController(text: widget.restaurant.tiktok);
    _stripeAccCtrl = TextEditingController(text: widget.restaurant.stripeAccountId);
    _status = widget.restaurant.status;
  }

  Future<void> _submitInfo() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final updatedResto = RestaurantModel(
        id: widget.restaurant.id,
        name: _nameCtrl.text.trim(),
        imageUrl: _imgCtrl.text.trim(),
        rating: widget.restaurant.rating,
        status: _status,
        type: _typeCtrl.text.trim(),
        zone: _zoneCtrl.text.trim(),
        lat: double.tryParse(_latCtrl.text) ?? widget.restaurant.lat,
        lng: double.tryParse(_lngCtrl.text) ?? widget.restaurant.lng,
        facebook: _fbCtrl.text.trim(),
        instagram: _igCtrl.text.trim(),
        tiktok: _ttCtrl.text.trim(),
        stripeAccountId: _stripeAccCtrl.text.trim().isNotEmpty ? _stripeAccCtrl.text.trim() : null,
      );
      await FirebaseFirestore.instance.collection('restaurants').doc(widget.restaurant.id).update(updatedResto.toJson());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informations mises à jour', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.emeraldGreen));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations Générales', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildField('Nom', _nameCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildField('URL Image', _imgCtrl)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildField('Type (ex: Fusion)', _typeCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildField('Zone', _zoneCtrl)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildField('Latitude', _latCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildField('Longitude', _lngCtrl)),
              ],
            ),
            const Divider(color: Colors.white24, height: 48),
            const Text('Réseaux Sociaux', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildField('Facebook URL', _fbCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildField('Instagram URL', _igCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildField('TikTok URL', _ttCtrl)),
              ],
            ),
            const Divider(color: Colors.white24, height: 48),
            const Text('Paiements & Stripe', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _buildField('ID Compte Stripe (ex: acct_123...)', _stripeAccCtrl),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Statut du restaurant: ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _status,
                  dropdownColor: AppTheme.darkBackground,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: const [
                    DropdownMenuItem(value: 'actif', child: Text('Ouvert / Actif', style: TextStyle(color: AppTheme.emeraldGreen))),
                    DropdownMenuItem(value: 'inactif', child: Text('Fermé / Inactif', style: TextStyle(color: Colors.redAccent))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitInfo,
                  icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                  label: const Text('Enregistrer les modifications'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
