import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Theme/AppTheme.dart';
import '../../ViewModel/AppStateVM.dart';
import '../../ViewModel/ThemeVM.dart';
import 'AddExpensePage.dart';
import 'CalculationPage.dart';
import 'FinancialGroupPage.dart';
import 'FinancialReportsPage.dart';
import 'SettlementPage.dart';
import 'expense_history_page.dart';

/// صفحه‌ی «هزینه‌ها».
///
/// قبلاً هر هشت قابلیت در یک شبکه‌ی ۴ستونه با آیکون و متن ۹پیکسلیِ یکسان بودند
/// — یعنی «ثبت هزینه» که هر روز استفاده می‌شود هم‌اندازه‌ی «تنظیمات» بود که
/// اصلاً ساخته نشده. حالا سه لایه دارد:
///
///   ۱. کارت‌های اصلی، بزرگ  → کارهای روزمره
///   ۲. کارت‌های میانی        → کارهایی که گاهی لازم می‌شوند
///   ۳. نوار پایین، کوچک     → قابلیت‌های هنوز ساخته‌نشده
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppStateVM>();

    final primary = <_Feature>[
      _Feature(
        'ثبت هزینه',
        'خرج تازه را بین اعضا تقسیم کن',
        Icons.add_card_rounded,
        AppTheme.positive,
        () => _open(context, AddExpensePage()),
      ),
      _Feature(
        'تسویه حساب',
        'ببین با هر کس چقدر حساب داری',
        Icons.handshake_rounded,
        AppTheme.info,
        () => _open(context, const SettlementPage()),
      ),
      _Feature(
        'تاریخچه هزینه‌ها',
        'همه‌ی خرج‌های ثبت‌شده',
        Icons.receipt_long_rounded,
        const Color(0xff8b5cf6),
        () => _open(context, ExpenseHistoryPage()),
      ),
      _Feature(
        'گروه‌های مالی',
        'ساخت و مدیریت گروه‌ها',
        Icons.groups_rounded,
        const Color(0xffec4899),
        () => _open(context, FinancialGroupPage()),
      ),
    ];

    final secondary = <_Feature>[
      _Feature('محاسبه بدهی', '', Icons.calculate_rounded, AppTheme.warning,
          () => _open(context, CalculationPage())),
      _Feature('گزارش مالی', '', Icons.insert_chart_rounded,
          const Color(0xff0d9488), () => _open(context, FinancialReportsPage())),
    ];

    const comingSoon = <({String title, IconData icon})>[
      (title: 'یادآوری پرداخت', icon: Icons.notifications_active_outlined),
      (title: 'خروجی اکسل', icon: Icons.table_chart_outlined),
      (title: 'تنظیمات', icon: Icons.settings_outlined),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(appState: appState)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle('کارهای اصلی', theme),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.02,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _PrimaryCard(feature: primary[i]),
                childCount: primary.length,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle('ابزارهای دیگر', theme),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  for (final f in secondary) ...[
                    Expanded(child: _SecondaryCard(feature: f)),
                    if (f != secondary.last) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
            sliver: SliverToBoxAdapter(
              child: _ComingSoonBar(items: comingSoon),
            ),
          ),
        ],
      ),
    );
  }

  static void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _Feature {
  const _Feature(this.title, this.subtitle, this.icon, this.color, this.onTap);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// سربرگ با خلاصه‌ی وضعیت کاربر و کلید تغییر تم.
class _Header extends StatelessWidget {
  const _Header({required this.appState});
  final AppStateVM appState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = appState.currentUser;
    final groupCount = appState.getCurrentUserGroups().length;
    final expenseCount = appState.allExpenses.length;
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      // جا برای دکمه‌های شناور منو/تازه‌سازی که HomePage روی صفحه می‌گذارد
      padding: EdgeInsets.fromLTRB(20, topInset + 56, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white24,
            backgroundImage: (user?.photoURL?.isNotEmpty ?? false)
                ? NetworkImage(user!.photoURL!)
                : null,
            child: (user?.photoURL?.isNotEmpty ?? false)
                ? null
                : Text(
                    user?.initial ?? '؟',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سلام ${user?.name ?? ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$groupCount گروه · $expenseCount هزینه',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const _ThemeToggleButton(),
        ],
      ),
    );
  }
}

/// کلید سریع روشن/تیره. انتخاب کاربر در Hive می‌ماند.
class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final themeVM = context.watch<ThemeVM>();
    return IconButton(
      tooltip: 'تم: ${themeVM.label}',
      onPressed: () => themeVM.toggle(context),
      icon: Icon(themeVM.icon, color: Colors.white),
      style: IconButton.styleFrom(backgroundColor: Colors.white24),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.theme);
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

/// کارت بزرگ: آیکون درشت، عنوان و یک خط توضیح.
class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(feature.icon, size: 32, color: feature.color),
              ),
              const Spacer(),
              Text(
                feature.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                feature.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
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

/// کارت میانی: آیکون متوسط و فقط عنوان.
class _SecondaryCard extends StatelessWidget {
  const _SecondaryCard({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(feature.icon, size: 22, color: feature.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  feature.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// نوار پایین: قابلیت‌هایی که هنوز ساخته نشده‌اند — کوچک، کم‌رنگ و غیرفعال،
/// تا جای کارهای واقعی را نگیرند ولی معلوم باشد در راه‌اند.
class _ComingSoonBar extends StatelessWidget {
  const _ComingSoonBar({required this.items});
  final List<({String title, IconData icon})> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: theme.brightness == Brightness.dark ? 0.4 : 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 10),
            child: Text(
              'به‌زودی',
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
            ),
          ),
          Row(
            children: [
              for (final item in items)
                Expanded(
                  child: Opacity(
                    opacity: 0.55,
                    child: Column(
                      children: [
                        Icon(item.icon, size: 20, color: muted),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: muted, fontSize: 10),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
