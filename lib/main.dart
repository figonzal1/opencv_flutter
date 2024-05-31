// ignore_for_file: avoid_print

import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart';

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

  late ArucoDetector aruco;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    var type = PredefinedDictionaryType.DICT_5X5_50;
    var dictionary = ArucoDictionary.predefined(type);
    var parameters = ArucoDetectorParameters.empty();
    aruco = ArucoDetector.create(dictionary, parameters);
  }

  Future<(Uint8List, Uint8List)> analysis(Uint8List buffer) async {
    final image = imdecode(Uint8List.fromList(buffer), IMREAD_COLOR);

    var rgba = Mat.create();
    cvtColor(image, COLOR_BGR2RGBA, dst: rgba);

    var rgb = Mat.create();
    cvtColor(rgba, COLOR_RGBA2RGB, dst: rgb);

    var grey = Mat.create();
    cvtColor(rgb, COLOR_RGBA2GRAY, dst: grey);

    var (corners, ids, rejected) = aruco.detectMarkers(grey);

    if (corners.isNotEmpty) {
      arucoDrawDetectedMarkers(rgb, corners, ids, Scalar.red);



    }

    print("Corners ${corners}, + IDS $ids");

    return (
      imencode(ImageFormat.png.ext, grey),
      imencode(ImageFormat.png.ext, rgb)
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter OpenCV'),
        ),
        body: Container(
          alignment: Alignment.center,
          child: Column(
            children: [
              const Text("OpenCV Aruco Marker"),
              ElevatedButton(
                onPressed: () async {
                  final data = await DefaultAssetBundle.of(context)
                      .load("images/phone_aruco.jpg");
                  final bytes = data.buffer.asUint8List();
                  // heavy computation
                  final (gray, processed) = await analysis(bytes);

                  setState(() {
                    images = [bytes, gray, processed];
                  });
                },
                child: const Text("Pick Image"),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: images.length,
                        itemBuilder: (ctx, idx) => Card(
                          child: Image.memory(images[idx]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
