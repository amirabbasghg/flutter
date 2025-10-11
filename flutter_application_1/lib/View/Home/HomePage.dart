// view/home_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:namer_app/Services/GoogleSignInService.dart';
import 'package:namer_app/View/Home/GroupPage.dart';
import 'package:namer_app/View/Home/ProfilePage.dart';
import 'package:namer_app/ViewModel/AppStateVM.dart';
import 'package:provider/provider.dart';

import '../../ViewModel/HomeVM.dart';

import 'MemberPage.dart';
import 'ServicesScreen.dart';


class HomePage extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
        final homeVM = context.watch<HomeVM>();
        final appStateVM = context.watch<AppStateVM>();

        Widget page;
        switch (homeVM.selectedIndex) {
            // case 0:
            //     page = GeneratorPage();
            //     break;
            // case 1:
            //     page = FavoritesPage();
            //     break;
            case 0:
                page = FriendsPage();
                break;
            case 1:
                page = GroupPage();
                break;
            case 2:
                page = ServicesScreen();
                break;
            default:
                throw UnimplementedError('no widget for ${homeVM.selectedIndex}');
        }

        void _showMenuPanel() {
            showModalBottomSheet(
                context: context,
                builder: (context) {
                    return Container(
                        padding: EdgeInsets.all(20), // مقدار padding را کاهش دادم
                        child: Column(
                          children: [
                            Card(
                                color: Theme.of(context).primaryColor,
                                child: ListTile(
                                    leading: CircleAvatar(
                                        // تصحیح شرط برای نمایش تصویر پروفایل
                                        backgroundImage: appStateVM.currentUser?.photoURL != null
                                            ? NetworkImage(appStateVM.currentUser!.photoURL!)
                                            : null,
                                        child: appStateVM.currentUser?.photoURL == null
                                            ? Icon(Icons.person)
                                            : null,
                                    ),
                                    title: Text(appStateVM.currentUser?.name ?? 'کاربر ناشناس',
                                    style: TextStyle(color: Colors.white),),
                                    subtitle: Text(appStateVM.currentUser?.email ?? '', style: TextStyle(color: Colors.white),),
                                    // اضافه کردن trailing برای منو
                                ),
                            ),
                              SizedBox(height: 10,),
                              Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: InkWell(
                                    child: ListTile(
                                        leading: Icon(Icons.person_outlined),
                                        trailing: Icon(Icons.keyboard_arrow_left),
                                        title: Text('پروفایل کاربری'),
                                    ),
                                      onTap: (){
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage()));
                                      },
                                  )
                              ),
                              SizedBox(height: 10,),
                              Container(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                      onPressed: () async {
                                          await GoogleSignInService.signOut();
                                          Navigator.pop(context);
                                      },
                                      icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.primary),
                                      label: Text(
                                          'خروج از حساب کاربری',
                                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 0,
                                      ),
                                  ),
                              ),
                          ],
                        ),
                    );
                },
            );
        }
        return Scaffold(
            body: Stack(
                children: [
                    page, // محتوای اصلی

                    // دکمه منو در گوشه بالا چپ
                    Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 8,
                        child: Row(
                          children: [
                            IconButton(
                                onPressed: appStateVM.refreshCurrentUser,
                                icon: Icon(Icons.refresh, color: Colors.white),
                                // style: IconButton.styleFrom(
                                //     backgroundColor: Colors.white,
                                //     padding: EdgeInsets.all(8),
                                // ),
                            ),
                              SizedBox(width: 10,),
                              IconButton(
                                  onPressed: _showMenuPanel,
                                  icon: Icon(Icons.menu, color: Colors.white),
                                  // style: IconButton.styleFrom(
                                  //     backgroundColor: Colors.white,
                                  //     padding: EdgeInsets.all(8),
                                  // ),
                              ),
                          ],
                        ),
                    ),
                ],
            ),
            bottomNavigationBar: BottomNavigationBar(
                items: const [
                    // BottomNavigationBarItem(
                    //     icon: Icon(Icons.home),
                    //     label: 'Home',
                    // ),
                    // BottomNavigationBarItem(
                    //     icon: Icon(Icons.favorite),
                    //     label: 'Favorites',
                    // ),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.account_circle_rounded),
                        label: 'members',
                    ),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.group),
                        label: 'groups',
                    ),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.attach_money),
                        label: 'expense',
                    ),
                ],
                currentIndex: homeVM.selectedIndex,
                onTap: (index) {
                    homeVM.setSelectedIndex(index);
                },
                selectedItemColor: Theme.of(context).primaryColor,
                unselectedItemColor: Theme.of(context).disabledColor
            ),
        );
    }

}