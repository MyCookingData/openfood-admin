import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'package:openfood_models/openfood_models.dart';
import 'package:flutter/services.dart';
import 'promo_code_dialog.dart';
import 'promo_code_history_dialog.dart';

class PromoCodesTab extends StatefulWidget {
  const PromoCodesTab({super.key});

  @override
  State<PromoCodesTab> createState() => _PromoCodesTabState();
}

class _PromoCodesTabState extends State<PromoCodesTab> {
  String _searchQuery = '';
  String _selectedType = 'all'; // 'all', 'global', 'unitary'

  String _translateTarget(PromoTarget target) {
    switch (target) {
      case PromoTarget.cart_subtotal: return 'le sous-total du panier';
      case PromoTarget.selected_products: return 'les produits sélectionnés';
      case PromoTarget.most_expensive: return 'le produit le plus cher';
      case PromoTarget.least_expensive: return 'le produit le moins cher';
      case PromoTarget.delivery_fee: return 'les frais de livraison';
    }
  }

  void _showAddPromoCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PromoCodeDialog(),
    );
  }

  void _showEditPromoCodeDialog(BuildContext context, PromoCodeModel promo) {
    showDialog(
      context: context,
      builder: (context) => PromoCodeDialog(promoCode: promo),
    );
  }

  void _showHistoryDialog(BuildContext context, PromoCodeModel promo) {
    showDialog(
      context: context,
      builder: (context) => PromoCodeHistoryDialog(promoCode: promo),
    );
  }

  Future<void> _deletePromoCode(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkBackground,
        title: const Text('Confirmer la suppression', style: TextStyle(color: Colors.white)),
        content: const Text('Voulez-vous vraiment supprimer ce code promo ?', style: TextStyle(color: Colors.white70)),
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
      await FirebaseFirestore.instance.collection('promo_codes').doc(id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Codes Promo',
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPromoCodeDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 12),
                    ),
                    label: Text(isMobile ? 'Nouveau' : 'Nouveau Code'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 280,
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un code...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        dropdownColor: AppTheme.lighterDarkBackground,
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tous les types')),
                          DropdownMenuItem(value: 'global', child: Text('Globaux uniquement')),
                          DropdownMenuItem(value: 'unitary', child: Text('Unitaires uniquement')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('promo_codes').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));

                    final docs = snapshot.data?.docs ?? [];
                    var promoCodes = docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      return PromoCodeModel.fromJson(data);
                    }).toList();

                    // Filtrage
                    if (_selectedType == 'global') {
                      promoCodes = promoCodes.where((p) => p.isGlobal).toList();
                    } else if (_selectedType == 'unitary') {
                      promoCodes = promoCodes.where((p) => !p.isGlobal).toList();
                    }

                    if (_searchQuery.isNotEmpty) {
                      promoCodes = promoCodes.where((p) => p.code.toLowerCase().contains(_searchQuery)).toList();
                    }

                    if (promoCodes.isEmpty) {
                      return const Center(child: Text('Aucun code promo trouvé.', style: TextStyle(color: Colors.white54, fontSize: 16)));
                    }

                    return ListView.builder(
                      itemCount: promoCodes.length,
                      itemBuilder: (context, index) {
                        final promo = promoCodes[index];
                        final isValid = promo.isValid();

                        return Card(
                          color: AppTheme.lighterDarkBackground,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isValid ? AppTheme.emeraldGreen.withValues(alpha: 0.5) : Colors.redAccent.withValues(alpha: 0.5))),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(promo.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: promo.isGlobal ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.orangeAccent.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(promo.isGlobal ? 'Global' : 'Unitaire', style: TextStyle(color: promo.isGlobal ? Colors.blueAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                          if (!isValid)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('Inactif/Expiré', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (!isMobile)
                                      _buildActionsRow(context, promo),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Réduction : ${promo.type == PromotionType.percentage ? '${promo.value}%' : '${promo.value}€'} sur ${_translateTarget(promo.discountTarget)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                if (promo.expirationDate != null)
                                  Text('Expire le : ${DateFormat('dd/MM/yyyy HH:mm').format(promo.expirationDate!)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('Utilisations : ${promo.currentUses} / ${promo.maxUses == null ? 'Illimité' : promo.maxUses}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                if (isMobile) ...[
                                  const Divider(color: Colors.white10, height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _buildActionsRow(context, promo),
                                    ],
                                  ),
                                ],
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

  Widget _buildActionsRow(BuildContext context, PromoCodeModel promo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.history, color: AppTheme.emeraldGreen, size: 20),
          tooltip: 'Voir l\'historique',
          onPressed: () => _showHistoryDialog(context, promo),
        ),
        IconButton(
          icon: const Icon(Icons.copy, color: Colors.blueAccent, size: 20),
          tooltip: 'Copier le code',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: promo.code));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Code copié dans le presse-papier !', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.blueAccent,
                duration: Duration(seconds: 2),
              ));
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
          onPressed: () => _showEditPromoCodeDialog(context, promo),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
          onPressed: () => _deletePromoCode(promo.id),
        ),
      ],
    );
  }
}
