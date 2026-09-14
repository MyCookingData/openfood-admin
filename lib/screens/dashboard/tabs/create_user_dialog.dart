import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';

class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedRole = 'restaurant_owner';
  String? _selectedRestaurantId;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == 'restaurant_owner' && _selectedRestaurantId == null) {
      setState(() => _errorMessage = "Veuillez sélectionner un restaurant.");
      return;
    }
    if (_selectedRole == 'livreur' && _phoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Le numéro de téléphone est requis pour un livreur.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Initialize secondary app to avoid logging out admin
      final secondaryApp = await Firebase.initializeApp(
        name: 'RestaurateurCreationApp_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      final auth = FirebaseAuth.instanceFor(app: secondaryApp);
      
      final credential = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uid = credential.user!.uid;

      // Create UserModel in main firestore
      final userModel = UserModel(
        id: uid,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: _selectedRole,
        restaurantId: _selectedRole == 'restaurant_owner' ? _selectedRestaurantId : null,
        phone: _selectedRole == 'livreur' ? _phoneController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('users').doc(uid).set(userModel.toJson());

      // Delete secondary app instance
      await secondaryApp.delete();

      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        child: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nouvel Utilisateur',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 32),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                _buildTextField('Nom Complet', _nameController, Icons.person),
                const SizedBox(height: 16),
                _buildTextField('Email', _emailController, Icons.email),
                const SizedBox(height: 16),
                _buildTextField('Mot de passe', _passwordController, Icons.lock, obscure: true),
                const SizedBox(height: 16),
                const Text('Type de compte :', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  dropdownColor: AppTheme.lighterDarkBackground,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.emeraldGreen), borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'restaurant_owner', child: Text('Restaurateur', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'livreur', child: Text('Livreur', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedRole = val!);
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedRole == 'restaurant_owner') ...[
                  const Text('Assigner à un restaurant :', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  _buildRestaurantDropdown(),
                ] else if (_selectedRole == 'livreur') ...[
                  _buildTextField('Numéro de téléphone', _phoneController, Icons.phone),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Créer le compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool obscure = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: (val) => val == null || val.isEmpty ? 'Champ requis' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppTheme.emeraldGreen),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildRestaurantDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));
        
        final restaurants = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return RestaurantModel.fromJson(data);
        }).toList();

        return DropdownButtonFormField<String>(
          initialValue: _selectedRestaurantId,
          dropdownColor: AppTheme.lighterDarkBackground,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppTheme.emeraldGreen),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: restaurants.map((r) {
            return DropdownMenuItem(
              value: r.id,
              child: Text(r.name, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: (val) {
            setState(() => _selectedRestaurantId = val);
          },
        );
      },
    );
  }
}
