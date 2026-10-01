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
      if (mounted) {
        setState(() {
          receivings = recs;
          farmers = fList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddReceivingModal() {
    int? farmerId = farmers.isNotEmpty ? farmers[0]['id'] : null;
    int cropId = 1; // Default Gandum Wheat
    final bagsCtrl = TextEditingController(text: '0');
    final grossCtrl = TextEditingController(text: '0');
    final tareCtrl = TextEditingController(text: '0');
    final moistureCtrl = TextEditingController(text: '0');
    final deductionCtrl = TextEditingController(text: '0');

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
                DropdownButtonFormField<int>(
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
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: cropId,
                  decoration: const InputDecoration(labelText: 'Select Crop (جنس)'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Gandum (Wheat)')),
                    DropdownMenuItem(value: 2, child: Text('Chana (Chickpeas)')),
                    DropdownMenuItem(value: 3, child: Text('Cotton (Kapas)')),
                    DropdownMenuItem(value: 4, child: Text('Rice (Basmati)')),
                    DropdownMenuItem(value: 5, child: Text('Maize (Makai)')),
                  ],
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
                        decoration: const InputDecoration(labelText: 'Tare Wt KG (کاٹ کاٹ)'),
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
                    onPressed: () async {
                      if (farmerId == null) return;
                      final res = await ApiService.createReceiving({
                        'farmer_id': farmerId,
                        'crop_id': cropId,
                        'bags': int.tryParse(bagsCtrl.text) ?? 0,
                        'gross_weight': double.tryParse(grossCtrl.text) ?? 0.0,
                        'tare_weight': double.tryParse(tareCtrl.text) ?? 0.0,
                        'moisture_percent': double.tryParse(moistureCtrl.text) ?? 0.0,
                        'deduction_kg': double.tryParse(deductionCtrl.text) ?? 0.0,
                      });
                      if (res['success']) {
                        if (mounted) Navigator.pop(ctx);
                        _loadData();
                      }
                    },
                    child: const Text('Save Aamad (آمد محفوظ کریں)'),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              ? const Center(child: Text('Koi fasal aamad record nahi mila.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: receivings.length,
                  itemBuilder: (ctx, i) {
                    final r = receivings[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF0F5132),
                          child: Icon(Icons.grass, color: Colors.white),
                        ),
                        title: Text('${r['farmer_name']} - ${r['crop_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Receipt: ${r['receipt_no']} • Bags: ${r['bags']} • Net: ${r['final_weight']} KG'),
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
    );
  }
}
