import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_utils/google_maps_utils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart'; // Import the url_launcher package

const apiKey = 'AIzaSyAyWpjQ_9muTPZzR1vAhdwUjLyEmzFcDp0';

Future<double> calculateRoadDistance(
    double lat1, double lon1, double lat2, double lon2) async {
  Map<String, String> requestHeaders = {
    "Access-Control-Allow-Headers": "Access-Control-Allow-Origin, Accept",
    "Access-Control-Allow-Origin": "*"
  };
  final url =
      'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$lat1,$lon1&destinations=$lat2,$lon2&travel_mode=driving&key=$apiKey';
  final response = await http.get(Uri.parse(url), headers: requestHeaders);
  if (response.statusCode == 200) {
    final jsonResponse = convert.jsonDecode(response.body);
    final rows = jsonResponse['rows'];
    final elements = rows[0]['elements'];
    final distance = elements[0]['distance']['value'];
    print(distance);
    return distance / 1000; // Convert meters to kilometers
  } else {
    throw Exception('Error fetching distance: ${response.statusCode}');
  }
}

class BGPage extends StatefulWidget {
  const BGPage({Key? key});

  @override
  State<BGPage> createState() => _BGPageState();
}

class _BGPageState extends State<BGPage> {
  String searchValue = '';
  List<Map<String, dynamic>> searchResults = [];
  Future<List<Map<String, dynamic>>> getAllData() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('Hospital-Data').get();

    List<Map<String, dynamic>> allData = [];
    snapshot.docs.forEach((doc) {
      allData.add(doc.data() as Map<String, dynamic>);
    });

