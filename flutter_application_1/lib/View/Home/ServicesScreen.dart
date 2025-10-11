import 'package:flutter/material.dart';
import 'AddExpensePage.dart';
import 'CalculationPage.dart';
import 'FinancialGroupPage.dart';
import 'FinancialReportsPage.dart';
import '../Home/SettlementPage.dart';
import 'expense_history_page.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // لیست امکانات اسپلیت وایز
    final List<FeatureItem> features = [
      FeatureItem('تاریخچه هزینه‌ها', Icons.history, Colors.purple, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseHistoryPage()));
      }),
      FeatureItem('اضافه کردن هزینه', Icons.add_circle, Colors.green, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpensePage()));
      }),
      // در لیست features در SplitWiseScreen
      FeatureItem('تسویه حساب', Icons.payment, Colors.blue, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => SettlementPage()));
      }),
      FeatureItem(
        'محاسبه بدهی‌ها',
        Icons.calculate,
        Colors.orange,
            () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CalculationPage()),
          );
        },
      ),
      FeatureItem(
        'گروه‌های مالی',
        Icons.group,
        Colors.pink,
            () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FinancialGroupPage()),
          );
        },
      ),
      FeatureItem(
        'گزارش مالی',
        Icons.bar_chart,
        Colors.teal,
            () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FinancialReportsPage()),
          );
        },
      ),
      FeatureItem('یادآوری پرداخت', Icons.notifications, Colors.red, () {
        _showComingSoon(context);
      }),
      FeatureItem('تنظیمات', Icons.settings, Colors.grey, () {
        _showComingSoon(context);
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Text(
              'کیف پول',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 28,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 12.0, // کاهش از 16 به 12
            childAspectRatio: 0.7, // افزایش از 0.6 به 0.7
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            return FeatureCard(feature: features[index]);
          },
        )
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('این قابلیت به زودی اضافه خواهد شد'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

class FeatureItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  FeatureItem(this.title, this.icon, this.color, this.onTap);
}

class FeatureCard extends StatelessWidget {
  final FeatureItem feature;

  const FeatureCard({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 150,
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Expanded( // اضافه کردن Expanded برای آیکون
                child: InkWell(
                  onTap: feature.onTap,
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: feature.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Icon(
                      feature.icon,
                      size: 28,
                      color: feature.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                feature.title,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}