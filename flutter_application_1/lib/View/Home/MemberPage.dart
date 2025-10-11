// view/friends_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iranian_banks/iranian_banks.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../model/User.dart';
import '../../ViewModel/AppStateVM.dart';

class FriendsPage extends StatefulWidget {
  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedTab = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appStateVM = context.watch<AppStateVM>();
    final currentUser = appStateVM.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_rounded, size: 64, color: theme.disabledColor),
              SizedBox(height: 16),
              Text(
                'لطفاً ابتدا وارد شوید',
                style: theme.textTheme.titleMedium?.copyWith(color: theme.disabledColor),
              ),
            ],
          ),
        ),
      );
    }

    final filteredMembers = _searchQuery.isEmpty
        ? appStateVM.members
        : appStateVM.members.where((user) =>
    user.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
        user.id != currentUser.id).toList();

    final friends = appStateVM.members.where((user) =>
        currentUser.friendIds.contains(user.id)).toList();

    final nonFriends = filteredMembers.where((user) =>
    user.id != currentUser.id &&
        !currentUser.friendIds.contains(user.id)).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text('دوستان', style: TextStyle(color: Colors.white)),
              backgroundColor: theme.primaryColor,
              floating: true,
              snap: true,
              pinned: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.primaryColor,
                        theme.primaryColorDark,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'جستجوی دوستان...',
                              hintStyle: TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                              prefixIcon: Icon(Iconsax.search_normal, color: Colors.white70),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                icon: Icon(Icons.close, color: Colors.white70),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                                  : null,
                            ),
                            style: TextStyle(color: Colors.white),
                            onChanged: (value) => setState(() => _searchQuery = value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildTab(0, 'دوستان من', friends.length, theme),
                  _buildTab(1, 'پیدا کردن', nonFriends.length, theme),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  // Tab 0: Friends
                  friends.isEmpty
                      ? _buildEmptyState(
                    Iconsax.people,
                    'هنوز دوستی اضافه نکرده‌اید',
                    'با جستجو در تب بعدی دوستان جدید پیدا کنید',
                    theme,
                  )
                      : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: friends.length,
                    itemBuilder: (context, index) => FriendListItem(
                      user: friends[index],
                      isFriend: true,
                      onRemove: () => _removeFriend(context, friends[index]),
                      theme: theme,
                    ),
                  ),

                  // Tab 1: Search
                  _searchQuery.isEmpty
                      ? _buildEmptyState(
                    Iconsax.search_status,
                    'دوستان جدید پیدا کنید',
                    'نام دوست خود را جستجو کنید',
                    theme,
                  )
                      : nonFriends.isEmpty
                      ? _buildEmptyState(
                    Iconsax.search_status,
                    'نتیجه‌ای یافت نشد',
                    'اسم دیگری را امتحان کنید',
                    theme,
                  )
                      : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: nonFriends.length,
                    itemBuilder: (context, index) => FriendListItem(
                      user: nonFriends[index],
                      isFriend: false,
                      onAdd: () => _addFriend(context, nonFriends[index]),
                      theme: theme,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String title, int count, ThemeData theme) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _selectedTab == index ? theme.primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _selectedTab == index ? theme.primaryColor : theme.disabledColor,
                  fontWeight: _selectedTab == index ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _selectedTab == index ? theme.primaryColor.withOpacity(0.1) : theme.disabledColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _selectedTab == index ? theme.primaryColor : theme.disabledColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.primaryColor),
          SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.disabledColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _addFriend(BuildContext context, User friend) async {
    final appStateVM = context.read<AppStateVM>();
    final theme = Theme.of(context);

    try {
      await appStateVM.addFriend(friend.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('درخواست دوستی برای ${friend.name} ارسال شد'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('خطا در ارسال درخواست دوستی'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _removeFriend(BuildContext context, User friend) async {
    final appStateVM = context.read<AppStateVM>();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_remove, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'حذف دوست',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'آیا مطمئن هستید که می‌خواهید ${friend.name} را از دوستان خود حذف کنید؟',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('لغو', style: TextStyle(color: theme.primaryColor)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await appStateVM.removeFriend(friend.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text('${friend.name} از دوستان شما حذف شد'),
                                ],
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text('خطا در حذف دوست'),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('حذف', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FriendListItem extends StatelessWidget {
  final User user;
  final bool isFriend;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final ThemeData theme;

  const FriendListItem({
    required this.user,
    required this.isFriend,
    this.onAdd,
    this.onRemove,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 25, // اندازه دایره
          backgroundColor: Colors.transparent, // پس زمینه شفاف برای گرادینت
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.primaryColor,
                  theme.primaryColorDark,
                ],
              ),
            ),
            child: user.photoURL != null
                ? CircleAvatar(
              backgroundImage: NetworkImage(user.photoURL!),
              backgroundColor: Colors.transparent,
            )
                : Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          user.name,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: user.email != null
            ? Text(
          user.email!,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
        )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFriend) ...[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: (){_show(context , user);},
                  child: Icon(
                    Iconsax.user_tag,
                    color: theme.primaryColor,
                    size: 19,
                  ),
                ),
              ),
              SizedBox(width: 100),
            ],
            Container(
              decoration: BoxDecoration(
                color: isFriend ? Colors.red.withOpacity(0.1) : theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  isFriend ? Iconsax.user_minus : Iconsax.user_add,
                  color: isFriend ? Colors.red : theme.primaryColor,
                  size: 22,
                ),
                onPressed: isFriend ? onRemove : onAdd,
                tooltip: isFriend ? 'حذف از دوستان' : 'اضافه کردن به دوستان',
              ),
            ),
          ].where((child) => child != null).toList(),
        ),
      ),
    );
  }
  void _show(BuildContext context, User user) {
    final appStateVM = context.read<AppStateVM>();
    final currentUser = appStateVM.currentUser;

    // محاسبه بدهی بین کاربر جاری و کاربر انتخاب شده
    double debtAmount = 0.0;
    if (currentUser != null && currentUser.id != user.id) {
      debtAmount = _calculateDebtBetweenUsers(currentUser, user, appStateVM);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("اطلاعات کاربر"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // اطلاعات کاربر
              _buildInfoRow(
                icon: Icons.person,
                label: "نام",
                value: user.name ?? "نامشخص",
              ),

              _buildInfoRow(
                icon: Icons.email,
                label: "ایمیل",
                value: user.email,
              ),

              // بخش بدهی/طلب
              if (currentUser != null && currentUser.id != user.id)
                _buildDebtSection(currentUser, user, debtAmount, context),

              // بخش شماره حساب با بک‌گراند بانکی
              if (user.accountNumber != null && user.accountNumber!.isNotEmpty)
                _buildBankThemedAccountNumber(user.accountNumber!.replaceAll('-', ''), context),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('بستن'),
            ),
          ],
        );
      },
    );
  }

