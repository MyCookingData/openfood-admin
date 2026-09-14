import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../widgets/glass_container.dart';

class CarouselDialog extends StatefulWidget {
  final CarouselModel? carousel;

  const CarouselDialog({super.key, this.carousel});

  @override
  State<CarouselDialog> createState() => _CarouselDialogState();
}

class _CarouselDialogState extends State<CarouselDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  final _emojiCtrl = TextEditingController(text: '👋');
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _tagTextCtrl = TextEditingController();
  final _chipTextCtrl = TextEditingController();
  final _ctaTextCtrl = TextEditingController(text: 'Découvrir');
  
  final _color1Ctrl = TextEditingController(text: '#1E8B3A');
  final _color2Ctrl = TextEditingController(text: '#104A1F');
  
  final _imageUrlCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  final _actionPayloadCtrl = TextEditingController();
  
  String? _selectedTargetRestaurantId;
  String? _tempActionRestoId;
  String? _tempActionRestoName;
  
  CarouselPlacement _placement = CarouselPlacement.home;
  
  final _minOrdersCtrl = TextEditingController();
  final _maxOrdersCtrl = TextEditingController();
  final _minTotalSpentCtrl = TextEditingController();
  final _maxTotalSpentCtrl = TextEditingController();

  CarouselActionType _actionType = CarouselActionType.none;
  bool _isSponsored = false;
  bool _isActive = true;
  int _sortOrder = 0;
  
  TimeOfDay? _validTimeStart;
  TimeOfDay? _validTimeEnd;
  List<int> _validDaysOfWeek = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Add listeners for real-time preview
    final controllers = [
      _emojiCtrl, _titleCtrl, _subtitleCtrl, _tagTextCtrl, 
      _chipTextCtrl, _ctaTextCtrl, _color1Ctrl, _color2Ctrl, 
      _imageUrlCtrl, _logoUrlCtrl
    ];
    for (var ctrl in controllers) {
      ctrl.addListener(() => setState(() {}));
    }

    if (widget.carousel != null) {
      final c = widget.carousel!;
      _emojiCtrl.text = c.emoji;
      _titleCtrl.text = c.title;
      _subtitleCtrl.text = c.subtitle;
      _tagTextCtrl.text = c.tagText;
      _chipTextCtrl.text = c.chipText;
      _ctaTextCtrl.text = c.ctaText;
      
      _imageUrlCtrl.text = c.imageUrl ?? '';
      _logoUrlCtrl.text = c.logoUrl ?? '';

      if (c.gradientColorsHex.isNotEmpty) {
        _color1Ctrl.text = c.gradientColorsHex[0];
        if (c.gradientColorsHex.length > 1) {
          _color2Ctrl.text = c.gradientColorsHex[1];
        }
      }

      _actionType = c.actionType;
      _actionPayloadCtrl.text = c.actionPayload ?? '';
      
      _isSponsored = c.isSponsored;
      _isActive = c.isActive;
      _sortOrder = c.sortOrder;

      if (c.validTimeStart != null) {
        final parts = c.validTimeStart!.split(':');
        _validTimeStart = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (c.validTimeEnd != null) {
        final parts = c.validTimeEnd!.split(':');
        _validTimeEnd = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      _validDaysOfWeek = List.from(c.validDaysOfWeek ?? []);
      
      _minOrdersCtrl.text = c.minOrders?.toString() ?? '';
      _maxOrdersCtrl.text = c.maxOrders?.toString() ?? '';
      _minTotalSpentCtrl.text = c.minTotalSpent?.toString() ?? '';
      _maxTotalSpentCtrl.text = c.maxTotalSpent?.toString() ?? '';
      _selectedTargetRestaurantId = c.targetRestaurantId;
      _placement = c.placement;
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final minOrders = int.tryParse(_minOrdersCtrl.text);
      final maxOrders = int.tryParse(_maxOrdersCtrl.text);
      final minTotalSpent = double.tryParse(_minTotalSpentCtrl.text.replaceAll(',', '.'));
      final maxTotalSpent = double.tryParse(_maxTotalSpentCtrl.text.replaceAll(',', '.'));
      
      final String? timeStartStr = _validTimeStart != null ? '${_validTimeStart!.hour.toString().padLeft(2, '0')}:${_validTimeStart!.minute.toString().padLeft(2, '0')}' : null;
      final String? timeEndStr = _validTimeEnd != null ? '${_validTimeEnd!.hour.toString().padLeft(2, '0')}:${_validTimeEnd!.minute.toString().padLeft(2, '0')}' : null;
      
      final collection = FirebaseFirestore.instance.collection('carousels');
      final String docId = widget.carousel?.id ?? collection.doc().id;

      final newCarousel = CarouselModel(
        id: docId,
        emoji: _emojiCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text.trim(),
        tagText: _tagTextCtrl.text.trim(),
        chipText: _chipTextCtrl.text.trim(),
        ctaText: _ctaTextCtrl.text.trim(),
        gradientColorsHex: [_color1Ctrl.text.trim(), _color2Ctrl.text.trim()],
        imageUrl: _imageUrlCtrl.text.trim().isNotEmpty ? _imageUrlCtrl.text.trim() : null,
        logoUrl: _logoUrlCtrl.text.trim().isNotEmpty ? _logoUrlCtrl.text.trim() : null,
        actionType: _actionType,
        actionPayload: _actionPayloadCtrl.text.trim().isNotEmpty ? _actionPayloadCtrl.text.trim() : null,
        placement: _placement,
        isSponsored: _isSponsored,
        isActive: _isActive,
        sortOrder: _sortOrder,
        validDaysOfWeek: _validDaysOfWeek.isEmpty ? null : _validDaysOfWeek,
        validTimeStart: timeStartStr,
        validTimeEnd: timeEndStr,
        minOrders: minOrders,
        maxOrders: maxOrders,
        minTotalSpent: minTotalSpent,
        maxTotalSpent: maxTotalSpent,
        targetRestaurantId: _selectedTargetRestaurantId,
      );

      if (widget.carousel == null) {
        await collection.doc(docId).set(newCarousel.toJson());
      } else {
        await collection.doc(docId).update(newCarousel.toJson());
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.black12,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.emeraldGreen)),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  // ==== WIDGET: LIVE PREVIEW ====
  Widget _buildLivePreview() {
    final c1 = _parseColor(_color1Ctrl.text);
    final c2 = _parseColor(_color2Ctrl.text);
    
    return Container(
      width: 320, // Typical phone width scale
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Aperçu Client', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // The Banner
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: _imageUrlCtrl.text.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_imageUrlCtrl.text),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.4), BlendMode.darken),
                    )
                  : null,
              gradient: _imageUrlCtrl.text.isEmpty
                  ? LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
              boxShadow: [
                BoxShadow(color: c1.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_tagTextCtrl.text.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(_tagTextCtrl.text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                Text(
                                  _titleCtrl.text.isEmpty ? 'Titre Principal' : _titleCtrl.text,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.1, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _subtitleCtrl.text.isEmpty ? 'Sous-titre descriptif' : _subtitleCtrl.text,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                                ),
                              ],
                            ),
                          ),
                          if (_logoUrlCtrl.text.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(_logoUrlCtrl.text, width: 40, height: 40, fit: BoxFit.cover),
                            )
                          else
                            Text(_emojiCtrl.text, style: const TextStyle(fontSize: 32)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _chipTextCtrl.text.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emeraldGreen,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(_chipTextCtrl.text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                )
                              : const SizedBox(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _ctaTextCtrl.text,
                              style: TextStyle(color: c1, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isSponsored)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomLeft: Radius.circular(8)),
                      ),
                      child: const Text('Sponsorisé', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==== TAB: DESIGN ====
  Widget _buildDesignTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            SizedBox(
              width: 80,
              child: TextFormField(
                controller: _emojiCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 24),
                decoration: _inputDeco('Emoji'),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Titre principal'),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _subtitleCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco('Sous-titre'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _tagTextCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Tag en haut (ex: 🔥 Offre)'))),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _chipTextCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Badge vert (ex: -50%)'))),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(controller: _ctaTextCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Texte du bouton action')),
        const Divider(color: Colors.white24, height: 32),
        const Text('Visuels Avancés', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(controller: _imageUrlCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('URL Image de Fond (Optionnel)')),
        const SizedBox(height: 16),
        TextFormField(controller: _logoUrlCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('URL Logo Restaurant/Marque (Optionnel)')),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _color1Ctrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Couleur Hex 1'))),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _color2Ctrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Couleur Hex 2'))),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Badge "Sponsorisé"', style: TextStyle(color: Colors.white)),
          value: _isSponsored,
          activeTrackColor: Colors.amber,
          onChanged: (v) => setState(() => _isSponsored = v),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // ==== TAB: ACTION ====
  Widget _buildActionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Action au Clic', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        const Text('Que doit-il se passer quand le client clique sur la bannière ?', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 24),
        DropdownButtonFormField<CarouselActionType>(
          value: _actionType,
          dropdownColor: AppTheme.lighterDarkBackground,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco('Type d\'action'),
          items: CarouselActionType.values.map((t) {
            String label = '';
            switch (t) {
              case CarouselActionType.none: label = 'Aucune action'; break;
              case CarouselActionType.open_restaurant: label = 'Ouvrir un restaurant'; break;
              case CarouselActionType.open_product: label = 'Ouvrir un produit'; break;
              case CarouselActionType.open_promo_code: label = 'Ouvrir un code promo'; break;
              case CarouselActionType.open_url: label = 'Ouvrir une URL'; break;
            }
            return DropdownMenuItem(value: t, child: Text(label));
          }).toList(),
          onChanged: (v) => setState(() {
            _actionType = v!;
            _actionPayloadCtrl.clear();
          }),
        ),
        const SizedBox(height: 24),
        if (_actionType == CarouselActionType.open_restaurant)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final items = snapshot.data!.docs;
              final val = items.any((e) => e.id == _actionPayloadCtrl.text) ? _actionPayloadCtrl.text : null;
              return DropdownButtonFormField<String>(
                value: val,
                dropdownColor: AppTheme.lighterDarkBackground,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Sélectionner le restaurant'),
                items: items.map((e) => DropdownMenuItem(value: e.id, child: Text(e['name'] as String))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _actionPayloadCtrl.text = v);
                },
              );
            }
          )
        else if (_actionType == CarouselActionType.open_product)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final items = snapshot.data!.docs;
                  return DropdownButtonFormField<String?>(
                    value: _tempActionRestoId,
                    dropdownColor: AppTheme.lighterDarkBackground,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('Filtre: Choisir un restaurant d\'abord'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous les restaurants')),
                      ...items.map((e) => DropdownMenuItem(value: e.id, child: Text(e['name'] as String)))
                    ],
                    onChanged: (v) {
                      setState(() {
                        _tempActionRestoId = v;
                        if (v != null) {
                          final doc = items.firstWhere((e) => e.id == v);
                          _tempActionRestoName = doc['name'] as String;
                        } else {
                          _tempActionRestoName = null;
                        }
                        _actionPayloadCtrl.clear();
                      });
                    },
                  );
                }
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _tempActionRestoId == null
                    ? FirebaseFirestore.instance.collection('products').snapshots()
                    : FirebaseFirestore.instance.collection('products').where('restaurantId', whereIn: [_tempActionRestoId, _tempActionRestoName ?? _tempActionRestoId]).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final products = snapshot.data!.docs;
                  final val = products.any((e) => e.id == _actionPayloadCtrl.text) ? _actionPayloadCtrl.text : null;
                  return DropdownButtonFormField<String>(
                    value: val,
                    dropdownColor: AppTheme.lighterDarkBackground,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('Sélectionner le produit'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sélectionner un produit')),
                      ...products.map((e) => DropdownMenuItem(value: e.id, child: Text(e['name'] as String)))
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _actionPayloadCtrl.text = v);
                    },
                  );
                }
              ),
            ],
          )
        else if (_actionType != CarouselActionType.none)
          TextFormField(
            controller: _actionPayloadCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco(
              _actionType == CarouselActionType.open_promo_code ? 'Nom du Code Promo' :
              'URL complète'
            ),
          ),
      ],
    );
  }

  // ==== TAB: CIBLAGE ====
  Widget _buildTargetingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Emplacement', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<CarouselPlacement>(
          value: _placement,
          dropdownColor: AppTheme.lighterDarkBackground,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco('Afficher cette bannière sur...'),
          items: const [
            DropdownMenuItem(value: CarouselPlacement.home, child: Text("L'Accueil")),
            DropdownMenuItem(value: CarouselPlacement.restaurant, child: Text("Le Haut de la carte d'un restaurant")),
          ],
          onChanged: (v) => setState(() => _placement = v!),
        ),
        const Divider(color: Colors.white24, height: 32),
        SwitchListTile(
          title: const Text('Bannière Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: const Text('Désactiver pour la masquer immédiatement pour tout le monde.', style: TextStyle(color: Colors.white54)),
          value: _isActive,
          activeTrackColor: AppTheme.emeraldGreen,
          onChanged: (v) => setState(() => _isActive = v),
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(color: Colors.white24, height: 32),
        const Text('Ciblage Horaire', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: _validTimeStart ?? const TimeOfDay(hour: 0, minute: 0));
                  if (time != null) setState(() => _validTimeStart = time);
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco(_validTimeStart == null ? 'Heure début' : '${_validTimeStart!.hour.toString().padLeft(2, '0')}:${_validTimeStart!.minute.toString().padLeft(2, '0')}').copyWith(
                      suffixIcon: _validTimeStart != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.white54), onPressed: () => setState(() => _validTimeStart = null)) : const Icon(Icons.access_time, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: _validTimeEnd ?? const TimeOfDay(hour: 23, minute: 59));
                  if (time != null) setState(() => _validTimeEnd = time);
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco(_validTimeEnd == null ? 'Heure fin' : '${_validTimeEnd!.hour.toString().padLeft(2, '0')}:${_validTimeEnd!.minute.toString().padLeft(2, '0')}').copyWith(
                      suffixIcon: _validTimeEnd != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.white54), onPressed: () => setState(() => _validTimeEnd = null)) : const Icon(Icons.access_time, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Jours de validité (Laissez vide pour tous)', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(7, (index) {
            final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
            final dayVal = index + 1; // 1=Monday
            final isSel = _validDaysOfWeek.contains(dayVal);
            return FilterChip(
              label: Text(days[index], style: TextStyle(color: isSel ? Colors.black : Colors.white)),
              selected: isSel,
              selectedColor: AppTheme.emeraldGreen,
              backgroundColor: Colors.black26,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _validDaysOfWeek.add(dayVal);
                  } else {
                    _validDaysOfWeek.remove(dayVal);
                  }
                });
              },
            );
          }),
        ),
        const Divider(color: Colors.white24, height: 32),
        const Text('Ciblage par Restaurant (Exclusivité)', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final items = snapshot.data!.docs;
            return DropdownButtonFormField<String?>(
              value: _selectedTargetRestaurantId,
              dropdownColor: AppTheme.lighterDarkBackground,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('Restaurant Cible (Optionnel)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tous les restaurants')),
                ...items.map((e) => DropdownMenuItem(value: e.id, child: Text(e['name'] as String)))
              ],
              onChanged: (v) => setState(() => _selectedTargetRestaurantId = v),
            );
          }
        ),
        const Divider(color: Colors.white24, height: 32),
        const Text('Ciblage par Historique (Nouveaux clients, Habitués...)', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _minOrdersCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Nb Commandes Min (Inclus)'))),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _maxOrdersCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Nb Commandes Max (Inclus)'))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _minTotalSpentCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Dépense Min (€)'))),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _maxTotalSpentCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Dépense Max (€)'))),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(0),
        child: SizedBox(
          width: 1000,
          height: 700,
          child: Column(
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.carousel == null ? 'Créer une Bannière' : 'Modifier la Bannière', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              
              // BODY
              Expanded(
                child: Form(
                  key: _formKey,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT: LIVE PREVIEW
                      Container(
                        width: 360,
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          border: Border(right: BorderSide(color: Colors.white24)),
                        ),
                        child: Center(child: _buildLivePreview()),
                      ),
                      
                      // RIGHT: CONFIG TABS
                      Expanded(
                        child: Column(
                          children: [
                            TabBar(
                              controller: _tabController,
                              indicatorColor: AppTheme.emeraldGreen,
                              labelColor: AppTheme.emeraldGreen,
                              unselectedLabelColor: Colors.white54,
                              tabs: const [
                                Tab(icon: Icon(Icons.palette), text: 'Design'),
                                Tab(icon: Icon(Icons.touch_app), text: 'Action'),
                                Tab(icon: Icon(Icons.track_changes), text: 'Ciblage'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildDesignTab(),
                                  _buildActionTab(),
                                  _buildTargetingTab(),
                                ],
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              
              // FOOTER
              const Divider(color: Colors.white24, height: 1),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Enregistrer la Bannière', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
