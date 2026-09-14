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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gestion des Utilisateurs',
                style: TextStyle(
                  fontSize: 32,
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
                icon: const Icon(Icons.person_add),
                label: const Text('Nouvel Utilisateur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
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
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
                                child: Icon(Icons.person, color: _getRoleColor(user.role)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(user.name.isNotEmpty ? user.name : 'Utilisateur Anonyme', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                        if (!user.isActive) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('DÉSACTIVÉ', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                          )
                                        ]
                                      ],
                                    ),
                                    Text(user.email, style: const TextStyle(color: Colors.white54)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(user.role).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _getRoleColor(user.role)),
                                ),
                                child: Text(user.role.toUpperCase(), style: TextStyle(color: _getRoleColor(user.role), fontWeight: FontWeight.bold, fontSize: 12)),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        child: SizedBox(
          width: 800,
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white12,
                        child: Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name.isNotEmpty ? user.name : 'Anonyme', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(user.email, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (user.isActive)
                        TextButton.icon(
                          icon: const Icon(Icons.block, color: Colors.orange, size: 18),
                          label: const Text('Désactiver', style: TextStyle(color: Colors.orange)),
                          onPressed: () => _toggleUserStatus(context, false),
                        )
                      else
                        TextButton.icon(
                          icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          label: const Text('Activer', style: TextStyle(color: Colors.green)),
                          onPressed: () => _toggleUserStatus(context, true),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
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
              const Divider(color: Colors.white24, height: 48),
              
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
                                          subtitle: Text(_formatDate(order.createdAt), style: const TextStyle(color: Colors.white54)),
                                          trailing: Text('${order.totalAmount.toStringAsFixed(2)} €', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
        Text(label, style: const TextStyle(color: Colors.white54)),
        Text(value, style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Future<void> _toggleUserStatus(BuildContext context, bool isActive) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.id).update({'isActive': isActive});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isActive ? 'Utilisateur activé.' : 'Utilisateur désactivé.'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteUser(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkBackground,
        title: const Text('Supprimer l\'utilisateur', style: TextStyle(color: Colors.white)),
        content: const Text('Êtes-vous sûr de vouloir supprimer définitivement cet utilisateur ? Cette action est irréversible.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      )
    );

    if (confirm == true && context.mounted) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.id).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur supprimé.'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}
