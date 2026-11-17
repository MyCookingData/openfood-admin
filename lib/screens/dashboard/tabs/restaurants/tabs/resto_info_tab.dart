import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/glass_container.dart';
import '../../../../../widgets/ovh_image_upload_field.dart';

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

  final Map<String, DaySchedule> _schedule = {};

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

    _initOpeningHours();
  }

  void _initOpeningHours() {
    final raw = widget.restaurant.openingHours ?? OpeningHoursHelper.defaultOpeningHours();
    for (final day in OpeningHoursHelper.dayKeys) {
      if (raw[day] is Map) {
        _schedule[day] = DaySchedule.fromJson(Map<String, dynamic>.from(raw[day] as Map));
      } else {
        _schedule[day] = const DaySchedule(isOpen: false);
      }
    }
  }

  void _applyStandardHours() {
    setState(() {
      final defaults = OpeningHoursHelper.defaultOpeningHours();
      for (final day in OpeningHoursHelper.dayKeys) {
        if (defaults[day] != null) {
          _schedule[day] = DaySchedule.fromJson(defaults[day]);
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Horaires par défaut appliqués'),
        backgroundColor: AppTheme.emeraldGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyMondayToWeekdays() {
    final monday = _schedule['monday'];
    if (monday == null) return;
    setState(() {
      for (final day in ['tuesday', 'wednesday', 'thursday', 'friday']) {
        _schedule[day] = monday.copyWith();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Horaires du lundi dupliqués sur mardi à vendredi'),
        backgroundColor: AppTheme.emeraldGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, String currentVal, Function(String) onSelected) async {
    final parts = currentVal.replaceAll('h', ':').split(':');
    final initial = TimeOfDay(
      hour: parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 12) : 12,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.emeraldGreen,
              onPrimary: Colors.white,
              surface: Color(0xFF1E2620),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() {
        onSelected('$h:$m');
      });
    }
  }

  Future<void> _submitInfo() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> openingHoursMap = {};
      _schedule.forEach((day, schedule) {
        openingHoursMap[day] = schedule.toJson();
      });

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
        openingHours: openingHoursMap,
      );

      await FirebaseFirestore.instance.collection('restaurants').doc(widget.restaurant.id).update(updatedResto.toJson());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informations et horaires mis à jour', style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
      }
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

  Widget _buildTimeChip(String time, VoidCallback onTap) {
    final display = OpeningHoursHelper.formatTimeDisplay(time);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 14, color: AppTheme.emeraldGreen),
            const SizedBox(width: 6),
            Text(
              display.isEmpty ? 'Choisir' : display,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpeningHoursSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.schedule, color: AppTheme.emeraldGreen, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Horaires & Jours d\'ouverture',
              style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Définissez les créneaux d\'ouverture pour chaque jour. L\'application mobile affichera automatiquement si le restaurant est ouvert ou fermé.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _applyStandardHours,
              icon: const Icon(Icons.restore, size: 16, color: AppTheme.emeraldGreen),
              label: const Text('Horaires types (11h30-14h30 / 18h30-22h30)', style: TextStyle(fontSize: 12, color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.emeraldGreen.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _copyMondayToWeekdays,
              icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
              label: const Text('Dupliquer Lundi sur Mar–Ven', style: TextStyle(fontSize: 12, color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...OpeningHoursHelper.dayKeys.map((dayKey) {
          final schedule = _schedule[dayKey] ?? const DaySchedule(isOpen: false);
          final dayName = OpeningHoursHelper.dayNamesFr[dayKey] ?? dayKey;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: schedule.isOpen ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: schedule.isOpen ? AppTheme.emeraldGreen.withValues(alpha: 0.25) : Colors.white10,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        dayName,
                        style: TextStyle(
                          color: schedule.isOpen ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: schedule.isOpen,
                      activeThumbColor: AppTheme.emeraldGreen,
                      activeTrackColor: AppTheme.emeraldGreen.withValues(alpha: 0.5),
                      onChanged: (val) {
                        setState(() {
                          _schedule[dayKey] = schedule.copyWith(isOpen: val);
                        });
                      },
                    ),
                    Text(
                      schedule.isOpen ? 'Ouvert' : 'Fermé',
                      style: TextStyle(
                        color: schedule.isOpen ? AppTheme.emeraldGreen : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (schedule.isOpen) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text('Service 1 :', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      _buildTimeChip(schedule.open, () {
                        _pickTime(context, schedule.open, (newVal) {
                          _schedule[dayKey] = schedule.copyWith(open: newVal);
                        });
                      }),
                      const Text('à', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      _buildTimeChip(schedule.close, () {
                        _pickTime(context, schedule.close, (newVal) {
                          _schedule[dayKey] = schedule.copyWith(close: newVal);
                        });
                      }),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _schedule[dayKey] = schedule.copyWith(hasSecondSlot: !schedule.hasSecondSlot);
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: schedule.hasSecondSlot,
                              activeColor: AppTheme.emeraldGreen,
                              onChanged: (val) {
                                setState(() {
                                  _schedule[dayKey] = schedule.copyWith(hasSecondSlot: val ?? false);
                                });
                              },
                            ),
                            const Text('2ème service (soir)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (schedule.hasSecondSlot) ...[
                        _buildTimeChip(schedule.open2, () {
                          _pickTime(context, schedule.open2, (newVal) {
                            _schedule[dayKey] = schedule.copyWith(open2: newVal);
                          });
                        }),
                        const Text('à', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        _buildTimeChip(schedule.close2, () {
                          _pickTime(context, schedule.close2, (newVal) {
                            _schedule[dayKey] = schedule.copyWith(close2: newVal);
                          });
                        }),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final padding = isMobile ? 14.0 : 24.0;
        final innerPadding = isMobile ? 16.0 : 28.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: GlassContainer(
            padding: EdgeInsets.all(innerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informations Générales',
                  style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),
                _buildField('Nom', _nameCtrl),
                const SizedBox(height: 12),
                OvhImageUploadField(
                  label: 'Photo de Couverture du Restaurant (Serveur OVH)',
                  controller: _imgCtrl,
                  folder: 'restaurants',
                ),
                const SizedBox(height: 16),
                if (isMobile) ...[
                  _buildField('Type (ex: Fusion)', _typeCtrl),
                  _buildField('Zone', _zoneCtrl),
                  _buildField('Latitude', _latCtrl),
                  _buildField('Longitude', _lngCtrl),
                ] else ...[
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
                ],
                const Divider(color: Colors.white24, height: 36),
                const Text('Réseaux Sociaux', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 14),
                if (isMobile) ...[
                  _buildField('Facebook URL', _fbCtrl),
                  _buildField('Instagram URL', _igCtrl),
                  _buildField('TikTok URL', _ttCtrl),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _buildField('Facebook URL', _fbCtrl)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildField('Instagram URL', _igCtrl)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildField('TikTok URL', _ttCtrl)),
                    ],
                  ),
                ],
                const Divider(color: Colors.white24, height: 36),
                const Text('Paiements & Stripe', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 14),
                _buildField('ID Compte Stripe (ex: acct_123...)', _stripeAccCtrl),
                const Divider(color: Colors.white24, height: 36),
                _buildOpeningHoursSection(isMobile),
                const Divider(color: Colors.white24, height: 36),
                if (isMobile) ...[
                  Row(
                    children: [
                      const Text('Statut : ', style: TextStyle(color: Colors.white70, fontSize: 15)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _status,
                        dropdownColor: AppTheme.darkBackground,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        items: const [
                          DropdownMenuItem(value: 'actif', child: Text('Ouvert / Actif', style: TextStyle(color: AppTheme.emeraldGreen))),
                          DropdownMenuItem(value: 'inactif', child: Text('Fermé / Inactif', style: TextStyle(color: Colors.redAccent))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitInfo,
                      icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                      label: const Text('Enregistrer les modifications'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ] else ...[
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
                        icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                        label: const Text('Enregistrer les modifications'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
