import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final langService = LanguageService();
  bool isLoading = true;
  bool isSaving = false;
  bool _obscurePassword = true;

  final usernameCtrl = TextEditingController();
  final shopNameCtrl = TextEditingController();
  final ownerNameCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    shopNameCtrl.dispose();
    ownerNameCtrl.dispose();
    mobileCtrl.dispose();
    emailCtrl.dispose();
    cityCtrl.dispose();
    newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.getProfile();
      if (res['success'] && mounted) {
        final data = res['data'];
        usernameCtrl.text = data['username'] ?? '';
        shopNameCtrl.text = data['shop_name'] ?? '';
        ownerNameCtrl.text = data['owner_name'] ?? '';
        mobileCtrl.text = data['mobile'] ?? '';
        emailCtrl.text = data['email'] ?? '';
        cityCtrl.text = data['city'] ?? '';
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to load profile'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(langService.t('Error loading profile: $e', 'پروفائل لوڈ کرنے میں خرابی: $e')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (shopNameCtrl.text.trim().isEmpty || ownerNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langService.t('Shop name and owner name are required', 'دکان کا نام اور مالک کا نام ضروری ہے')),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final res = await ApiService.updateProfile(
        shopName: shopNameCtrl.text.trim(),
        ownerName: ownerNameCtrl.text.trim(),
        mobile: mobileCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        city: cityCtrl.text.trim(),
        newPassword: newPasswordCtrl.text.trim().isNotEmpty ? newPasswordCtrl.text.trim() : null,
      );

      if (mounted) {
        if (res['success']) {
          newPasswordCtrl.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(langService.t('Profile updated successfully!', 'پروفائل کامیابی سے محفوظ ہو گیا!')),
              backgroundColor: const Color(0xFF0F5132),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Update failed'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(langService.t('Error saving profile: $e', 'پروفائل محفوظ کرنے میں خرابی: $e')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F5132);

    return Scaffold(
      appBar: AppBar(
        title: Text(langService.t('Shop Profile & Settings', 'دکان کی پروفائل اور سیٹنگز')),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: primaryColor.withOpacity(0.12),
                          child: const Icon(Icons.store, size: 40, color: primaryColor),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          shopNameCtrl.text.isNotEmpty ? shopNameCtrl.text : langService.t('Shop Profile', 'دکان کی پروفائل'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Username (Fixed)
                      TextField(
                        controller: usernameCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: langService.t('Username (Fixed)', 'یوزر نیم (تبدیل نہیں ہو سکتا)'),
                          prefixIcon: const Icon(Icons.account_circle),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Owner Name
                      TextField(
                        controller: ownerNameCtrl,
                        decoration: InputDecoration(
                          labelText: langService.t('Owner Name (Malik) *', 'مالک کا نام *'),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Shop Name
                      TextField(
                        controller: shopNameCtrl,
                        decoration: InputDecoration(
                          labelText: langService.t('Shop Name *', 'دکان کا نام *'),
                          prefixIcon: const Icon(Icons.storefront),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Mobile Number
                      TextField(
                        controller: mobileCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: langService.t('Mobile Number *', 'موبائل نمبر *'),
                          prefixIcon: const Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Email Address
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: langService.t('Email Address (ای میل)', 'ای میل ایڈریس'),
                          hintText: 'user@example.com',
                          prefixIcon: const Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // City / Mandi Location
                      TextField(
                        controller: cityCtrl,
                        decoration: InputDecoration(
                          labelText: langService.t('City / Mandi Location *', 'شہر / منڈی کا مقام *'),
                          prefixIcon: const Icon(Icons.location_city),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Divider(),
                      const SizedBox(height: 12),

                      Text(
                        langService.t('Change Password', 'پاسورڈ تبدیل کریں'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryColor),
                      ),
                      const SizedBox(height: 8),

                      // New Password Field with Eye Toggle
                      TextField(
                        controller: newPasswordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: langService.t('New Password (Leave empty to keep current)', 'نیا پاسورڈ (موجودہ رکھنے کیلئے خالی چھوڑیں)'),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey.shade600,
                            ),
                            tooltip: _obscurePassword ? 'Show Password' : 'Hide Password',
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isSaving ? null : _saveProfile,
                          icon: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            isSaving
                                ? langService.t('Saving...', 'محفوظ ہو رہا ہے...')
                                : langService.t('Save Profile Changes', 'تبدیلیاں محفوظ کریں'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