// ویجت برای بخش بدهی/طلب
  Widget _buildDebtSection(User currentUser, User targetUser, double debtAmount, BuildContext context) {
    final bool hasDebt = debtAmount != 0;
    final bool isDebtPositive = debtAmount > 0;
    final Color debtColor = isDebtPositive ? Colors.green : Colors.red;
    final IconData debtIcon = isDebtPositive ? Icons.arrow_downward : Icons.arrow_upward;

    String debtDescription;
    if (debtAmount > 0) {
      debtDescription = '${targetUser.name} به شما بدهکار است';
    } else if (debtAmount < 0) {
      debtDescription = 'شما به ${targetUser.name} بدهکار هستید';
    } else {
      debtDescription = 'هیچ بدهی متقابل وجود ندارد';
    }

    return Container(
      margin: EdgeInsets.only(top: 16, bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasDebt
            ? debtColor.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasDebt
              ? debtColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: hasDebt ? debtColor : Colors.grey,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasDebt ? debtIcon : Icons.account_balance_wallet,
              color: Colors.white,
              size: 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وضعیت مالی',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  debtDescription,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hasDebt ? debtColor : Colors.grey,
                  ),
                ),
                if (hasDebt) ...[
                  SizedBox(height: 4),
                  Text(
                    '${NumberFormat('#,###').format(debtAmount.abs()).toPersianDigit()} تومان',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: debtColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // if (hasDebt)
          //   IconButton(
          //     icon: Icon(
          //       Icons.payment,
          //       color: debtColor,
          //       size: 20,
          //     ),
          //     onPressed: () {
          //       Navigator.pop(context); // بستن دیالوگ فعلی
          //       _showSettlementDialog(context, currentUser, targetUser, debtAmount);
          //     },
          //     tooltip: 'ثبت پرداخت',
          //   ),
        ],
      ),
    );
  }

