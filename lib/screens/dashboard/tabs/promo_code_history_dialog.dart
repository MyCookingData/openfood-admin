import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'package:openfood_models/openfood_models.dart';

class PromoCodeHistoryDialog extends StatelessWidget {
  final PromoCodeModel promoCode;

  const PromoCodeHistoryDialog({super.key, required this.promoCode});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Historique : ${promoCode.code}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(color: Colors.white24, height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.lighterDarkBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.emeraldGreen),
                  const SizedBox(width: 12),
                  Text('Utilisé ${promoCode.currentUses} fois sur un maximum de ${promoCode.maxUses ?? "Illimité"}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Commandes associées', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('promoCodeId', isEqualTo: promoCode.id)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));
                  }

                  final orders = snapshot.data!.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();

                  if (orders.isEmpty) {
                    return const Center(
                      child: Text('Aucune commande n\'a encore utilisé ce code.', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Card(
                        color: Colors.black26,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('Commande #${order.id.substring(0, 6)} - ${order.restaurantName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Client : ${order.customerName ?? "Inconnu"}', style: const TextStyle(color: Colors.white70)),
                              Text('Date : ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)}', style: const TextStyle(color: Colors.white54)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${order.totalAmount.toStringAsFixed(2)} €', style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                              if (order.discountAmount != null && order.discountAmount! > 0)
                                Text('-${order.discountAmount!.toStringAsFixed(2)} € de remise', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
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
      ),
    );
  }
}
