import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  Widget _buildStepCard({
    required String stepNum,
    required String titleEn,
    required String titleUr,
    required String descEn,
    required String descUr,
    required IconData icon,
    required Color color,
    required List<String> points,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Text(
                    stepNum,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleUr,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        titleEn,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Icon(icon, color: color, size: 28),
              ],
            ),
            const Divider(height: 20),
            Text(
              descUr,
              style: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: points.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 Mandi System Guide (ہدایات)'),
        backgroundColor: const Color(0xFF0F5132),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F5132), Color(0xFF166534)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'غلہ منڈی ای آر پی سسٹم استعمال کرنے کا طریقہ',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Mandi System Walkthrough in 4 Simple Steps',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 1
            _buildStepCard(
              stepNum: '1',
              titleEn: 'Step 1: Create Accounts (Parties)',
              titleUr: '1️⃣ مرحلہ: کھاتے داروں کے کھاتے بنائیں',
              descEn: 'Create accounts for Farmers/Sellers and Buyers/Mills.',
              descUr: 'سب سے پہلے منڈی کے کسانوں (Farmers/Sellers) اور خریداروں (Buyers/Mills) کا کھاتہ درج کریں۔',
              icon: Icons.people,
              color: const Color(0xFF0F5132),
              points: [
                'Farmer/Seller: وہ کسان جو غلہ فروخت کرنے لاتا ہے۔',
                'Buyer/Mill: وہ مل یا بیوپاری جو غلہ خریدتا ہے۔',
                'Opening Balance: پچھلا بقیہ حساب (لینا ہے / دینا ہے) شامل کریں۔',
              ],
            ),

            // Step 2
            _buildStepCard(
              stepNum: '2',
              titleEn: 'Step 2: Fasal Aamad (Receiving)',
              titleUr: '2️⃣ مرحلہ: کسان کی فصل آمد درج کریں',
              descEn: 'Log crop stock received from the farmer at your shop.',
              descUr: 'جب کسان دکان پر فصل لائے تو آمد درج کریں (بوریاں + وزن)۔',
              icon: Icons.grass,
              color: Colors.blue.shade700,
              points: [
                'کسان کا نام اور جنس (گندم، چنا، کاٹن) منتخب کریں۔',
                'بوریاں اور کل وزن (Gross Weight KG) درج کریں۔',
                'سسٹم خود بخود صافی وزن اور کل من (Manns) کیلکولیٹ کر دے گا۔',
              ],
            ),

            // Step 3
            _buildStepCard(
              stepNum: '3',
              titleEn: 'Step 3: Process Sales & Settlement (Bikri)',
              titleUr: '3️⃣ مرحلہ: فروخت کریں اور حساب فائنل کریں',
              descEn: 'Sell crop to Buyer with automated commission & palledari deductions.',
              descUr: 'جب خریدار فصل خریدے تو "Process Sale" سے حساب 1 سیکنڈ میں فائنل کریں۔',
              icon: Icons.shopping_cart_checkout,
              color: Colors.amber.shade900,
              points: [
                'Buyer Bill (+): کل رقم + خریدار کمیشن (+1%) ➔ خریدار کے کھاتے میں "لینا ہے" درج ہوگا۔',
                'Farmer Net (-): کل رقم - کمیشن - مزدوری - بروکری - دوکان اخراجات ➔ کسان کو "دینا ہے"۔',
                'مزدوری، بروکری اور دوکان کے الگ الگ سیکشنز خود بخود منس (Minus) ہوتے ہیں۔',
              ],
            ),

            // Step 4
            _buildStepCard(
              stepNum: '4',
              titleEn: 'Step 4: Ledger & Payments (ادائیگیاں و وصولی)',
              titleUr: '4️⃣ مرحلہ: وصولی و ادائیگی کا کیش واؤچر',
              descEn: 'Record receipts from Buyer and cash payments to Farmer.',
              descUr: 'جب خریدار سے کیش ملے یا کسان کو رقم دیں تو کیش واؤچر کی اینٹری کریں۔',
              icon: Icons.account_balance_wallet,
              color: Colors.purple.shade700,
              points: [
                'Vasooli (Receipt): خریدار سے پیسے ملنے پر "Vasooli" درج کریں ➔ خریدار کا کھاتہ 0 ہو جائے گا۔',
                'Payment (Adaygi): کسان کو رقم دینے پر "Payment" درج کریں ➔ کسان کا کھاتہ 0 ہو جائے گا۔',
                'پرنٹیبل پرچی (Printable Voucher) تیار ہوتی ہے۔',
              ],
            ),

            // Formula Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '💡 Formula Example (مثال کیلیے):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F5132)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Gross Sale: 4,000 KG @ Rs. 100 = Rs. 400,000\n'
                    '• Buyer Total Bill: Rs. 400,000 + 4,000 (1% Comm) = Rs. 404,000\n'
                    '• Farmer Net Amount: Rs. 400,000 - 8,000 (2% Comm) - 2,000 (Palledari) - 1,000 (Brokery) - 1,000 (Shop) = Rs. 388,000',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