// محاسبه بدهی بین دو کاربر
  double _calculateDebtBetweenUsers(User user1, User user2, AppStateVM appStateVM) {
    double totalDebt = 0.0;

    // محاسبه از طریق تمام expenseها
    for (final expense in appStateVM.allExpenses) {
      final debtUser1 = expense.getDebtAmountForUser(user1, appStateVM.members);
      final debtUser2 = expense.getDebtAmountForUser(user2, appStateVM.members);

      // بدهی خالص بین دو کاربر
      final netDebt = debtUser1 - debtUser2;

      // اگر expense مربوط به هر دو کاربر باشد
      if (expense.isUserInvolved(user1, appStateVM.members) &&
          expense.isUserInvolved(user2, appStateVM.members)) {
        totalDebt += netDebt;
      }
    }

    return totalDebt;
  }

// دیالوگ برای ثبت پرداخت
//   void _showSettlementDialog(BuildContext context, User currentUser, User targetUser, double debtAmount) {
//     final bool isDebtPositive = debtAmount > 0;
//     final payer = isDebtPositive ? targetUser : currentUser;
//     final receiver = isDebtPositive ? currentUser : targetUser;
//     final amount = debtAmount.abs();
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Row(
//           children: [
//             Icon(Icons.payment, color: Colors.blue),
//             SizedBox(width: 8),
//             Text('ثبت پرداخت'),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'پیشنهاد تسویه حساب:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Container(
//               padding: EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.blue.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.arrow_forward, color: Colors.blue),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       '${payer.name} → ${receiver.name}',
//                       style: TextStyle(fontWeight: FontWeight.w500),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               'مبلغ: ${amount.toStringAsFixed(0)} تومان',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.green,
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('بستن'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _navigateToSettlementPage(context, payer, receiver, amount);
//             },
//             child: Text('ثبت پرداخت'),
//           ),
//         ],
//       ),
//     );
//   }

// هدایت به صفحه تسویه حساب


// ویجت برای بخش شماره حساب با بک‌گراند بانکی (بدون تغییر)
  Widget _buildBankThemedAccountNumber(String accountNumber, BuildContext context) {
    // کد قبلی بدون تغییر
    BankInfoView? bankInfo;
    if (accountNumber.length >= 6) {
      bankInfo = IranianBanks.getBankFromCard(accountNumber);
    }

    return Container(
      margin: EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: bankInfo != null
            ? LinearGradient(
          colors: [bankInfo.primaryColor, bankInfo.darkerColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : LinearGradient(
          colors: [Colors.blue, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          if (bankInfo != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: bankInfo.logoBuilder(height: 30),
            ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "شماره حساب",
                  style: TextStyle(
                    color: bankInfo?.onPrimaryColor ?? Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _formatCardNumber(accountNumber),
                  style: TextStyle(
                    color: bankInfo?.onPrimaryColor ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            icon: Icon(
              Icons.copy, // تغییر از iconsax.copy به Icons.copy
              color: bankInfo?.onPrimaryColor ?? Colors.white,
              size: 20,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: accountNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('شماره حساب کپی شد'))
              );
            },
            tooltip: 'کپی شماره حساب',
          ),
        ],
      ),
    );
  }

// تابع برای فرمت کردن شماره کارت (بدون تغییر)
  String _formatCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 16) return cardNumber;

    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write('-');
      }
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }

// تابع برای ساخت ردیف اطلاعات (بدون تغییر)
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20),
          SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

}