import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'ledger_screen.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  bool isLoading = true;
  List<dynamic> parties = [];
  String selectedType = 'All';
  final formatter = NumberFormat('#,##0.00', 'en_US');
  final langService = LanguageService();

  @override
  void initState() {
    super.initState();
    _loadParties();
    langService.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    langService.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadParties() async {
    setState(() => isLoading = true);
    try {
      final list = await ApiService.getParties(partyType: selectedType);
      if (mounted) {
        setState(() {
          parties = list;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddPartyModal() {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final cnicCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final openingBalCtrl = TextEditingController(text: '0');
    String type = 'Farmer';
    String balType = 'Receivable';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langService.t('Add New Account', 'نیا کھاتہ شامل کریں'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: langService.t('Party Name', 'نام')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: langService.t('Mobile Number', 'موبائل نمبر')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: InputDecoration(labelText: langService.t('Party Type', 'قسم')),
                  items: [
                    DropdownMenuItem(value: 'Farmer', child: Text(langService.t('Farmer / Seller', 'کسان / فروخت کنندہ'))),
                    DropdownMenuItem(value: 'Seller', child: Text(langService.t('Seller', 'بیوپاری / فروخت کنندہ'))),
                    DropdownMenuItem(value: 'Buyer', child: Text(langService.t('Buyer', 'خریدار / مل'))),
                    DropdownMenuItem(value: 'Supplier', child: Text(langService.t('Supplier', 'سپلائر'))),
                  ],
                  onChanged: (v) => setModalState(() => type = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: openingBalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: langService.t('Opening Balance', 'ابتدائی رقم')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: balType,
                        decoration: InputDecoration(labelText: langService.t('Status', 'حیثیت')),
                        items: [
                          DropdownMenuItem(value: 'Receivable', child: Text(langService.t('Lena Hai (Receivable)', 'وصولی (لینا ہے)'))),
                          DropdownMenuItem(value: 'Payable', child: Text(langService.t('Dena Hai (Payable)', 'ادائیگی (دینا ہے)'))),
                        ],
                        onChanged: (v) => setModalState(() => balType = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final res = await ApiService.createParty({
                        'name': nameCtrl.text.trim(),
                        'mobile': mobileCtrl.text.trim(),
                        'cnic': cnicCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'party_type': type,
                        'opening_balance': double.tryParse(openingBalCtrl.text) ?? 0.0,
                        'balance_type': balType,
                      });
                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        _loadParties();
                      }
                    },
                    child: Text(langService.t('Save Account', 'محفوظ کریں')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPartyModal(Map<String, dynamic> party) {
    final nameCtrl = TextEditingController(text: party['name']);
    final mobileCtrl = TextEditingController(text: party['mobile'] ?? '');
    final cnicCtrl = TextEditingController(text: party['cnic'] ?? '');
    final addressCtrl = TextEditingController(text: party['address'] ?? '');
    final openingBalCtrl = TextEditingController(text: (party['balance'] ?? 0.0).toString());
    String type = party['party_type'] ?? 'Farmer';
    String balType = (party['balance_status'] ?? '').contains('Lena') ? 'Receivable' : 'Payable';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langService.t('Edit Party Account', 'کھاتہ تبدیل کریں'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: langService.t('Party Name', 'نام')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: langService.t('Mobile Number', 'موبائل نمبر')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: InputDecoration(labelText: langService.t('Party Type', 'قسم')),
                  items: [
                    DropdownMenuItem(value: 'Farmer', child: Text(langService.t('Farmer / Seller', 'کسان / فروخت کنندہ'))),
                    DropdownMenuItem(value: 'Seller', child: Text(langService.t('Seller', 'بیوپاری / فروخت کنندہ'))),
                    DropdownMenuItem(value: 'Buyer', child: Text(langService.t('Buyer', 'خریدار / مل'))),
                    DropdownMenuItem(value: 'Supplier', child: Text(langService.t('Supplier', 'سپلائر'))),
                  ],
                  onChanged: (v) => setModalState(() => type = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: openingBalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: langService.t('Opening Balance', 'ابتدائی رقم')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: balType,
                        decoration: InputDecoration(labelText: langService.t('Status', 'حیثیت')),
                        items: [
                          DropdownMenuItem(value: 'Receivable', child: Text(langService.t('Lena Hai', 'وصولی (لینا ہے)'))),
                          DropdownMenuItem(value: 'Payable', child: Text(langService.t('Dena Hai', 'ادائیگی (دینا ہے)'))),
                        ],
                        onChanged: (v) => setModalState(() => balType = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final res = await ApiService.updateParty(party['id'], {
                        'name': nameCtrl.text.trim(),
                        'mobile': mobileCtrl.text.trim(),
                        'cnic': cnicCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'party_type': type,
                        'opening_balance': double.tryParse(openingBalCtrl.text) ?? 0.0,
                        'balance_type': balType,
                      });
                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        _loadParties();
                      }
                    },
                    child: Text(langService.t('Update Account', 'کھاتہ تبدیل کریں')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteParty(Map<String, dynamic> party) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(langService.t('Delete Account?', 'کھاتہ ختم کریں؟')),
        content: Text(langService.t(
          'Are you sure you want to delete ${party['name']} and all associated ledger history?',
          'کیا آپ واقعی ${party['name']} کا کھاتہ ختم کرنا چاہتے ہیں؟',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(langService.t('Cancel', 'منسوخ')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              final ok = await ApiService.deleteParty(party['id']);
              if (ok) {
                if (mounted) Navigator.pop(ctx);
                _loadParties();
              }
            },
            child: Text(langService.t('Delete', 'ختم کریں')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F5132),
        onPressed: _showAddPartyModal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Farmer', 'Seller', 'Buyer', 'Supplier'].map((type) {
                  final isSel = selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(langService.t(type, type)),
                      selected: isSel,
                      selectedColor: const Color(0xFF0F5132),
                      labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() => selectedType = type);
                          _loadParties();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : parties.isEmpty
                    ? Center(child: Text(langService.t('No accounts found.', 'کوئی کھاتہ نہیں ملا۔')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: parties.length,
                        itemBuilder: (ctx, i) {
                          final p = parties[i];
                          final bool isReceivable = (p['balance_status'] ?? '').contains('Lena');
                          final Color balColor = isReceivable ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0F5132).withOpacity(0.1),
                                child: Icon(
                                  p['party_type'] == 'Farmer' ? Icons.person : Icons.store,
                                  color: const Color(0xFF0F5132),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p['name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                    onPressed: () => _showEditPartyModal(p),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                    onPressed: () => _confirmDeleteParty(p),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${p['party_type']} • Mobile: ${p['mobile'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rs. ${formatter.format(p['balance'])}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: balColor),
                                  ),
                                  Text(
                                    langService.t(
                                      isReceivable ? 'Lena Hai' : 'Dena Hai',
                                      isReceivable ? 'وصولی (لینا ہے)' : 'ادائیگی (دینا ہے)',
                                    ),
                                    style: TextStyle(fontSize: 10, color: balColor, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => LedgerScreen(
                                      partyId: p['id'],
                                      partyName: p['name'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
