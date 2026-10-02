import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:namer_app/Services/Api.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final ApiService _api = ApiService.instance;
  bool _loading = true;
  String? _error;

  List<dynamic> _users = [];
  List<dynamic> _groups = [];
  List<dynamic> _expenses = [];

  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.adminBootstrap();
      if (!mounted) return;
      setState(() {
        _users = (data['users'] as List?) ?? [];
        _groups = (data['groups'] as List?) ?? [];
        _expenses = (data['expenses'] as List?) ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'خطا در دریافت اطلاعات مدیریت کل';
        _loading = false;
      });
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف کاربر'),
        content: Text('آیا از حذف کاربر "$userName" مطمئن هستید؟ تمام اطلاعات، حساب کاربری و هویتهای متصل حذف خواهد شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('لغو'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف کاربر', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.adminDeleteUser(userId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کاربر $userName با موفقیت حذف شد'), backgroundColor: Colors.green),
        );
        _loadAdminData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف کاربر'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteGroup(String groupId, String groupName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف گروه'),
        content: Text('آیا از حذف گروه "$groupName" و تمامی هزینه‌های آن مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('لغو'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف گروه', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.adminDeleteGroup(groupId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('گروه $groupName با موفقیت حذف شد'), backgroundColor: Colors.green),
        );
        _loadAdminData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف گروه'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteExpense(String expenseId, String description) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف هزینه'),
        content: Text('آیا از حذف هزینه "$description" مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('لغو'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف هزینه', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.adminDeleteExpense(expenseId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هزینه با موفقیت حذف شد'), backgroundColor: Colors.green),
        );
        _loadAdminData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف هزینه'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('🛡️ پنل مدیریت کل (Super Admin)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAdminData,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red, fontSize: 16)),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAdminData, child: Text('تلاش مجدد')),
          ],
        ),
      )
          : Column(
        children: [
          // Navigation tabs
          Container(
            color: theme.cardColor,
            child: Row(
              children: [
                _buildTab(0, 'کاربران', _users.length, theme),
                _buildTab(1, 'گروه‌ها', _groups.length, theme),
                _buildTab(2, 'هزینه‌ها', _expenses.length, theme),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildUsersList(theme),
                _buildGroupsList(theme),
                _buildExpensesList(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title, int count, ThemeData theme) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.deepPurple : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.deepPurple : theme.disabledColor,
                ),
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.deepPurple.withOpacity(0.1) : theme.disabledColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString().toPersianDigit(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.deepPurple : theme.disabledColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersList(ThemeData theme) {
    if (_users.isEmpty) {
      return Center(child: Text('کاربری وجود ندارد'));
    }
    return ListView.builder(
      padding: EdgeInsets.all(12),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];
        final name = (u['name'] ?? 'کاربر') as String;
        final email = (u['email'] ?? '') as String;
        final id = (u['id'] ?? '') as String;

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple[100],
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
            ),
            title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(email.isNotEmpty ? email : 'بدون ایمیل'),
            trailing: IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () => _deleteUser(id, name),
              tooltip: 'حذف کاربر',
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupsList(ThemeData theme) {
    if (_groups.isEmpty) {
      return Center(child: Text('گروهی وجود ندارد'));
    }
    return ListView.builder(
      padding: EdgeInsets.all(12),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final g = _groups[index];
        final name = (g['name'] ?? 'گروه') as String;
        final id = (g['id'] ?? '') as String;
        final memberCount = ((g['memberIds'] as List?) ?? []).length;

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo[100],
              child: Icon(Icons.group, color: Colors.indigo),
            ),
            title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${memberCount.toString().toPersianDigit()} عضو'),
            trailing: IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () => _deleteGroup(id, name),
              tooltip: 'حذف گروه',
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpensesList(ThemeData theme) {
    if (_expenses.isEmpty) {
      return Center(child: Text('هزینه‌ای وجود ندارد'));
    }
    return ListView.builder(
      padding: EdgeInsets.all(12),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final e = _expenses[index];
        final id = (e['id'] ?? '') as String;
        final desc = (e['description'] ?? 'بدون توضیح') as String;
        final amount = (e['amount'] ?? 0).toDouble();

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[100],
              child: Icon(Icons.attach_money, color: Colors.green),
            ),
            title: Text(desc, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${NumberFormat('#,###').format(amount).toPersianDigit()} تومان'),
            trailing: IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () => _deleteExpense(id, desc),
              tooltip: 'حذف هزینه',
            ),
          ),
        );
      },
    );
  }
}
