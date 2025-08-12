import 'package:flutter/material.dart';

class HeaderCard extends StatelessWidget {
  const HeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                CircleAvatar(radius: 20),
                SizedBox(width: 10),
                Text(
                  "Name",
                  style: TextStyle(fontSize: 18, fontFamily: 'Circular'),
                ),
              ],
            ),
          ),

          // Right icon button
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Text("0"),
                SizedBox(width: 5),
                const Icon(
                  Icons.local_fire_department_sharp,
                  color: Colors.orange,
                ),
                SizedBox(width: 10),
                Text("FR"),
                SizedBox(width: 5),
                const Icon(Icons.calendar_view_day_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
