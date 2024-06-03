// ignore_for_file: avoid_print

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

    var (corners, ids, _) = aruco.detectMarkers(grey);

    if (corners.isNotEmpty) {
      //VecVecPoint2f to VecVecPoint
      var convertCorners = convertVecVecPoint2fToVecVecPoint(corners);
      var objectsCnt = detectObjects(rgb);

      //Dibujar lineas sobre aruco
      //polylines(rgb, convertCorners, true, Scalar(0, 255, 0, 150),
      //    thickness: 5);

      //VecVecPoint to VecPoint (SIMPLIFIED)
      var simplifiedCorners = convertVecVecPointToVecPoint(convertCorners);

      var aruco_perimeter = arcLength(simplifiedCorners, true);

      //Calcular rectangulo de aruco
      var arucoRect = minAreaRect(simplifiedCorners);

      var pixelCmRatio = aruco_perimeter / 20;

      //Escribir ratio en pantalla
      putText(
          rgb,
          "Pixel/cm: $pixelCmRatio",
          Point((arucoRect.center.x - 100).toInt(),
              (arucoRect.center.y - 100).toInt()),
          2,
          1,
          Scalar.fromRgb(0, 255, 255),
          thickness: 2);

      for (var cnt in objectsCnt) {
        var rect = minAreaRect(cnt);

        var x = rect.center.x;
        var y = rect.center.y;
        var h = rect.boundingRect.height;
        var w = rect.boundingRect.width;

        var objectWidth = w / pixelCmRatio;
        var objectHeight = h / pixelCmRatio;

        var box = boxPoints(rect);
        print("box celular $box");

        Point2f previousPoint = box.first;

        for (Point2f point2f in box) {
          // Dibuja una línea desde el punto anterior hasta el punto actual
          line(
              rgb,
              Point(previousPoint.x.toInt(), previousPoint.y.toInt()),
              Point(point2f.x.toInt(), point2f.y.toInt()),
              Scalar.fromRgb(255, 0, 0),
              thickness: 2);

          // Actualiza el punto anterior
          previousPoint = point2f;
        }

        // Dibuja una línea desde el último punto hasta el primer punto para cerrar la caja
        if (box.isNotEmpty) {
          line(
              rgb,
              Point(previousPoint.x.toInt(), previousPoint.y.toInt()),
              Point(box.first.x.toInt(), box.first.y.toInt()),
              Scalar.fromRgb(255, 0, 0),
              thickness: 2);
        }

        //Draw circle
        circle(rgb, Point(x.toInt(), y.toInt()), 15, Scalar.blue,
            thickness: -1);

        //polylines(rgb, convertVecPoint2fToVecVecPoint(box), true,
        //    Scalar.fromRgb(255, 0, 0));

        putText(
            rgb,
            "Ancho ${double.parse(objectWidth.toStringAsFixed(2))} cm",
            Point((x - 100).toInt(), (y - 20).toInt()),
            FONT_HERSHEY_PLAIN,
            2,
            Scalar.fromRgb(100, 200, 0),
            thickness: 2);

        putText(
            rgb,
            "Alto ${double.parse(objectHeight.toStringAsFixed(2))} cm",
            Point((x - 100).toInt(), (y + 15).toInt()),
            FONT_HERSHEY_PLAIN,
            2,
            Scalar.fromRgb(100, 200, 0),
            thickness: 2);
      }
    }

    print("Corners ${corners}, + IDS $ids");

    return (
      imencode(ImageFormat.png.ext, grey),
      imencode(ImageFormat.png.ext, rgb)
    );
  }

  List<VecPoint> detectObjects(Mat frame) {
    //Image frame to grayscale
    var gray = Mat.create();
    cvtColor(frame, COLOR_BGR2GRAY, dst: gray);

    var mask = Mat.create();
    adaptiveThreshold(
        gray, 255, ADAPTIVE_THRESH_MEAN_C, THRESH_BINARY_INV, 19, 5,
        dst: mask);

    //Find contours
    var (contours, _) = findContours(mask, RETR_EXTERNAL, CHAIN_APPROX_SIMPLE);

    List<VecPoint> objectContours = [];
    for (var cnt in contours) {
      var area = contourArea(cnt);

      print("Area contours: $area");

      if (area > 1000) {
        objectContours.add(cnt);
      }
    }

    print("Objectos detectados: ${objectContours.length}");

    return objectContours;
  }

  ///Convertir VecVecPoint2f a VecVecPoint
  VecVecPoint convertVecVecPoint2fToVecVecPoint(VecVecPoint2f vecVecPoint2f) {
    List<List<Point>> listVecVecPoint = [];

    for (var vecPoint2f in vecVecPoint2f) {
      List<Point> listVecPoint = [];
      for (var point2f in vecPoint2f) {
        // Convierte cada Point2f a un Point
        Point point = Point(point2f.x.toInt(), point2f.y.toInt());
        listVecPoint.add(point);
      }
      listVecVecPoint.add(listVecPoint);
    }

    // Convierte la lista de listas de Point a VecVecPoint
    VecVecPoint vecVecPoint = VecVecPoint.fromList(listVecVecPoint);

    return vecVecPoint;
  }

  VecPoint convertVecVecPointToVecPoint(VecVecPoint vecVecPoint) {
    List<Point> listPoint = [];

    for (var vecPoint in vecVecPoint) {
      for (var point in vecPoint) {
        // Agrega cada Point al listPoint
        listPoint.add(point);
      }
    }

    // Convierte la lista de Point a VecPoint
    VecPoint vecPoint = VecPoint.fromList(listPoint);

    return vecPoint;
  }

  VecVecPoint convertVecPoint2fToVecVecPoint(VecPoint2f vecPoint2f) {
    List<List<Point>> listVecVecPoint = [];

    for (var point2f in vecPoint2f) {
      // Convierte cada Point2f a un Point
      Point point = Point(point2f.x.toInt(), point2f.y.toInt());

      // Agrega cada Point a una lista individual
      List<Point> listVecPoint = [point];

      // Agrega la lista de Point a la lista de listas de Point
      listVecVecPoint.add(listVecPoint);
    }

    // Convierte la lista de listas de Point a VecVecPoint
    VecVecPoint vecVecPoint = VecVecPoint.fromList(listVecVecPoint);

    return vecVecPoint;
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
