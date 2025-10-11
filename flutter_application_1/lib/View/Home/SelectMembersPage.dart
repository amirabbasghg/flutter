// lib/view/select_members_page.dart
import 'package:flutter/material.dart';
import 'package:money2/money2.dart';
import 'package:provider/provider.dart';
import '../../model/User.dart';
import '../../ViewModel/AppStateVM.dart';

class SelectMembersPage extends StatefulWidget {
  @override
  _SelectMembersPageState createState() => _SelectMembersPageState();
}

class _SelectMembersPageState extends State<SelectMembersPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<User> _selectedMembers = [];
  bool selectAll = false;

  @override
  Widget build(BuildContext context) {
    final appStateVM = context.watch<AppStateVM>();
    final currentUser = appStateVM.currentUser;
    final friends = appStateVM.members.where((user) =>
        currentUser!.friendIds.contains(user.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('ایجاد گروه جدید'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedMembers.isNotEmpty)
            IconButton(
              icon: Icon(Icons.check),
              onPressed: () {
                _createGroup(context, appStateVM , currentUser!);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // فیلد نام گروه
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'نام گروه',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),

          // لیست ممبرهای انتخاب شده (مثل تلگرام)
          if (_selectedMembers.isNotEmpty) _buildSelectedMembersList(),

          // عنوان لیست کاربران
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'انتخاب اعضا',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // دکمه Select All در کنار تعداد انتخاب شده
                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      child: Text(
                        _selectedMembers.isEmpty
                            ? 'انتخاب اعضا'
                            : '${_selectedMembers.length} انتخاب شده',
                        key: ValueKey(_selectedMembers.length),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    if (friends.isNotEmpty)
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedMembers.length == friends.length
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            _toggleSelectAll(friends);
                          },
                          child: Row(
                            children: [
                              SizedBox(width: 4),
                              AnimatedSize(
                                duration: Duration(milliseconds: 300),
                                child: Text(
                                  _selectedMembers.length == friends.length
                                      ? 'لغو انتخاب همه'
                                      : 'انتخاب همه',
                                  style: TextStyle(
                                    color: _selectedMembers.length == friends.length
                                        ? Colors.white
                                        : Theme.of(context).primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text('  '),
                              Icon(
                                _selectedMembers.length == friends.length
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                size: 20,
                                color: _selectedMembers.length == friends.length
                                    ? Colors.white
                                    : Theme.of(context).primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // لیست کاربران
          Expanded(
            child: friends.isEmpty
                ? Center(
              child: Text(
                'هیچ عضوی موجود نیست.\nابتدا اعضا را اضافه کنید!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final user = friends[index];
                final isSelected = _selectedMembers.contains(user);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      user.name[0].toUpperCase(),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(user.name),
                  trailing: isSelected
                      ? Icon(Icons.check_circle,
                      color: Theme.of(context).primaryColor)
                      : Icon(Icons.radio_button_unchecked,
                      color: Colors.grey),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedMembers.remove(user);
                      } else {
                        _selectedMembers.add(user);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedMembers.isNotEmpty &&
          _groupNameController.text.isNotEmpty
          ? FloatingActionButton(
        onPressed: () {
          _createGroup(context, appStateVM , currentUser!);
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(Icons.check),
      )
          : null,
    );
  }

  // ویجت برای نمایش ممبرهای انتخاب شده در بالای صفحه
  Widget _buildSelectedMembersList() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height: _selectedMembers.isEmpty ? 0 : 80,
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: _selectedMembers.isEmpty
          ? SizedBox.shrink()
          : ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedMembers.length,
        itemBuilder: (context, index) {
          final user = _selectedMembers[index];
          return _buildSelectedMemberChip(user);
        },
      ),
    );
  }

  // ویجت برای هر ممبر انتخاب شده
  Widget _buildSelectedMemberChip(User user) {
    return AnimatedScale(
      duration: Duration(milliseconds: 200),
      scale: 1.0,
      child: Container(
        margin: EdgeInsets.only(right: 8.0),
        child: Chip(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
          label: Text(
            user.name,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          avatar: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            radius: 12,
            child: Text(
              user.name[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          deleteIcon: Icon(Icons.close, size: 16, color: Colors.purple),
          onDeleted: () {
            setState(() {
              _selectedMembers.remove(user);
            });
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  void _createGroup(BuildContext context, AppStateVM appStateVM , User user) {
    final name = _groupNameController.text.trim();
    if (name.isNotEmpty && _selectedMembers.isNotEmpty) {
      _selectedMembers.add(user);
      appStateVM.addGroup(name, _selectedMembers);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('گروه "$name" با ${_selectedMembers.length} عضو ایجاد شد!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // متد برای انتخاب یا عدم انتخاب همه
  void _toggleSelectAll(List<User> allMembers) {
    setState(() {
      if (_selectedMembers.length == allMembers.length) {
        // اگر همه انتخاب شده‌اند، همه را deselect کن
        _selectedMembers.clear();
      } else {
        // اگر نه، همه را select کن
        _selectedMembers.clear();
        _selectedMembers.addAll(allMembers);
      }
    });
  }
}