import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';
import 'dart:math';

class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class CustomerData {
  String name;
  String phone;
  int orderCount = 0;
  double totalSpent = 0;
  CustomerData(this.name, this.phone);
}

class _StatisticsTabState extends State<StatisticsTab> {
  DateTimeRange? _selectedDateRange;
  String? _selectedRestaurantName;

  final List<Color> _chartColors = [
    Colors.blueAccent,
    Colors.redAccent,
    Colors.greenAccent,
    Colors.amber,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.cyanAccent,
    Colors.limeAccent,
  ];

  String _extractCity(String? address) {
    if (address == null || address.trim().isEmpty) return 'Inconnue';
    final regex = RegExp(r'\b\d{5}\s+([A-Za-zÀ-ÖØ-öø-ÿ\s\-]+)');
    final match = regex.firstMatch(address);
    if (match != null && match.groupCount >= 1) return match.group(1)!.trim().toUpperCase();
    final parts = address.split(',');
    if (parts.length > 1) {
      String lastPart = parts.last.trim();
      lastPart = lastPart.replaceAll(RegExp(r'\d'), '').trim().toUpperCase();
      if (lastPart.isNotEmpty) return lastPart;
    }
    return 'Autre';
  }

  List<String> _extractAddons(Map<String, dynamic> item) {
    List<String> addons = [];
    if (item['options'] is List) {
      for (var opt in item['options']) {
        if (opt is Map && opt['name'] != null) addons.add(opt['name'].toString());
        else if (opt is String) addons.add(opt);
      }
    }
    if (item['selectedModifiers'] is List) {
      for (var mod in item['selectedModifiers']) {
        if (mod is Map && mod['name'] != null) addons.add(mod['name'].toString());
        else if (mod is String) addons.add(mod);
      }
    }
    if (item['selectedOptions'] is Map) {
      final map = item['selectedOptions'] as Map;
      for (var val in map.values) {
        if (val is List) addons.addAll(val.map((e) => e.toString()));
        else addons.add(val.toString());
      }
    }
    return addons;
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
              const Text('Analytique 360°', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              Row(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final restaurants = snapshot.data!.docs;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedRestaurantName,
                            dropdownColor: AppTheme.lighterDarkBackground,
                            hint: const Text('Tous les restaurants', style: TextStyle(color: Colors.white70)),
                            style: const TextStyle(color: Colors.white),
                            icon: const Icon(Icons.arrow_drop_down, color: AppTheme.emeraldGreen),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Tous les restaurants')),
                              ...restaurants.map((doc) => DropdownMenuItem<String?>(value: (doc['name'] as String? ?? '').toLowerCase(), child: Text(doc['name'] as String? ?? ''))),
                            ],
                            onChanged: (val) => setState(() => _selectedRestaurantName = val),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              initialDateRange: _selectedDateRange,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (range != null) setState(() => _selectedDateRange = range);
                          },
                          icon: const Icon(Icons.calendar_today, color: AppTheme.emeraldGreen, size: 18),
                          label: Text(
                            _selectedDateRange != null ? '${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}' : 'Toutes les dates',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        if (_selectedDateRange != null)
                          IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 18), onPressed: () => setState(() => _selectedDateRange = null)),
                      ],
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erreur : ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                var allDocs = snapshot.data?.docs ?? [];
                
                if (_selectedRestaurantName != null && _selectedRestaurantName!.isNotEmpty) {
                  allDocs = allDocs.where((doc) => ((doc.data() as Map)['restaurantName'] as String?)?.toLowerCase().contains(_selectedRestaurantName!) ?? false).toList();
                }

                if (_selectedDateRange != null) {
                  allDocs = allDocs.where((doc) {
                    final createdAt = ((doc.data() as Map)['createdAt'] as Timestamp).toDate();
                    final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
                    final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
                    return createdAt.isAfter(start) && createdAt.isBefore(end);
                  }).toList();
                }

                if (allDocs.isEmpty) return const Center(child: Text("Aucune donnée", style: TextStyle(color: Colors.white54, fontSize: 18)));

                int totalCancelled = 0;
                var deliveredDocs = <DocumentSnapshot>[];

                for (var doc in allDocs) {
                  final s = (doc.data() as Map)['status'] as int? ?? 0;
                  if (s == 4) totalCancelled++;
                  if (s == 3) deliveredDocs.add(doc);
                }

                double totalCA = 0;
                Map<String, double> productRevenue = {};
                Map<String, int> addonsCount = {};
                Map<String, int> cityCount = {};
                Map<int, int> rushHours = {}; // 0 to 23
                Map<int, int> weekdayOrders = {}; // 1 (Mon) to 7 (Sun)
                Map<String, CustomerData> customers = {};
                
                // Timeline granularity determination
                bool isSingleDay = _selectedDateRange != null && _selectedDateRange!.end.difference(_selectedDateRange!.start).inDays <= 1;
                Map<String, double> revenueTimeline = {};
                Map<String, int> ordersTimeline = {};

                for (var doc in deliveredDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                  final createdAt = (data['createdAt'] as Timestamp).toDate();
                  
                  totalCA += amount;
                  
                  // Heures & Jours
                  rushHours.update(createdAt.hour, (v) => v + 1, ifAbsent: () => 1);
                  weekdayOrders.update(createdAt.weekday, (v) => v + 1, ifAbsent: () => 1);

                  // Timeline
                  String timeKey;
                  if (isSingleDay) {
                    timeKey = '${createdAt.hour.toString().padLeft(2, '0')}:00';
                  } else {
                    timeKey = DateFormat('yyyy-MM-dd').format(createdAt);
                  }
                  revenueTimeline.update(timeKey, (v) => v + amount, ifAbsent: () => amount);
                  ordersTimeline.update(timeKey, (v) => v + 1, ifAbsent: () => 1);

                  // Clients
                  final phone = data['customerPhone']?.toString() ?? 'Inconnu';
                  final name = data['customerName']?.toString() ?? 'Client Mystère';
                  if (!customers.containsKey(phone)) customers[phone] = CustomerData(name, phone);
                  customers[phone]!.orderCount += 1;
                  customers[phone]!.totalSpent += amount;

                  // Ville
                  cityCount.update(_extractCity(data['deliveryAddress']?.toString()), (v) => v + 1, ifAbsent: () => 1);

                  // Produits & Addons
                  final items = data['items'] as List<dynamic>? ?? [];
                  for (var item in items) {
                    if (item is Map<String, dynamic>) {
                      final pName = item['name'] as String? ?? 'Inconnu';
                      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                      productRevenue.update(pName, (v) => v + (price * qty), ifAbsent: () => (price * qty));
                      for (var addon in _extractAddons(item)) addonsCount.update(addon, (v) => v + qty, ifAbsent: () => qty);
                    }
                  }
                }

                double aov = deliveredDocs.isNotEmpty ? totalCA / deliveredDocs.length : 0;
                double cancelRate = allDocs.isNotEmpty ? (totalCancelled / allDocs.length) * 100 : 0;

                int uniqueCustomers = customers.values.where((c) => c.orderCount == 1).length;
                int recurringCustomers = customers.values.where((c) => c.orderCount > 1).length;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // KPIs
                      Row(
                        children: [
                          Expanded(child: _buildKpiCard('Chiffre d\'Affaires', '${totalCA.toStringAsFixed(2)} €', Icons.account_balance_wallet, AppTheme.emeraldGreen)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildKpiCard('Commandes Livrées', '${deliveredDocs.length}', Icons.check_circle_outline, Colors.blueAccent)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildKpiCard('Panier Moyen', '${aov.toStringAsFixed(2)} €', Icons.shopping_basket, Colors.purpleAccent)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildKpiCard('Taux Annulation', '${cancelRate.toStringAsFixed(1)} %', Icons.cancel, Colors.redAccent)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Ligne 2: Timeline et Top Clients
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: SizedBox(height: 350, child: _buildTimelineChart(revenueTimeline, ordersTimeline, isSingleDay))),
                          const SizedBox(width: 24),
                          Expanded(flex: 1, child: SizedBox(height: 350, child: _buildTopCustomers(customers.values.toList()))),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Ligne 3: Heures de Pointe et Jours de la semaine
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: SizedBox(height: 300, child: _buildRushHoursChart(rushHours))),
                          const SizedBox(width: 24),
                          Expanded(flex: 1, child: SizedBox(height: 300, child: _buildWeekdayChart(weekdayOrders))),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Ligne 4: Parts de marché
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: SizedBox(height: 250, child: _buildPieChart('Revenus par Produit', productRevenue, true))),
                          const SizedBox(width: 24),
                          Expanded(flex: 1, child: SizedBox(height: 250, child: _buildPieChart('Villes de Livraison', cityCount.map((k, v) => MapEntry(k, v.toDouble())), false))),
                          const SizedBox(width: 24),
                          Expanded(flex: 1, child: SizedBox(height: 250, child: _buildPieChart('Fidélité Clients', {'Unique (1 cmd)': uniqueCustomers.toDouble(), 'Fidèles (>1 cmd)': recurringCustomers.toDouble()}, false))),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Ligne 5: Top Addons
                      SizedBox(height: 300, child: _buildAddonsChart(addonsCount)),
                      const SizedBox(height: 48),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTopCustomers(List<CustomerData> customers) {
    customers.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    final top = customers.take(10).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Clients (Revenus)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: top.isEmpty 
              ? const Center(child: Text("Aucun client"))
              : ListView.builder(
                  itemCount: top.length,
                  itemBuilder: (context, i) {
                    final c = top[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(backgroundColor: Colors.white12, child: Text('${i+1}', style: const TextStyle(color: AppTheme.emeraldGreen))),
                      title: Text(c.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${c.orderCount} commandes', style: const TextStyle(color: Colors.white54)),
                      trailing: Text('${c.totalSpent.toStringAsFixed(2)} €', style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
          )
        ],
      ),
    );
  }

  Widget _buildPieChart(String title, Map<String, double> data, bool isCurrency) {
    if (data.isEmpty) return GlassContainer(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const Expanded(child: Center(child: Text('Aucune donnée')))]));
    var sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length > 5) {
      double others = 0;
      for (int i = 5; i < sorted.length; i++) others += sorted[i].value;
      sorted = sorted.sublist(0, 5);
      sorted.add(MapEntry('Autres', others));
    }
    double total = sorted.fold(0, (sum, e) => sum + e.value);

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 25,
                      sections: List.generate(sorted.length, (i) {
                        final val = sorted[i].value;
                        return PieChartSectionData(
                          color: _chartColors[i % _chartColors.length],
                          value: val,
                          title: '${(val/total*100).toStringAsFixed(0)}%',
                          radius: 40,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: _chartColors[i % _chartColors.length])),
                            const SizedBox(width: 6),
                            Expanded(child: Text(sorted[i].key, style: const TextStyle(color: Colors.white, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
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
    );
  }

  Widget _buildRushHoursChart(Map<int, int> data) {
    if (data.isEmpty) return const GlassContainer(child: Center(child: Text("Aucune commande")));
    int maxVal = data.values.fold(0, (max, v) => v > max ? v : max);

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Heures de Pointe (Nb Commandes)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2 == 0 ? 10 : maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem('${group.x}h\n', const TextStyle(color: Colors.white), children: [TextSpan(text: '${rod.toY.toInt()} cmds', style: const TextStyle(color: Colors.amber))])
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}h', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    )
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: List.generate(24, (i) {
                  return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: (data[i] ?? 0).toDouble(), color: Colors.amber, width: 8, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);
                }),
              )
            ),
          )
        ],
      )
    );
  }

  Widget _buildWeekdayChart(Map<int, int> data) {
    if (data.isEmpty) return const GlassContainer(child: Center(child: Text("Aucune commande")));
    int maxVal = data.values.fold(0, (max, v) => v > max ? v : max);
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Jours les plus rentables', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2 == 0 ? 10 : maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem('${days[group.x.toInt() - 1]}\n', const TextStyle(color: Colors.white), children: [TextSpan(text: '${rod.toY.toInt()} cmds', style: const TextStyle(color: Colors.purpleAccent))])
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(days[v.toInt() - 1], style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    )
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: List.generate(7, (i) {
                  int day = i + 1;
                  return BarChartGroupData(x: day, barRods: [BarChartRodData(toY: (data[day] ?? 0).toDouble(), color: Colors.purpleAccent, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);
                }),
              )
            ),
          )
        ],
      )
    );
  }

  Widget _buildAddonsChart(Map<String, int> data) {
    if (data.isEmpty) return const GlassContainer(child: Center(child: Text("Aucun supplément")));
    var sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top10 = sorted.take(15).toList();
    final maxY = top10.first.value.toDouble() * 1.2;

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Addons & Suppléments', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY == 0 ? 10 : maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem('${top10[group.x.toInt()].key}\n', const TextStyle(color: Colors.white), children: [TextSpan(text: '${rod.toY.toInt()} fois', style: const TextStyle(color: Colors.cyanAccent))])
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (v, _) {
                        if (v.toInt() >= top10.length) return const SizedBox();
                        String name = top10[v.toInt()].key;
                        if (name.length > 10) name = '${name.substring(0, 10)}.';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          ),
                        );
                      },
                    )
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: List.generate(top10.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: top10[i].value.toDouble(), color: Colors.cyanAccent, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))])),
              )
            ),
          )
        ],
      )
    );
  }

  Widget _buildTimelineChart(Map<String, double> revenueMap, Map<String, int> ordersMap, bool isHourly) {
    if (revenueMap.isEmpty) return const GlassContainer(child: Center(child: Text("Pas de données")));
    
    var sortedKeys = revenueMap.keys.toList()..sort();
    
    List<FlSpot> revSpots = [];
    List<FlSpot> ordSpots = [];
    double maxRev = 0;
    double maxOrd = 0;

    for (int i = 0; i < sortedKeys.length; i++) {
      final r = revenueMap[sortedKeys[i]]!;
      final o = ordersMap[sortedKeys[i]]!.toDouble();
      revSpots.add(FlSpot(i.toDouble(), r));
      ordSpots.add(FlSpot(i.toDouble(), o));
      if (r > maxRev) maxRev = r;
      if (o > maxOrd) maxOrd = o;
    }

    double scale = maxOrd > 0 && maxRev > 0 ? maxRev / maxOrd : 1.0;
    if (scale == 0 || scale.isNaN || scale.isInfinite) scale = 1.0;
    var scaledOrdSpots = ordSpots.map((s) => FlSpot(s.x, s.y * scale)).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isHourly ? 'Évolution Temporelle (Heure par Heure)' : 'Évolution Temporelle (Jour par Jour)', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.emeraldGreen, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('Revenus', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 16),
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('Commandes', style: TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxRev * 1.2 == 0 ? 10 : maxRev * 1.2,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItems: (spots) => spots.map((spot) {
                      String key = sortedKeys[spot.x.toInt()];
                      if (spot.barIndex == 0) return LineTooltipItem('$key\n${spot.y.toStringAsFixed(2)} €', const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold));
                      return LineTooltipItem('${(spot.y / scale).toInt()} cmds', const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold));
                    }).toList(),
                  ),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white12, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (sortedKeys.length / 6).ceilToDouble().clamp(1.0, 100.0),
                      getTitlesWidget: (v, _) {
                        if (v.toInt() < 0 || v.toInt() >= sortedKeys.length) return const SizedBox();
                        String k = sortedKeys[v.toInt()];
                        if (!isHourly && k.length >= 10) k = k.substring(5); // Show MM-DD instead of YYYY-MM-DD
                        return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(k, style: const TextStyle(color: Colors.white54, fontSize: 10)));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text('${v.toInt()}€', style: const TextStyle(color: Colors.white54, fontSize: 10)))),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(spots: revSpots, isCurved: true, color: AppTheme.emeraldGreen, barWidth: 3, dotData: FlDotData(show: sortedKeys.length < 20), belowBarData: BarAreaData(show: true, color: AppTheme.emeraldGreen.withValues(alpha: 0.2))),
                  LineChartBarData(spots: scaledOrdSpots, isCurved: true, color: Colors.blueAccent, barWidth: 3, dotData: FlDotData(show: sortedKeys.length < 20)),
                ],
              )
            ),
          )
        ],
      )
    );
  }
}
