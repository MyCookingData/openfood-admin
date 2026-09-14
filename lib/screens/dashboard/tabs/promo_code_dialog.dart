import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'package:openfood_models/openfood_models.dart';

class PromoCodeDialog extends StatefulWidget {
  final PromoCodeModel? promoCode;

  const PromoCodeDialog({super.key, this.promoCode});

  @override
  State<PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends State<PromoCodeDialog> {
  bool _isGlobal = true;
  final _codeCtrl = TextEditingController();
  final _batchCountCtrl = TextEditingController(text: '10');
  
  PromotionType _type = PromotionType.percentage;
  final _valueCtrl = TextEditingController();
  
  PromoTarget _target = PromoTarget.cart_subtotal;
  
  final _maxUsesCtrl = TextEditingController();
  DateTime? _expirationDate;
  
  final _minAmountCtrl = TextEditingController();
  final _minQuantityCtrl = TextEditingController();
  
  final _maxUsesPerUserCtrl = TextEditingController();
  final _successMessageCtrl = TextEditingController();
  String? _selectedRestaurantId;
  String? _selectedRestaurantName;
  List<String> _selectedProductIds = [];
  bool _firstOrderOnly = false;
  
  TimeOfDay? _validTimeStart;
  TimeOfDay? _validTimeEnd;
  List<int> _validDaysOfWeek = [];
  
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.promoCode != null) {
      final p = widget.promoCode!;
      _isGlobal = p.isGlobal;
      _codeCtrl.text = p.code;
      _type = p.type;
      _valueCtrl.text = p.value.toString();
      _target = p.discountTarget;
      _maxUsesCtrl.text = p.maxUses?.toString() ?? '';
      _maxUsesPerUserCtrl.text = p.maxUsesPerUser?.toString() ?? '';
      _successMessageCtrl.text = p.successMessage ?? '';
      _firstOrderOnly = p.firstOrderOnly;
      _expirationDate = p.expirationDate;
      if (p.validTimeStart != null) {
        final parts = p.validTimeStart!.split(':');
        _validTimeStart = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (p.validTimeEnd != null) {
        final parts = p.validTimeEnd!.split(':');
        _validTimeEnd = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      _validDaysOfWeek = p.validDaysOfWeek ?? [];
      
      _minAmountCtrl.text = p.minAmount?.toString() ?? '';
      _minQuantityCtrl.text = p.minQuantity?.toString() ?? '';
      _selectedRestaurantId = p.requiredRestaurantId;
      _selectedProductIds = List.from(p.applicableProductIds ?? []);
      _isActive = p.isActive;
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> _submit() async {
    final value = double.tryParse(_valueCtrl.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer une valeur valide.')));
      return;
    }

    if (_isGlobal && _codeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer un code global.')));
      return;
    }

    int batchCount = 1;
    if (!_isGlobal && widget.promoCode == null) {
      batchCount = int.tryParse(_batchCountCtrl.text) ?? 10;
      if (batchCount <= 0) batchCount = 1;
    }

    setState(() => _isLoading = true);

    try {
      final maxUses = int.tryParse(_maxUsesCtrl.text);
      final maxUsesPerUser = int.tryParse(_maxUsesPerUserCtrl.text);
      final minAmount = double.tryParse(_minAmountCtrl.text.replaceAll(',', '.'));
      final minQuantity = int.tryParse(_minQuantityCtrl.text);
      final successMessage = _successMessageCtrl.text.trim();
      final restaurantId = _selectedRestaurantId;
      final productIds = _selectedProductIds.isNotEmpty ? _selectedProductIds : null;
      
      final String? timeStartStr = _validTimeStart != null ? '${_validTimeStart!.hour.toString().padLeft(2, '0')}:${_validTimeStart!.minute.toString().padLeft(2, '0')}' : null;
      final String? timeEndStr = _validTimeEnd != null ? '${_validTimeEnd!.hour.toString().padLeft(2, '0')}:${_validTimeEnd!.minute.toString().padLeft(2, '0')}' : null;
      
      final batchId = (!_isGlobal && widget.promoCode == null) ? FirebaseFirestore.instance.collection('promo_codes').doc().id : widget.promoCode?.batchId;

      final batch = FirebaseFirestore.instance.batch();

      if (widget.promoCode != null) {
        // Edit mode
        final docRef = FirebaseFirestore.instance.collection('promo_codes').doc(widget.promoCode!.id);
        final updatedPromo = PromoCodeModel(
          id: widget.promoCode!.id,
          code: _isGlobal ? _codeCtrl.text.trim().toUpperCase() : widget.promoCode!.code,
          type: _type,
          value: value,
          isActive: _isActive,
          isGlobal: widget.promoCode!.isGlobal,
          maxUses: maxUses,
          currentUses: widget.promoCode!.currentUses,
          maxUsesPerUser: maxUsesPerUser,
          firstOrderOnly: _firstOrderOnly,
          validDaysOfWeek: _validDaysOfWeek.isEmpty ? null : _validDaysOfWeek,
          validTimeStart: timeStartStr,
          validTimeEnd: timeEndStr,
          successMessage: successMessage.isNotEmpty ? successMessage : null,
          expirationDate: _expirationDate,
          minAmount: minAmount,
          minQuantity: minQuantity,
          requiredRestaurantId: restaurantId,
          applicableProductIds: productIds,
          discountTarget: _target,
          batchId: widget.promoCode!.batchId,
          createdAt: widget.promoCode!.createdAt,
        );
        batch.update(docRef, updatedPromo.toJson());
      } else {
        // Create mode
        if (_isGlobal) {
          final docRef = FirebaseFirestore.instance.collection('promo_codes').doc();
          final newPromo = PromoCodeModel(
            id: docRef.id,
            code: _codeCtrl.text.trim().toUpperCase(),
            type: _type,
            value: value,
            isActive: _isActive,
            isGlobal: true,
            maxUses: maxUses,
            maxUsesPerUser: maxUsesPerUser,
            firstOrderOnly: _firstOrderOnly,
            validDaysOfWeek: _validDaysOfWeek.isEmpty ? null : _validDaysOfWeek,
            validTimeStart: timeStartStr,
            validTimeEnd: timeEndStr,
            successMessage: successMessage.isNotEmpty ? successMessage : null,
            expirationDate: _expirationDate,
            minAmount: minAmount,
            minQuantity: minQuantity,
            requiredRestaurantId: restaurantId,
            applicableProductIds: productIds,
            discountTarget: _target,
          );
          batch.set(docRef, newPromo.toJson());
        } else {
          for (int i = 0; i < batchCount; i++) {
            final docRef = FirebaseFirestore.instance.collection('promo_codes').doc();
            final newPromo = PromoCodeModel(
              id: docRef.id,
              code: _generateRandomCode(),
              type: _type,
              value: value,
              isActive: _isActive,
              isGlobal: false,
              maxUses: maxUses ?? 1, // Default to 1 for unitary codes if not specified
              maxUsesPerUser: maxUsesPerUser,
              firstOrderOnly: _firstOrderOnly,
              validDaysOfWeek: _validDaysOfWeek.isEmpty ? null : _validDaysOfWeek,
              validTimeStart: timeStartStr,
              validTimeEnd: timeEndStr,
              successMessage: successMessage.isNotEmpty ? successMessage : null,
              expirationDate: _expirationDate,
              minAmount: minAmount,
              minQuantity: minQuantity,
              requiredRestaurantId: restaurantId,
              applicableProductIds: productIds,
              discountTarget: _target,
              batchId: batchId,
            );
            batch.set(docRef, newPromo.toJson());
          }
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Codes Promo enregistrés !'), backgroundColor: AppTheme.emeraldGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.emeraldGreen,
              surface: AppTheme.darkBackground,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _expirationDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 800,
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
                Text(widget.promoCode == null ? 'Nouveau Code Promo' : 'Éditer Code Promo', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(color: Colors.white24, height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TYPE (Global / Unitaire)
                    if (widget.promoCode == null)
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Global (ex: ETE20)', style: TextStyle(color: Colors.white)),
                              value: true,
                              groupValue: _isGlobal,
                              activeColor: AppTheme.emeraldGreen,
                              onChanged: (v) => setState(() => _isGlobal = v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Unitaire (Aléatoire)', style: TextStyle(color: Colors.white)),
                              value: false,
                              groupValue: _isGlobal,
                              activeColor: AppTheme.emeraldGreen,
                              onChanged: (v) => setState(() => _isGlobal = v!),
                            ),
                          ),
                        ],
                      ),

                    if (_isGlobal)
                      _buildTextField('Code (ex: SUMMER10)', _codeCtrl, enabled: widget.promoCode == null)
                    else if (widget.promoCode == null)
                      _buildTextField('Nombre de codes à générer', _batchCountCtrl, isNumber: true),

                    if (widget.promoCode != null && !widget.promoCode!.isGlobal)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text('Code: ${widget.promoCode!.code} (Unitaire)', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ),

                    const SizedBox(height: 16),
                    const Text('Valeur de la Réduction', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<PromotionType>(
                            value: _type,
                            dropdownColor: AppTheme.lighterDarkBackground,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDeco('Type'),
                            items: const [
                              DropdownMenuItem(value: PromotionType.percentage, child: Text('Pourcentage (%)')),
                              DropdownMenuItem(value: PromotionType.fixed, child: Text('Montant Fixe (€)')),
                            ],
                            onChanged: (v) => setState(() => _type = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('Valeur', _valueCtrl, isNumber: true)),
                      ],
                    ),

                    const SizedBox(height: 16),
                    DropdownButtonFormField<PromoTarget>(
                      value: _target,
                      dropdownColor: AppTheme.lighterDarkBackground,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco('Appliquer la réduction sur'),
                      items: PromoTarget.values.map((t) {
                        String label = '';
                        switch (t) {
                          case PromoTarget.cart_subtotal: label = 'Sous-total du panier'; break;
                          case PromoTarget.selected_products: label = 'Produits sélectionnés'; break;
                          case PromoTarget.most_expensive: label = 'Produit le plus cher'; break;
                          case PromoTarget.least_expensive: label = 'Produit le moins cher'; break;
                          case PromoTarget.delivery_fee: label = 'Frais de livraison'; break;
                        }
                        return DropdownMenuItem(value: t, child: Text(label));
                      }).toList(),
                      onChanged: (v) => setState(() => _target = v!),
                    ),

                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        final items = snapshot.data!.docs;
                        String? val;
                        if (_selectedRestaurantId != null) {
                          if (items.any((e) => e.id == _selectedRestaurantId)) {
                            val = _selectedRestaurantId;
                          } else if (items.any((e) => e['name'] == _selectedRestaurantId)) {
                            val = items.firstWhere((e) => e['name'] == _selectedRestaurantId).id;
                          }
                        }
                        return DropdownButtonFormField<String?>(
                          value: val,
                          dropdownColor: AppTheme.lighterDarkBackground,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDeco('Restaurant requis (Optionnel)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tous les restaurants')),
                            ...items.map((e) => DropdownMenuItem(value: e.id, child: Text(e['name'] as String)))
                          ],
                          onChanged: (v) => setState(() {
                            _selectedRestaurantId = v;
                            if (v != null) {
                              final doc = items.firstWhere((e) => e.id == v);
                              _selectedRestaurantName = doc['name'] as String;
                            } else {
                              _selectedRestaurantName = null;
                            }
                            _selectedProductIds.clear(); // reset products when resto changes
                          }),
                        );
                      }
                    ),

                    if (_selectedRestaurantId != null) ...[
                      const SizedBox(height: 16),
                      const Text('Produits applicables (Laissez vide pour tout le restaurant)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('products').where('restaurantId', isEqualTo: _selectedRestaurantId).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          final products = snapshot.data!.docs;
                          if (products.isEmpty) return const Text('Aucun produit trouvé pour ce restaurant.', style: TextStyle(color: Colors.white54));
                          
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: products.map((doc) {
                              final name = doc['name'] as String;
                              final isSel = _selectedProductIds.contains(doc.id);
                              return FilterChip(
                                label: Text(name, style: TextStyle(color: isSel ? Colors.black : Colors.white)),
                                selected: isSel,
                                selectedColor: AppTheme.emeraldGreen,
                                backgroundColor: AppTheme.lighterDarkBackground,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) _selectedProductIds.add(doc.id);
                                    else _selectedProductIds.remove(doc.id);
                                  });
                                },
                              );
                            }).toList(),
                          );
                        }
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Text('Conditions & Limites', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Montant panier min (€)', _minAmountCtrl, isNumber: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('Nb d\'articles min', _minQuantityCtrl, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Utilisations max (TOTAL)', _maxUsesCtrl, isNumber: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('Utilisations max PAR CLIENT', _maxUsesPerUserCtrl, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Message de succès personnalisé', _successMessageCtrl),
                    
                    const SizedBox(height: 16),
                    const Text('Restrictions de Temps', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: AbsorbPointer(
                              child: TextFormField(
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDeco(
                                  _expirationDate == null ? 'Date d\'expiration' : DateFormat('dd/MM/yyyy HH:mm').format(_expirationDate!),
                                ).copyWith(
                                  suffixIcon: _expirationDate != null
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, color: Colors.white54),
                                          onPressed: () => setState(() => _expirationDate = null),
                                        )
                                      : const Icon(Icons.calendar_today, color: Colors.white54),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    const Text('Jours de validité (Laissez vide pour tous les jours)', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                          backgroundColor: AppTheme.lighterDarkBackground,
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
                    SwitchListTile(
                      title: const Text('Réservé à la Première Commande', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Nouveaux clients uniquement', style: TextStyle(color: Colors.white54)),
                      value: _firstOrderOnly,
                      activeColor: AppTheme.emeraldGreen,
                      onChanged: (v) => setState(() => _firstOrderOnly = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Code Actif', style: TextStyle(color: Colors.white)),
                      value: _isActive,
                      activeColor: AppTheme.emeraldGreen,
                      onChanged: (v) => setState(() => _isActive = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Enregistrer'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.emeraldGreen)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isNumber = false, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: ctrl,
        enabled: enabled,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(color: enabled ? Colors.white : Colors.white54),
        decoration: _inputDeco(label),
      ),
    );
  }
}