    return allData;
  }

  @override
  void initState() {
    setState(() {
      getAllData().then((allData) {
        searchLocalData(allData, "");
      });
    });
  }

  void searchLocalData(List<Map<String, dynamic>> allData, String searchValue) {
    List<Map<String, dynamic>> searchResults = allData.where((doc) {
      bool matchesEmergencyMedication = doc['Emergency-Medication'] is List &&
          (doc['Emergency-Medication'] as List).any((item) =>
              item.toString().toLowerCase() == searchValue.toLowerCase());
      bool matchesBloodAvailability = doc['Blood-Availability'] is List &&
          (doc['Blood-Availability'] as List).any((item) =>
              item.toString().toLowerCase() == searchValue.toLowerCase());
      bool matchesTestMapKeys = doc['Test-Map'] is Map &&
          (doc['Test-Map'] as Map).keys.any((key) =>
              key.toString().toLowerCase() == searchValue.toLowerCase());
      bool matchesSPKeys = doc['Specialists'] is Map &&
          (doc['Specialists'] as Map).keys.any((key) =>
              key.toString().toLowerCase().contains(searchValue.toLowerCase()));
      bool matchesHname = doc['Name'] is String &&
          doc['Name'].toLowerCase().contains(searchValue.toLowerCase());

      return matchesEmergencyMedication ||
          matchesBloodAvailability ||
          matchesTestMapKeys ||
          matchesSPKeys ||
          matchesHname;
    }).toList();
    double sum = 0;
    int count = 0;
    searchResults.forEach((result) {
      if (result['Test-Map'] is Map) {
        Map<String, dynamic> testMap = result['Test-Map'];
        testMap.values.forEach((value) {
          if (value is num) {
            sum += value;
            count++;
          }
        });
        double avgCost = count > 0 ? sum / count : 0;
        setState(() {
          result['Avg-Cost'] = avgCost.toInt();
        });
      }
    });

    searchResults.forEach((result) async {
      setState(() {
        result['Distance'] = 100;
        searchResults.sort((a, b) => a['Distance'].compareTo(b['Distance']));
      });
    });

    setState(() {
      this.searchResults = searchResults;
    });
    searchResults.forEach((result) async {
      double distance = await calculateRoadDistance(
          result['Co-ordinates'].latitude,
          result['Co-ordinates'].longitude,
          13.16756790891849,
          77.5331164318344);
      setState(() {
        result['Distance'] = distance;
        searchResults.sort((a, b) => a['Distance'].compareTo(b['Distance']));
      });
    });
    setState(() {
      this.searchResults = searchResults;
    });
  }

  Future<void> launchInBrowser(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define some dummy data for the list views

    // Define the search container widget
    Widget searchContainer = Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo image
          InkWell(
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            onTap: () {
              Navigator.pop(context);
            },
            child: Image.asset(
              'assets/images/logo.png',
              height: 100,
              width: 200,
            ),
          ),
          const SizedBox(width: 16),
          // Search field
          SizedBox(
              width: 400,
              height: 50,
              child: Container(
                decoration: BoxDecoration(boxShadow: [
                  BoxShadow(
                      offset: const Offset(12, 26),
                      blurRadius: 50,
                      spreadRadius: 0,
                      color: Colors.grey.withOpacity(.1)),
                ]),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchValue = value;
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF192655),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: "Search for hospitals, doctors, etc.",
                    hintStyle: const TextStyle(color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 20.0),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15.0)),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white, width: 1.0),
                      borderRadius: BorderRadius.all(Radius.circular(15.0)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white, width: 2.0),
                      borderRadius: BorderRadius.all(Radius.circular(15.0)),
                    ),
                  ),
                ),
              )),
          SizedBox(width: 16),
          InkWell(
            onTap: () {
              getAllData().then((allData) {
                searchLocalData(allData, searchValue.toLowerCase());
              });
            },
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                color: Color(0xFF192655),
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Define the filter component widget
    Widget filterComponent = Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              // Distance button
            ],
          ),
        ],
      ),
    );

    // Define the main container widget

    // Return the scaffold widget with the app bar and the body
    return Scaffold(
        body: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(child: searchContainer),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.9,
            width: MediaQuery.of(context).size.width * 0.9,
            child: ListView.builder(
              itemCount: searchResults.length,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    void showDetailsPopup(Map<String, dynamic> data) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  // Open Google Maps with the coordinates
                                  GeoPoint coordinates =
                                      searchResults[index]['Co-ordinates'];
                                  String url =
                                      'https://www.google.com/maps/search/?api=1&query=${coordinates.latitude},${coordinates.longitude}';
                                  launchInBrowser(
                                      url); // Use the launch function from the url_launcher package to open the URL
                                },
                                child: Text('Directions'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('Close'),
                              ),
                            ],
                            content: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.black,
                                            width:
                                                2), // Set border color and width here
                                      ),
                                      child: DataTable(
                                        columns: [
                                          DataColumn(label: Text('')),
                                          DataColumn(label: Text('')),
                                        ],
                                        rows: data.entries.map((entry) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(entry.key)),
                                              DataCell(
                                                Container(
                                                  height: 120,
                                                  child: Text(
                                                    entry.key ==
                                                                'Specialists' ||
                                                            entry.key ==
                                                                "Test-Map"
                                                        ? entry.value.keys
                                                            .map<String>(
                                                                (value) =>
                                                                    '• $value')
                                                            .join('\n')
                                                        : entry.value
                                                            .toString(),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }

                    showDetailsPopup(searchResults[index]);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: InfoCard(
                      title: searchResults[index]['Name'].toString(),
                      body:
                          searchResults[index]['Blood-Availability'].toString(),
                      subInfoText:
                          searchResults[index]['Distance'].toString() + " Km",
                      subInfoText2: searchResults[index]['Avg-Cost'].toString(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String body;

  final String subInfoTitle;
  final String subInfoText;
  final Widget subIcon;
  final String subInfoTitle2;
  final String subInfoText2;
  final Widget subIcon2;
  const InfoCard(
      {required this.title,
      required this.body,
      this.subIcon = const CircleAvatar(
        backgroundColor: Colors.orange,
        radius: 25,
        child: Icon(
          Icons.directions,
          color: Colors.white,
        ),
      ),
      required this.subInfoText,
      this.subInfoTitle = "Directions",
      required this.subInfoText2,
      this.subInfoTitle2 = "Average Test Cost",
      this.subIcon2 = const CircleAvatar(
        backgroundColor: Colors.orange,
        radius: 25,
        child: Icon(
          Icons.monetization_on,
          color: Colors.white,
        ),
      ),
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25.0),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              offset: const Offset(0, 10),
              blurRadius: 0,
              spreadRadius: 0,
            )
          ],
          gradient: const RadialGradient(
            colors: [Color(0xFF192655), Color(0xFF192655)],
            focal: Alignment.topCenter,
            radius: .85,
          )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 60,
                width: MediaQuery.of(context).size.width * 0.8,
                child: Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: body.split(',').map((item) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•',
                        style: TextStyle(
                            fontSize: 16, color: Colors.white.withOpacity(.9))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.trim().replaceAll('[', '').replaceAll(']', ''),
                        style: TextStyle(
                          color: Colors.white.withOpacity(.9),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                width: 400,
                height: 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25.0),
                  color: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      subIcon,
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subInfoTitle),
                          Text(
                            subInfoText,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 20,
              ),
              Container(
                width: 400,
                height: 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25.0),
                  color: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      subIcon2,
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subInfoTitle2),
                          Text(
                            subInfoText2,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
