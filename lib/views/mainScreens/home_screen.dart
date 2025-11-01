
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ubwinza_riders/global/global_instances.dart';
import 'package:ubwinza_riders/global/global_vars.dart';
import 'package:ubwinza_riders/views/mainScreens/history.dart';
import 'package:ubwinza_riders/views/mainScreens/new_available_order.dart';
import 'package:ubwinza_riders/views/mainScreens/not-yet_delivered.dart';
import 'package:ubwinza_riders/views/mainScreens/parcel_in_progress.dart';
import 'package:ubwinza_riders/views/mainScreens/total_earnings.dart';
import 'package:ubwinza_riders/views/splashScreen/splash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  Card dashboardItem(String title, IconData icondData, int index) {
    return Card(
      elevation: 2,
        margin: const EdgeInsets.all(8),
        child: Container(
          decoration: index == 0 || index ==3 || index == 4 ?
          const BoxDecoration(
           gradient: LinearGradient(colors: [ Color(0xFF1A2B7B),  Color(0xFF1A2B7B)],
             begin: FractionalOffset(0.0, 0.0),
             end: FractionalOffset(1.0, 0.0),
             tileMode: TileMode.clamp
           )
          ):
          const BoxDecoration(
              gradient: LinearGradient(colors: [ Color(0xFF1A2B7B), Colors.black],
                  begin: FractionalOffset(0.0, 0.0),
                  end: FractionalOffset(1.0, 0.0),
                  tileMode: TileMode.clamp
              )
          ),
          child: InkWell(
            onTap: (){

              if(index == 0) {

                Navigator.push(context, MaterialPageRoute(builder: (_) => NewAvailableOrderScreen()));
              }

              if(index == 1) {

               // Navigator.push(context, MaterialPageRoute(builder: (_) => ParcelInProgressScreen()));

              }

              if(index == 2) {

                Navigator.push(context, MaterialPageRoute(builder: (_) => NotYetDelivered()));

              }

              if(index == 3) {

                Navigator.push(context, MaterialPageRoute(builder: (_) => History()));

              }

              if(index == 4) {

                Navigator.push(context, MaterialPageRoute(builder: (_) => TotalEarnings()));

              }

              if(index == 5) {
                
                authViewModel.logout(context);
                //Navigator.push(context, MaterialPageRoute(builder: (_) => MySplashScreen()));

              }

            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              verticalDirection: VerticalDirection.down,
              children: [
                const SizedBox(height: 50.0,),
                Center(
                  child: Icon(
                    icondData,
                    size: 40,
                    color: Colors.white
                  ),
                ),

                const SizedBox(height: 10.0,),

                Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white

                    ),
                  )
                ),

              ],

            ),
          ),
        ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2B7B),
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text("Welcome ${sharedPreferences!.getString("name")}",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          letterSpacing: 2
        ),
        ),
        
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 1,),
        child: GridView.count(
          crossAxisCount: 2,
          children: [

            dashboardItem("New Available orders", Icons.assessment, 0),

            dashboardItem("Parcels in progress", Icons.airport_shuttle, 1),

            dashboardItem("Not yet Delivered", Icons.location_history, 2),

            dashboardItem("History", Icons.done_all, 3),

            dashboardItem("Total Earnings", Icons.monetization_on, 4),

            dashboardItem("Logout", Icons.logout, 5),

          ],
        ),
      ),
    );
  }
}
