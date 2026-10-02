import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReceivingScreen extends StatefulWidget {
  const ReceivingScreen({super.key});

  @override
  State<ReceivingScreen> createState() => _ReceivingScreenState();
}

class _ReceivingScreenState extends State<ReceivingScreen> {
  bool isLoading = true;
  List<dynamic> receivings = [];
  List<dynamic> farmers = [];
  List<dynamic> crops = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final recs = await ApiService.getReceivings();
      final fList = await ApiService.getParties(partyType: 'Farmer');
      final cList = await ApiService.getCrops();
      if (mounted) {
        setState(() {
          receivings = recs;
          farmers = fList;
          crops = cList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showQuickAddFarmerDialog(Function(int newFarmerId) onFarmerCreated) {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naya Farmer Add Karein (نیا کسان)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Farmer Name (نام)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mobileCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile No (موبائل)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final res = await ApiService.createParty({
                'name': nameCtrl.text.trim(),
                'mobile': mobileCtrl.text.trim(),
                'party_type': 'Farmer',
                'opening_balance': 0.0,
                'balance_type': 'Receivable',
              });
              if (res['success']) {
                Navigator.pop(ctx);
                final fList = await ApiService.getParties(partyType: 'Farmer');
                setState(() => farmers = fList);
                onFarmerCreated(res['data']['party_id']);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Naya Farmer kamyabi se add ho gaya!')),
                );
              }
            },
            child: const Text('Save Farmer'),
          ),
        ],
      ),
    );
  }

  void _showAddReceivingModal() {
    int? farmerId = farmers.isNotEmpty ? farmers[0]['id'] : null;
    int? cropId = crops.isNotEmpty ? crops[0]['id'] : null;

    final bagsCtrl = TextEditingController(text: '100');
    final grossCtrl = TextEditingController(text: '4000');
    final tareCtrl = TextEditingController(text: '100');
    final moistureCtrl = TextEditingController(text: '0');
    final deductionCtrl = TextEditingController(text: '0');
    bool isSaving = false;

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
                const Text('Fasal Aamad Entry (آمد درج کریں)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: farmerId,
                        decoration: const InputDecoration(labelText: 'Select Farmer (کسان)'),
                        items: farmers.map((f) {
                          return DropdownMenuItem<int>(
                            value: f['id'],
                            child: Text(f['name']),
                          );
                        }).toList(),
                        onChanged: (v) => setModalState(() => farmerId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.person_add, color: Color(0xFF0F5132)),
                      tooltip: 'Add New Farmer',
                      onPressed: () {
                        _showQuickAddFarmerDialog((newId) {
                          setModalState(() => farmerId = newId);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: cropId,
                  decoration: const InputDecoration(labelText: 'Select Crop (جنس)'),
                  items: crops.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'],
                      child: Text(c['name']),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => cropId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: bagsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Bags (بوریاں)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: grossCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Gross Wt KG (کل وزن)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tareCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Tare Wt KG (کاٹ)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: deductionCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Katt Deduction KG'),
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
                    onPressed: isSaving ? null : () async {
                      if (farmerId == null || cropId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Baraye meharbani Farmer aur Crop select karein.')),
                        );
                        return;
                      }

                      final grossVal = double.tryParse(grossCtrl.text) ?? 0.0;
                      if (grossVal <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Baraye meharbani Gross Weight (وزن) enter karein.')),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);
                      final res = await ApiService.createReceiving({
                        'farmer_id': farmerId,
                        'crop_id': cropId,
                        'bags': int.tryParse(bagsCtrl.text) ?? 0,
                        'gross_weight': grossVal,
                        'tare_weight': double.tryParse(tareCtrl.text) ?? 0.0,
                        'moisture_percent': double.tryParse(moistureCtrl.text) ?? 0.0,
                        'deduction_kg': double.tryParse(deductionCtrl.text) ?? 0.0,
                      });
                      setModalState(() => isSaving = false);

                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fasal Aamad successfully darj ho gayi!')),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['error'] ?? 'Fasal Aamad darj nahi ho saki.'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Aamad (آمد محفوظ کریں)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditReceivingModal(Map<String, dynamic> r) {
    int farmerId = r['farmer_id'] ?? (farmers.isNotEmpty ? farmers[0]['id'] : 1);
    int cropId = r['crop_id'] ?? (crops.isNotEmpty ? crops[0]['id'] : 1);

    final bagsCtrl = TextEditingController(text: r['bags'].toString());
    final grossCtrl = TextEditingController(text: r['gross_weight'].toString());
    final tareCtrl = TextEditingController(text: r['tare_weight'].toString());
    final deductionCtrl = TextEditingController(text: r['deduction_kg'].toString());
    bool isSaving = false;

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
                Text('Edit Aamad Record (${r['receipt_no']})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: farmerId,
                  decoration: const InputDecoration(labelText: 'Select Farmer (کسان)'),
                  items: farmers.map((f) => DropdownMenuItem<int>(value: f['id'], child: Text(f['name']))).toList(),
                  onChanged: (v) => setModalState(() => farmerId = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: cropId,
                  decoration: const InputDecoration(labelText: 'Select Crop (جنس)'),
                  items: crops.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['name']))).toList(),
                  onChanged: (v) => setModalState(() => cropId = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: bagsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Bags (بوریاں)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: grossCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Gross Wt KG (کل وزن)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tareCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Tare Wt KG (کاٹ)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: deductionCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Katt Deduction KG'),
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
                    onPressed: isSaving ? null : () async {
                      setModalState(() => isSaving = true);
                      final res = await ApiService.updateReceiving(r['id'], {
                        'farmer_id': farmerId,
                        'crop_id': cropId,
                        'bags': int.tryParse(bagsCtrl.text) ?? 0,
                        'gross_weight': double.tryParse(grossCtrl.text) ?? 0.0,
                        'tare_weight': double.tryParse(tareCtrl.text) ?? 0.0,
                        'moisture_percent': 0.0,
                        'deduction_kg': double.tryParse(deductionCtrl.text) ?? 0.0,
                        'bardana_charge': 0.0,
                        'transport_charge': 0.0,
                      });
                      setModalState(() => isSaving = false);

                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Aamad record successfully update ho gaya!')),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['error'] ?? 'Update nahi ho saka.'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Update Aamad (آمد تبدیل کریں)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteReceiving(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aamad Record Delete Karein?'),
        content: Text('Kya aap genuinely receipt ${r['receipt_no']} delete karna chahte hain?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              final ok = await ApiService.deleteReceiving(r['id']);
              if (ok) {
                if (mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Aamad record delete ho gaya.')),
                );
                _loadData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Delete nahi ho saka. Agar yeh sell ho chuki hai to pehle sale delete karein.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete'),
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
        onPressed: _showAddReceivingModal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : receivings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.grass, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Koi fasal aamad record nahi mila.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Nayi fasal aamad darj karne ke liye niche + button par click karein.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: receivings.length,
                    itemBuilder: (ctx, i) {
                      final r = receivings[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF0F5132),
                            child: Icon(Icons.grass, color: Colors.white),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text('${r['farmer_name']} - ${r['crop_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                onPressed: () => _showEditReceivingModal(r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                onPressed: () => _confirmDeleteReceiving(r),
                              ),
                            ],
                          ),
                          subtitle: Text('Receipt: ${r['receipt_no']}\nBags: ${r['bags']} • Net: ${r['final_weight']} KG'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: r['status'] == 'Settled' ? Colors.green.shade100 : Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r['status'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: r['status'] == 'Settled' ? Colors.green.shade800 : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
