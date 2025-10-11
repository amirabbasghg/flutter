import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class home extends StatefulWidget {
  const home({super.key});

  @override
  State<home> createState() => _homeState();
}

class _homeState extends State<home> {
  int count = 0;
  var users = [User(id: 'id', username: 'username') ,User(id: '5', username: 'ali') , User(id: '8',username: 'ggg') ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('hellojj'),animateColor : true , backgroundColor: Colors.green[500], ),
      backgroundColor: Colors.green[300],
      body: Padding(
        padding: const EdgeInsets.all(50.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/1.png'),
            ),
            Divider(
              thickness: 2,
              color: Colors.black,
            ),
            SizedBox(height: 10,),
            Text('project',
              style: TextStyle(
                color: Colors.green[900],
                fontWeight: FontWeight.bold,
                fontSize: 40,
              ),
            ),
            SizedBox(height: 10,),
            Text('level',
              style: TextStyle(
                color: Colors.black,
                fontSize: 40,
              ),
            ),
            SizedBox(height: 10,),
            Text('$count',
              style: TextStyle(
                color: Colors.green[900],
                fontWeight: FontWeight.bold,
                fontSize: 40,
              ),
            ),
            SpinKitCircle(
              color: Colors.green,
            ),
            ToggleSwitch(
              minWidth: 90.0,
              minHeight: 70.0,
              initialLabelIndex: 0,
              cornerRadius: 20.0,
              activeFgColor: Colors.white,
              inactiveBgColor: Colors.grey,
              inactiveFgColor: Colors.white,
              totalSwitches: 3,
              icons: [
                 Iconsax.cake,
                FontAwesomeIcons.twitter,
                FontAwesomeIcons.instagram
              ],
              iconSize: 30.0,
              borderColor: [Color(0xff3b5998), Color(0xff8b9dc3), Color(0xff00aeff), Color(0xff0077f2), Color(0xff962fbf), Color(0xff4f5bd5)],
              dividerColor: Colors.blueGrey,
              activeBgColors: [[Color(0xff3b5998), Color(0xff8b9dc3)], [Color(0xff00aeff), Color(0xff0077f2)], [Color(0xfffeda75), Color(0xfffa7e1e), Color(0xffd62976), Color(0xff962fbf), Color(0xff4f5bd5)]],
              onToggle: (index) {
                print('switched to: $index');
              },
            ),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                  itemBuilder: (context , index){
                  final user = users[index];
                  return Card(child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: Icon(Icons.account_circle),
                      title: Text(user.username!),
                      subtitle: Text(user.id),
                      trailing: InkWell(
                        child: Icon(Icons.delete),
                        onTap: (){
                          setState(() {
                            users.remove(user);
                          });

                        },
                      ),
                    ),
                  ));

                  },

              )
            ),
          ],
        ),
      ),
        floatingActionButton: FloatingActionButton(backgroundColor: Colors.green[100],autofocus : true , tooltip: 'click', onPressed: (){setState(() {
          count+=1;
        });}, mouseCursor: SystemMouseCursors.click, child: const Text('f')),
        bottomNavigationBar : BottomNavigationBar(items: const [BottomNavigationBarItem(icon: Icon(Iconsax.bank) , label: 'ggg' , activeIcon: Icon(Icons.account_circle)) , BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded) , label: 'hth')] , currentIndex: 1,)
    );
  }
}

class User {
  String? username ;
  String id;
  User({ required this.id , this.username});
}
// Container(
// padding: EdgeInsets.all(5),
// margin: EdgeInsets.all(100),
// color: Colors.amberAccent,
// child: Text('data'),
// ),


// Image.asset('assets/1.png'),



// Text(
// 'hello', style: TextStyle(
// fontSize: 50,
// fontWeight: FontWeight.bold,
// letterSpacing: 0,
// color: Colors.green,
// fontFamily: 'indieFlower',
// ),
// ),