// lib/view/groups_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:namer_app/View/Home/GroupPage.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:provider/provider.dart';

import '../../model/Group.dart';
import '../../model/User.dart';
import '../../ViewModel/AppStateVM.dart';

class FinancialGroupPage extends StatefulWidget {
  @override
  _FinancialGroupPage createState() => _FinancialGroupPage();
}

class _FinancialGroupPage extends State<FinancialGroupPage> {
  @override
  Widget build(BuildContext context) {
    final appStateVM = context.watch<AppStateVM>();
    final currentUser = appStateVM.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'لطفاً ابتدا وارد شوید',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // فقط گروه‌هایی که کاربر در آنها عضو است
    final userGroups = appStateVM.groups.where((group) =>
        group.memberIds.contains(currentUser.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '👥 گروه‌های مالی',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.pink[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GroupPage()),
              );
            },
          ),
        ],
      ),
      body: userGroups.isEmpty
          ? _buildEmptyState()
          : _buildGroupsList(appStateVM, userGroups, currentUser),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group, size: 64, color: Colors.pink[300]),
          SizedBox(height: 16),
          Text(
            'هنوز در گروهی عضو نیستید',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'یک گروه جدید ایجاد کنید یا به گروهی بپیوندید',
            style: TextStyle(color: Colors.grey[500]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GroupPage()),
              );
            },
            icon: Icon(Icons.add),
            label: Text('ایجاد گروه جدید'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList(AppStateVM appStateVM, List<Group> groups, User currentUser) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'گروه‌های شما (${groups.length})',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.pink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_getOwnedGroupsCount(groups, currentUser)} گروه مالک',
                  style: TextStyle(
                    color: Colors.pink,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final isOwner = group.createdBy == currentUser.id;
                return _buildGroupCard(appStateVM, group, currentUser, isOwner);
              },
            ),
          ),
        ],
      ),
    );
  }

  int _getOwnedGroupsCount(List<Group> groups, User currentUser) {
    return groups.where((group) => group.createdBy == currentUser.id).length;
  }

  Widget _buildGroupCard(AppStateVM appStateVM, Group group, User currentUser, bool isOwner) {
    final members = group.getMembers(appStateVM.members);
    final totalExpenses = appStateVM.getTotalExpensesForGroup(group);
    final userBalance = appStateVM.getUserBalanceInGroup(currentUser, group);

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          _showGroupDetails(appStateVM, group, currentUser, isOwner);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // هدر گروه با نشانگر مالکیت
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        group.name,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (isOwner) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.pink.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'مالک',
                            style: TextStyle(
                              color: Colors.pink,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              SizedBox(height: 12),

              // اطلاعات پایه گروه
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('${group.memberCount.toString().toPersianDigit()} عضو'),
                  SizedBox(width: 16),
                  Icon(Icons.receipt, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('${group.expenseCount.toString().toPersianDigit()} هزینه'),
                ],
              ),
              SizedBox(height: 8),

              // اطلاعات مالی
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    '${NumberFormat('#,###').format(totalExpenses).toPersianDigit()} تومان',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 16),
                  Icon(
                    userBalance >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: userBalance >= 0 ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${NumberFormat('#,###').format(userBalance.abs()).toPersianDigit()} تومان',
                    style: TextStyle(
                      color: userBalance >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // اعضای گروه
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: members.take(3).map((user) {
                  final isCurrentUser = user.id == currentUser.id;
                  return Chip(
                    label: Text(isCurrentUser ? 'شما' : user.name),
                    backgroundColor: isCurrentUser
                        ? Colors.pink[100]
                        : Colors.grey[200],
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isCurrentUser ? Colors.pink : Colors.grey[800],
                    ),
                  );
                }).toList(),
              ),
              if (members.length > 3) ...[
                SizedBox(height: 8),
                Text(
                  '+ ${members.length - 3} عضو دیگر',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupDetails(AppStateVM appStateVM, Group group, User currentUser, bool isOwner) {
    final members = group.getMembers(appStateVM.members);
    final totalExpenses = appStateVM.getTotalExpensesForGroup(group);
    final userBalance = appStateVM.getUserBalanceInGroup(currentUser, group);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),

            // هدر گروه
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (isOwner)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.pink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'شما مالک هستید',
                      style: TextStyle(
                        color: Colors.pink,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),

            // اطلاعات گروه
            _buildDetailItem('👥 تعداد اعضا', '${group.memberCount} نفر'),
            _buildDetailItem('💰 کل هزینه‌ها', '${totalExpenses.toStringAsFixed(0)} تومان'),
            _buildDetailItem('📝 تعداد هزینه‌ها', '${group.expenseCount} مورد'),
            _buildDetailItem(
              '💼 موجودی شما',
              '${userBalance.toStringAsFixed(0)} تومان',
              color: userBalance >= 0 ? Colors.green : Colors.red,
            ),
            SizedBox(height: 16),

            // دکمه اضافه کردن عضو جدید (فقط برای مالک)
            if (isOwner)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // بستن bottom sheet
                      _showAddMemberDialog(appStateVM, group, currentUser);
                    },
                    icon: Icon(Icons.person_add, size: 18),
                    label: Text('افزودن عضو جدید'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),

            // لیست اعضا با قابلیت حذف برای مالک
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'اعضای گروه:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (isOwner)
                  Text(
                    'برای حذف عضو کلیک کنید',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),

            // لیست اعضا
            Container(
              constraints: BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final user = members[index];
                  final isCurrentUser = user.id == currentUser.id;
                  final canRemove = isOwner && !isCurrentUser;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrentUser
                          ? Colors.pink[100]
                          : Colors.grey[200],
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: isCurrentUser ? Colors.pink : Colors.grey[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      isCurrentUser ? '${user.name} (شما)' : user.name,
                      style: TextStyle(
                        fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: canRemove
                        ? IconButton(
                      icon: Icon(Icons.person_remove, color: Colors.red, size: 20),
                      onPressed: () => _removeMemberFromGroup(context, group, user, appStateVM),
                    )
                        : isCurrentUser
                        ? Text(
                      'شما',
                      style: TextStyle(
                        color: Colors.pink,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                        : null,
                  );
                },
              ),
            ),
            SizedBox(height: 24),

            // دکمه‌های پایین
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('بستن'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String title, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMemberDialog(AppStateVM appStateVM, Group group, User currentUser) async {
    // دریافت لیست دوستان کاربر که در گروه نیستند
    final friendsNotInGroup = currentUser.friendIds
        .where((friendId) => !group.memberIds.contains(friendId))
        .map((friendId) => appStateVM.members.firstWhere((user) => user.id == friendId))
        .toList();

    if (friendsNotInGroup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('هیچ دوستی برای اضافه کردن به گروه وجود ندارد'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_add, color: Colors.pink),
            SizedBox(width: 8),
            Text('افزودن عضو به گروه'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'دوستان شما که در گروه نیستند:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: friendsNotInGroup.length,
                  itemBuilder: (context, index) {
                    final friend = friendsNotInGroup[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.pink[100],
                        child: Text(
                          friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'F',
                          style: TextStyle(
                            color: Colors.pink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(friend.name),
                      subtitle: Text(friend.email),
                      trailing: IconButton(
                        icon: Icon(Icons.add, color: Colors.green),
                        onPressed: () async {
                          await _addMemberToGroup(group, friend, appStateVM);
                          Navigator.pop(context); // بستن دیالوگ
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('لغو'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMemberToGroup(Group group, User newMember, AppStateVM appStateVM) async {
    try {
      // اضافه کردن کاربر به گروه
      if (!group.memberIds.contains(newMember.id)) {
        group.memberIds.add(newMember.id);
        await appStateVM.updateGroup(group);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newMember.name} به گروه اضافه شد'),
            backgroundColor: Colors.green,
          ),
        );

        // رفرش صفحه
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newMember.name} قبلاً در گروه عضو است'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در اضافه کردن عضو'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeMemberFromGroup(BuildContext context, Group group, User user, AppStateVM appStateVM) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف عضو از گروه'),
        content: Text('آیا مطمئن هستید که می‌خواهید ${user.name} را از گروه ${group.name} حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('حذف'),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      try {
        // حذف کاربر از گروه
        group.memberIds.remove(user.id);
        await appStateVM.updateGroup(group);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} از گروه حذف شد'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context); // بستن bottom sheet
        setState(() {}); // رفرش صفحه
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در حذف عضو'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}