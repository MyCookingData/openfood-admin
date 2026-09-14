import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';

class LiveOrdersTab extends StatefulWidget {
  const LiveOrdersTab({super.key});

  @override
  State<LiveOrdersTab> createState() => _LiveOrdersTabState();
}

class _LiveOrdersTabState extends State<LiveOrdersTab> {
  DateTimeRange? _selectedDateRange;
  int? _selectedStatus;
  String? _selectedRestaurantName;
  String _customerSearchQuery = '';
  String _orderIdSearchQuery = '';

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
                'Suivi en Direct',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Mode Administrateur',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          // FILTRES
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.filter_list, color: Colors.white70),
                const Text('Filtres :', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                // Filtre Statut
                DropdownButton<int?>(
                  value: _selectedStatus,
                  dropdownColor: AppTheme.lighterDarkBackground,
                  hint: const Text('Tous les états', style: TextStyle(color: Colors.white70)),
                  style: const TextStyle(color: Colors.white),
                  underline: Container(height: 1, color: Colors.white24),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous les états')),
                    DropdownMenuItem(value: 0, child: Text('En Attente')),
                    DropdownMenuItem(value: 1, child: Text('En Préparation')),
                    DropdownMenuItem(value: 2, child: Text('En Route')),
                    DropdownMenuItem(value: 3, child: Text('Livré')),
                    DropdownMenuItem(value: 4, child: Text('Annulé')),
                  ],
                  onChanged: (val) => setState(() => _selectedStatus = val),
                ),
                // Filtre Date (Plage)
                TextButton.icon(
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      initialDateRange: _selectedDateRange,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppTheme.emeraldGreen,
                              onPrimary: Colors.white,
                              surface: AppTheme.darkBackground,
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (range != null) {
                      setState(() => _selectedDateRange = range);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, color: AppTheme.emeraldGreen, size: 18),
                  label: Text(
                    _selectedDateRange != null 
                        ? '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}' 
                        : 'Toutes les dates',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (_selectedDateRange != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                    onPressed: () => setState(() => _selectedDateRange = null),
                    tooltip: 'Effacer les dates',
                  ),
                // Filtre Restaurant (Menu déroulant dynamique)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    final restaurants = snapshot.data!.docs;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedRestaurantName,
                          dropdownColor: AppTheme.lighterDarkBackground,
                          hint: const Text('Tous les restaurants', style: TextStyle(color: Colors.white70)),
                          style: const TextStyle(color: Colors.white),
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.emeraldGreen),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Tous les restaurants')),
                            ...restaurants.map((doc) {
                              final name = doc['name'] as String? ?? 'Inconnu';
                              return DropdownMenuItem<String?>(
                                value: name.toLowerCase(),
                                child: Text(name),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedRestaurantName = val;
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
                // Filtre Client (Nom ou Tél)
                SizedBox(
                  width: 220,
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Client (Nom ou Tél)...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.person_search, color: Colors.white54, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _customerSearchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                // Filtre ID Commande
                SizedBox(
                  width: 160,
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'N° Commande...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.tag, color: Colors.white54, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _orderIdSearchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders')
                .orderBy('createdAt', descending: true)
                .limit((_customerSearchQuery.isNotEmpty || _orderIdSearchQuery.isNotEmpty || _selectedDateRange != null) ? 1000 : 200)
                .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));

                final docs = snapshot.data?.docs ?? [];
                
                var orders = docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
                
                // Application des filtres locaux
                final now = DateTime.now();
                
                if (_selectedStatus != null) {
                  orders = orders.where((o) => o.status == _selectedStatus).toList();
                }
                if (_selectedDateRange != null) {
                  orders = orders.where((o) {
                    final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
                    final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
                    return o.createdAt.isAfter(start) && o.createdAt.isBefore(end);
                  }).toList();
                }
                if (_selectedRestaurantName != null && _selectedRestaurantName!.isNotEmpty) {
                  orders = orders.where((o) => o.restaurantName.toLowerCase().contains(_selectedRestaurantName!)).toList();
                }
                if (_customerSearchQuery.isNotEmpty) {
                  orders = orders.where((o) {
                    final n = o.customerName?.toLowerCase() ?? '';
                    final p = o.customerPhone?.toLowerCase() ?? '';
                    return n.contains(_customerSearchQuery) || p.contains(_customerSearchQuery);
                  }).toList();
                }
                if (_orderIdSearchQuery.isNotEmpty) {
                  orders = orders.where((o) => o.id.toLowerCase().contains(_orderIdSearchQuery)).toList();
                }

                if (orders.isEmpty) {
                  return const GlassContainer(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text("Aucune commande ne correspond aux filtres actuels.", style: TextStyle(color: Colors.white70)),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 3;
                    if (constraints.maxWidth < 800) {
                      crossAxisCount = 1;
                    } else if (constraints.maxWidth < 1300) crossAxisCount = 2;

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisExtent: 440,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                      ),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        return _AdminOrderCard(order: orders[index]);
                      },
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOrderCard extends StatefulWidget {
  final OrderModel order;
  const _AdminOrderCard({required this.order});

  @override
  State<_AdminOrderCard> createState() => _AdminOrderCardState();
}

class _AdminOrderCardState extends State<_AdminOrderCard> {
  Timer? _timer;
  String? _driverName;
  String? _driverPhone;
  bool _isLoadingDriver = false;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
    _fetchDriver();
  }

  @override
  void didUpdateWidget(covariant _AdminOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.driverId != widget.order.driverId) {
      _fetchDriver();
    }
  }

  Future<void> _fetchDriver() async {
    final driverId = widget.order.driverId;
    if (driverId == null || driverId.isEmpty) {
      if (mounted) setState(() { _driverName = null; _driverPhone = null; });
      return;
    }
    
    if (mounted) setState(() => _isLoadingDriver = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(driverId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _driverName = data['name'];
          // Assuming users collection might store phone or email
          _driverPhone = data['phone'] ?? data['email'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching driver: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDriver = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleCapturePayment(String orderId) async {
    setState(() => _isProcessingAction = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('captureOrderPayment');
      await callable.call({'orderId': orderId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement capturé. Commande acceptée !'), backgroundColor: AppTheme.emeraldGreen),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleCancelPayment(String orderId) async {
    setState(() => _isProcessingAction = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('cancelOrderPayment');
      await callable.call({'orderId': orderId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empreinte annulée. Commande refusée.'), backgroundColor: Colors.orangeAccent),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 0: return 'En Attente';
      case 1: return 'En Préparation';
      case 2: return 'En Route';
      case 3: return 'Livré';
      case 4: return 'Annulé';
      default: return 'Inconnu';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0: return Colors.redAccent;
      case 1: return Colors.orangeAccent;
      case 2: return Colors.blueAccent;
      case 3: return AppTheme.emeraldGreen;
      case 4: return Colors.grey;
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final now = DateTime.now();
    final elapsedMinutes = now.difference(order.createdAt).inMinutes;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.restaurantName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('#${order.id.substring(0, 6).toUpperCase()} • ${DateFormat('HH:mm').format(order.createdAt)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(order.status).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Text(
                    _getStatusText(order.status).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Timer
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                'Écoulé: $elapsedMinutes min',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              if (order.prepTimeMinutes != null) ...[
                const SizedBox(width: 8),
                const Text('|', style: TextStyle(color: Colors.white24)),
                const SizedBox(width: 8),
                Text('Prévu: ${order.prepTimeMinutes} min', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]
            ],
          ),
          const SizedBox(height: 12),
          // Info Client (Toujours visible pour l'administrateur, sauf si livrée > 30 min)
          Builder(
            builder: (context) {
              final isDelivered = order.status == 3;
              final deliveredTime = order.deliveredAt ?? order.createdAt;
              final isOldDelivery = isDelivered && now.difference(deliveredTime).inMinutes > 30;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Expanded(child: Text(order.customerName ?? 'Client Inconnu', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(isOldDelivery ? 'Masqué (Délai dépassé)' : (order.customerPhone ?? 'Sans numéro'), style: TextStyle(color: isOldDelivery ? Colors.white38 : Colors.white70, fontSize: 12, fontStyle: isOldDelivery ? FontStyle.italic : FontStyle.normal)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Expanded(child: Text(isOldDelivery ? 'Adresse masquée (Délai dépassé)' : (order.deliveryAddress ?? 'Adresse inconnue'), style: TextStyle(color: isOldDelivery ? Colors.white38 : Colors.white70, fontSize: 12, fontStyle: isOldDelivery ? FontStyle.italic : FontStyle.normal), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                )
              );
            }
          ),
          const SizedBox(height: 12),
          
          // Driver Info
          Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
             child: Row(
               children: [
                 const Icon(Icons.delivery_dining, color: Colors.blueAccent, size: 16),
                 const SizedBox(width: 8),
                 Expanded(
                   child: _isLoadingDriver 
                     ? const Text('Chargement du livreur...', style: TextStyle(color: Colors.blueAccent, fontSize: 12))
                     : Text(
                         _driverName != null ? 'Livreur: $_driverName ($_driverPhone)' : 'Aucun livreur assigné',
                         style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                       ),
                 ),
               ],
             ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView.separated(
              itemCount: order.items.length,
              separatorBuilder: (_, _) => const Divider(color: Colors.white12),
              itemBuilder: (context, index) {
                final item = order.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Text('${item['quantity']}x', style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item['name'], style: const TextStyle(color: Colors.white)),
                      ),
                      Text('${item['price']} €', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('${order.totalAmount.toStringAsFixed(2)} €', style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          if (order.paymentStatus == 'pending' && order.status == 0) ...[
            const SizedBox(height: 16),
            if (_isProcessingAction)
              const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen))
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleCancelPayment(order.id),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Refuser (Annuler)', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleCapturePayment(order.id),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Accepter (Débiter)', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ],
              )
          ]
        ],
      ),
    );
  }
}
