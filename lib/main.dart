// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:opencv_dart/opencv_dart.dart';
import 'package:permission_handler/permission_handler.dart';

var logger = Logger();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var images = <Uint8List>[];
  late Image imageWidget;

  VideoCapture? capture;

  final StreamController<Uint8List> _streamController =
      StreamController<Uint8List>();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    checkState();

    imageWidget = Image.memory(Uint8List(0));
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    capture?.dispose();
    _streamController.close();
  }

  Future<void> checkState() async {
    bool result = await Permission.camera.isGranted;

    if (!result) {
      requestPermission();
    } else {
      capture = VideoCapture.fromDevice(0, apiPreference: CAP_ANDROID);

      logger.d("CAPTURE INI ${capture!.isOpened}");
    }
  }

  void processFrame() async {
    while (true) {
      bool ret;
      Mat frame;

      (ret, frame) = capture!.read();

      if (!ret) {
        logger.f("Break while");
        break;
      }

      var rgb = Mat.create();
      cvtColor(frame, COLOR_RGBA2RGB, dst: rgb);
      Uint8List png = imencode(".png", rgb);

      _streamController.add(png);

      // Introduce un retraso para limitar la tasa de frames
      await Future.delayed(
          const Duration(milliseconds: 1000)); // Para aproximar 30 FPS
    }
  }

  void requestPermission() async {
    var permissionStatus = await Permission.camera.request();

    if (permissionStatus == PermissionStatus.granted) {
      logger.i("Camera permission granted");
    } else {
      logger.e("Camera permission denied");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Flutter OpenCV"),
        ),
        body: Container(
          alignment: Alignment.center,
          child: Column(
            children: [
              const Text("OpenCV Aruco Marker"),
              StreamBuilder<Uint8List>(
                stream: _streamController.stream,
                builder:
                    (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
                  if (snapshot.hasData) {
                    logger.e("RECIBIENDO DATA ${snapshot.data}");
                    return Image.memory(snapshot.data!);
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              ),
              MaterialButton(
                color: Theme.of(context).colorScheme.inversePrimary,
                onPressed: () {
                  processFrame();
                },
                child: const Text("Procesar frame"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
