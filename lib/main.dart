import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:permission_handler/permission_handler.dart'; 

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'IMU Sensor Data Recorder',
      home: SensorPage(),
    );
  }
}

class SensorPage extends StatefulWidget {
  const SensorPage({super.key});

  @override
  _SensorPageState createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  bool isRecording = false;
  List<List<dynamic>> records = [];
  StreamSubscription? _streamSubscription;
  List<dynamic> currentRecord = [];

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  // void startRecording() {
  //   setState(() {
  //     isRecording = true;
  //     records.add(<String>['Timestamp', 'Accelerometer x', 'Accelerometer y', 'Accelerometer z', 'Gyroscope x', 'Gyroscope y', 'Gyroscope z']);
  //   });
  //   _streamSubscription = SensorsPlatform.instance.accelerometerEventStream().listen((AccelerometerEvent event) {
  //     final now = DateTime.now();
  //     final gyroscope = SensorsPlatform.instance.gyroscopeEventStream();
  //     gyroscope.first.then((GyroscopeEvent gyroEvent) {
  //       setState(() {
  //         currentRecord = [
  //           now.toIso8601String(),
  //           event.x.toStringAsFixed(3),
  //           event.y.toStringAsFixed(3),
  //           event.z.toStringAsFixed(3),
  //           gyroEvent.x.toStringAsFixed(3),
  //           gyroEvent.y.toStringAsFixed(3),
  //           gyroEvent.z.toStringAsFixed(3),
  //         ];
  //       });
  //       if (isRecording) {
  //         records.add(currentRecord);
  //       }
  //     });
  // });
    
  void startRecording() {
  setState(() {
    isRecording = true;
    records.add(<String>[
      'Timestamp',
      'Accelerometer x', 'Accelerometer y', 'Accelerometer z',
      'Gyroscope x', 'Gyroscope y', 'Gyroscope z',
      'Magnetometer x', 'Magnetometer y', 'Magnetometer z',
      'User Accelerometer x', 'User Accelerometer y', 'User Accelerometer z'
    ]);
  });

  // Combine streams to handle all sensor data in one subscription
  _streamSubscription= ZipStream.zip4(
    SensorsPlatform.instance.accelerometerEventStream(),
    SensorsPlatform.instance.gyroscopeEventStream(),
    SensorsPlatform.instance.magnetometerEventStream(),
    SensorsPlatform.instance.userAccelerometerEventStream(),
    (AccelerometerEvent accelerometer, GyroscopeEvent gyroscope, MagnetometerEvent magnetometer, UserAccelerometerEvent userAccel) {
      final now = DateTime.now().toIso8601String();
      return [
        now,
        accelerometer.x.toStringAsFixed(3), accelerometer.y.toStringAsFixed(3), accelerometer.z.toStringAsFixed(3),
        gyroscope.x.toStringAsFixed(3), gyroscope.y.toStringAsFixed(3), gyroscope.z.toStringAsFixed(3),
        magnetometer.x.toStringAsFixed(3), magnetometer.y.toStringAsFixed(3), magnetometer.z.toStringAsFixed(3),
        userAccel.x.toStringAsFixed(3), userAccel.y.toStringAsFixed(3), userAccel.z.toStringAsFixed(3),
      ];
    }
  ).listen((List<dynamic> record) {
    setState(() {
      currentRecord = record;
      if (isRecording) {
        records.add(record);
      }
    });
  });
  }


  Future<void> saveEmptyFile() async {
    final directory = await getApplicationDocumentsDirectory();
    String filePath = '${directory.path}/imu_data_empty.csv';
    File file = File(filePath);
  
    await file.writeAsString('0,0,0,0,0,0,0,0,0,0,0,0,0');  // Writing a single line of zeros
  // print('Empty data saved to $filePath because no sensor data was recorded.');
  }



  Future<void> saveToFile() async {
    var status = await Permission.storage.status; 
    if (!status.isGranted) { 
      // If not we will ask for permission first 
      await Permission.storage.request(); 
    } 
    Directory directory = Directory(""); 
    if (Platform.isAndroid) { 
       // Redirects it to download folder in android 
      directory = Directory("/storage/emulated/0/Download"); 
    } else { 
      directory = await getApplicationDocumentsDirectory(); 
    } 

    // final directory = await getApplicationDocumentsDirectory();
    String filePath = '${directory.path}/imu_data.csv';
    File file = File(filePath);

    String csvData = const ListToCsvConverter().convert(records);
    await file.writeAsString(csvData);
    // print('Data saved to $filePath');
  }

  void stopRecording() async {
    await _streamSubscription?.cancel();
    setState(() {
      isRecording = false;
    });
    if (records.length > 1) {
      saveToFile();
    } 
    else {
      saveEmptyFile();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IMU Sensor Data Recorder'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
        if (currentRecord.isNotEmpty) ...[
          Text('Current Accelerometer: X=${currentRecord[1]}, Y=${currentRecord[2]}, Z=${currentRecord[3]}'),
          Text('Current Gyroscope: X=${currentRecord[4]}, Y=${currentRecord[5]}, Z=${currentRecord[6]}'),
          Text('Current Magnetometer: X=${currentRecord[7]}, Y=${currentRecord[8]}, Z=${currentRecord[9]}'),
          Text('Current User Accelerometer: X=${currentRecord[10]}, Y=${currentRecord[11]}, Z=${currentRecord[12]}'),
        ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isRecording ? null : startRecording,
            child: const Text('Start Recording'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: isRecording ? stopRecording : null,
            child: const Text('Stop Recording'),
          ),
        ],
      ),
    );
  }
}
