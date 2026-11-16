import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';
import 'package:openfood_models/openfood_models.dart';
import 'create_user_dialog.dart';

class UsersManagementTab extends StatelessWidget {
  const UsersManagementTab({super.key});

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
                    'Gestion des Utilisateurs',
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const CreateUserDialog(),
                      );
                    },
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(isMobile ? 'Nouveau' : 'Nouvel Utilisateur'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));

                    final users = snapshot.data?.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      return UserModel.fromJson(data);
                    }).toList() ?? [];

                    if (users.isEmpty) {
                      return const GlassContainer(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text("Aucun utilisateur trouvé.", style: TextStyle(color: Colors.white70)),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InkWell(
                            onTap: () => _showUserDetails(context, user),
                            borderRadius: BorderRadius.circular(16),
                            child: GlassContainer(
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
                                    child: Icon(Icons.person, color: _getRoleColor(user.role)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              user.name.isNotEmpty ? user.name : 'Utilisateur Anonyme', 
                                              style: TextStyle(color: Colors.white, fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.bold),
                                            ),
                                            if (!user.isActive)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                                child: const Text('DÉSACTIVÉ', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(user.email, style: const TextStyle(color: Colors.white54, fontSize: 13), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(user.role).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _getRoleColor(user.role)),
                                    ),
                                    child: Text(user.role.toUpperCase(), style: TextStyle(color: _getRoleColor(user.role), fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
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
      },
    );
  }

  void _showUserDetails(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => _UserDetailsDialog(user: user),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.redAccent;
      case 'livreur':
        return Colors.blueAccent;
      case 'restaurant_owner':
        return Colors.amber;
      default:
        return AppTheme.emeraldGreen;
    }
  }
}

class _UserDetailsDialog extends StatelessWidget {
  final UserModel user;
  const _UserDetailsDialog({required this.user});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: screenSize.height * 0.9,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 22 : 28,
                        backgroundColor: Colors.white12,
                        child: Icon(Icons.person, color: Colors.white, size: isMobile ? 22 : 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name.isNotEmpty ? user.name : 'Anonyme', style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user.isActive)
                        TextButton.icon(
                          icon: const Icon(Icons.block, color: Colors.orange, size: 16),
                          label: const Text('Désactiver', style: TextStyle(color: Colors.orange, fontSize: 13)),
                          onPressed: () => _toggleUserStatus(context, false),
                        )
                      else
                        TextButton.icon(
                          icon: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          label: const Text('Activer', style: TextStyle(color: Colors.green, fontSize: 13)),
                          onPressed: () => _toggleUserStatus(context, true),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                        label: const Text('Supprimer', style: TextStyle(color: Colors.red, fontSize: 13)),
                        onPressed: () => _deleteUser(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 28),
              
              // Contenu (Data orders + adresses)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('orders').where('userId', isEqualTo: user.id).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('Erreur récupération commandes: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));

                    final docs = snapshot.data?.docs ?? [];
                    final orders = docs.map((doc) => OrderModel.fromFirestore(doc)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    
                    // Extraction des adresses uniques
                    final Set<String> uniqueAddresses = {};
                    for (var o in orders) {
                      if (o.deliveryAddress != null && o.deliveryAddress!.isNotEmpty) {
                        uniqueAddresses.add(o.deliveryAddress!);
                      }
                    }

                    if (isMobile) {
                      return ListView(
                        children: [
                          const Text('Historique des commandes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (orders.isEmpty)
                            const Text("Aucune commande n'a été passée par cet utilisateur.", style: TextStyle(color: Colors.white54, fontSize: 13))
                          else
                            ...orders.take(5).map((order) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.receipt, color: AppTheme.emeraldGreen, size: 20),
                              title: Text(order.restaurantName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('${order.items.length} articles • ${_getStatusText(order.status)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: Text('${order.totalAmount.toStringAsFixed(2)} €', style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                            )),
                          const Divider(color: Colors.white24, height: 24),
                          const Text('Carnet d\'Adresses', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (uniqueAddresses.isEmpty)
                            const Text("Aucune adresse enregistrée.", style: TextStyle(color: Colors.white54, fontSize: 13))
                          else
                            ...uniqueAddresses.map((addr) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.blueAccent, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(addr, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                                ],
                              ),
                            )),
                          const Divider(color: Colors.white24, height: 24),
                          const Text('Métriques', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildMetricRow('Total dépensé', '${orders.fold<double>(0, (total, item) => total + item.totalAmount).toStringAsFixed(2)} €'),
                          const SizedBox(height: 6),
                          _buildMetricRow('Nombre de commandes', '${orders.length}'),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Historique des commandes
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Historique des commandes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Expanded(
                                child: orders.isEmpty 
                                  ? const Text("Aucune commande n'a été passée par cet utilisateur.", style: TextStyle(color: Colors.white54))
                                  : ListView.separated(
                                      itemCount: orders.length,
                                      separatorBuilder: (_, _) => const Divider(color: Colors.white12),
                                      itemBuilder: (context, index) {
                                        final order = orders[index];
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(Icons.receipt, color: AppTheme.emeraldGreen),
                                          title: Text(order.restaurantName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          subtitle: Text('${order.items.length} articles • Statut: ${_getStatusText(order.status)}', style: const TextStyle(color: Colors.white54)),
                                          trailing: Text('${order.totalAmount.toStringAsFixed(2)} €', style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                                        );
                                      },
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Adresses et infos
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Carnet d\'Adresses (Récentes)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Expanded(
                                child: uniqueAddresses.isEmpty
                                  ? const Text("Aucune adresse enregistrée.", style: TextStyle(color: Colors.white54))
                                  : ListView.builder(
                                      itemCount: uniqueAddresses.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white12,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.white24),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.location_on, color: Colors.blueAccent, size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(uniqueAddresses.elementAt(index), style: const TextStyle(color: Colors.white70)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                              ),
                              const Divider(color: Colors.white24, height: 32),
                              const Text('Métriques', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              _buildMetricRow('Total dépensé', '${orders.fold<double>(0, (total, item) => total + item.totalAmount).toStringAsFixed(2)} €'),
                              const SizedBox(height: 8),
                              _buildMetricRow('Nombre de commandes', '${orders.length}'),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _getStatusText(int status) {
    switch (status) {
      case 0: return 'En attente';
      case 1: return 'En préparation';
      case 2: return 'En livraison';
      case 3: return 'Livrée';
      case 4: return 'Annulée';
      default: return 'Inconnu';
    }
  }

  Future<void> _toggleUserStatus(BuildContext context, bool newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.id).update({'isActive': newStatus});
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut utilisateur mis à jour: ${newStatus ? "Actif" : "Désactivé"}'), backgroundColor: AppTheme.emeraldGreen),
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _deleteUser(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkBackground,
        title: const Text('Confirmer la suppression', style: TextStyle(color: Colors.white)),
        content: const Text('Êtes-vous sûr de vouloir supprimer définitivement cet utilisateur ? Ses données ne pourront pas être récupérées.', style: TextStyle(color: Colors.white70)),
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
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.id).delete();
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utilisateur supprimé'), backgroundColor: AppTheme.emeraldGreen),
          );
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }
}
