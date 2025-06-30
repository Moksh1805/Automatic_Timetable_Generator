import 'package:flutter/material.dart';
import 'package:timetable_generator/Generate_timetable_page.dart';

class homepage extends StatelessWidget {
  const homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: Row(
              //mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.table_chart_outlined , color: Colors.deepPurple, size: 30,),
                SizedBox(width: 10,),
                Text("Automatic TimeTable Generator" , style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22 ,
                ),),
              ],
            ),
          ),
          SizedBox(height: 40,),

          Expanded(
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Generate Your\ntimetable in seconds!", style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),),
                            SizedBox(height: 20,),
                            Text('Simply set up your lecture, add subjects, \nand instantly create a customizable timetable!',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey),
                            ),
                            SizedBox(height: 30,),
                            ElevatedButton(
                                onPressed: (){
                                  Navigator.push(context, MaterialPageRoute(builder: (context)=> GenerateTimetablePage()));
                                },
                                child: Text("Lets Get Started"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(fontSize: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)
                                ),
                              ),
                            ),
                          ],
                        )
                      ),

                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                )
                              ]
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Timetable',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16,),
                                Table(
                                  border: TableBorder.all(color: Colors.grey.shade300),
                                  children: [
                                    TableRow(
                                      decoration : BoxDecoration(
                                        color: Colors.grey[200],
                                      ),
                                      children: ['Mon' ,'Tue', 'Wed', 'Thu', 'Fri' ]
                                          .map((d) => Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Center(child: Text(d),),
                                      )).toList(),
                                    ),
                                    for(int i= 9 ; i<=12 ; i++)
                                      TableRow(
                                        children: List.generate(5, (index) {
                                          bool showMath = (i == 11 && index == 2); // Wed 11 AM
                                          return Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: showMath
                                                ? Container(
                                              decoration: BoxDecoration(
                                                color: Colors.deepPurple.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'Math',
                                                  style: TextStyle(color: Colors.deepPurple),
                                                ),
                                              ),
                                            )
                                                : const SizedBox.shrink(),
                                          );
                                        }),
                                      ),

                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ),

                    ],
                  ),
              ),
          ),
        ],
      ),
    );
  }
}
