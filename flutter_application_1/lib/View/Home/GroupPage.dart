// view/group_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../model/Group.dart';
import '../../ViewModel/AppStateVM.dart';
import 'SelectMembersPage.dart';

class GroupPage extends StatefulWidget {
  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  @override
  Widget build(BuildContext context) {
    final appStateVM = context.watch<AppStateVM>();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        title: Text('گروه‌ها' , style: TextStyle(color: Colors.white , fontSize: 30),),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SelectMembersPage()),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(Icons.add , color: Colors.white,),
      ),
      body: Column(
        children: [
          // تقویم
          // _buildCalendar(),

          // لیست گروه‌ها
          Expanded(
            child: appStateVM.getCurrentUserGroups().isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.peopleGroup, color: Theme.of(context).primaryColor, size: 50,),
                  SizedBox(height: 20,),
                  Text(
                    'هنوز گروهی وجود ندارد.\nاولین گروه خود را ایجاد کنید!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),



                ],
              ),
            )
                : ListView.builder(
              itemCount: appStateVM.getCurrentUserGroups().length,
              itemBuilder: (context, index) {
                final group = appStateVM.getCurrentUserGroups()[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    title: Text(
                      group.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      '${group.memberCount} عضو',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: group.createdBy == (appStateVM.currentUser?.id) ? IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _showDeleteDialog(context, group);
                      },
                    ) : null,
                    onTap: () {
                      // رفتن به صفحه جزئیات گروه
                      // Navigator.push(context, MaterialPageRoute(
                      //   builder: (context) => GroupDetailPage(group: group)
                      // ));
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

  void _showDeleteDialog(BuildContext context, Group group) {
    final appStateVM = context.read<AppStateVM>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('حذف گروه'),
          content: Text('آیا از حذف گروه "${group.name}" مطمئن هستید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('لغو'),
            ),
            TextButton(
              onPressed: () {
                appStateVM.removeGroup(group);
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('گروه "${group.name}" حذف شد'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}