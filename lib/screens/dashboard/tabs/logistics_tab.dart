import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';

class LogisticsTab extends StatefulWidget {
  const LogisticsTab({super.key});

  @override
  State<LogisticsTab> createState() => _LogisticsTabState();
}

class _LogisticsTabState extends State<LogisticsTab> {
  GoogleMapController? _mapController;
  
  // Coordonnées approximatives pour centrer sur la Martinique
  static const CameraPosition _martiniqueCamera = CameraPosition(
    target: LatLng(14.6415, -61.0242),
    zoom: 10.0,
  );

  final String _darkMapStyle = '''
  [
    { "elementType": "geometry", "stylers": [{ "color": "#242f3e" }] },
    { "elementType": "labels.text.stroke", "stylers": [{ "color": "#242f3e" }] },
    { "elementType": "labels.text.fill", "stylers": [{ "color": "#746855" }] },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [{ "color": "#d59563" }]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [{ "color": "#d59563" }]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [{ "color": "#263c3f" }]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [{ "color": "#6b9a76" }]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{ "color": "#38414e" }]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [{ "color": "#212a37" }]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [{ "color": "#9ca5b3" }]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [{ "color": "#746855" }]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [{ "color": "#1f2835" }]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [{ "color": "#f3d19c" }]
    },
    {
      "featureType": "transit",
      "elementType": "geometry",
      "stylers": [{ "color": "#2f3948" }]
    },
    {
      "featureType": "transit.station",
      "elementType": "labels.text.fill",
      "stylers": [{ "color": "#d59563" }]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{ "color": "#17263c" }]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [{ "color": "#515c6d" }]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.stroke",
      "stylers": [{ "color": "#17263c" }]
    }
  ]
  ''';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Logistique',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('status', whereIn: [1, 2])
                .snapshots(),
            builder: (context, snapshot) {
              Set<Marker> markers = {};

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final order = OrderModel.fromFirestore(doc);
                  if (order.customerLat != null && order.customerLng != null) {
                    markers.add(
                      Marker(
                        markerId: MarkerId(order.id),
                        position: LatLng(order.customerLat!, order.customerLng!),
                        infoWindow: InfoWindow(
                          title: order.customerPhone ?? 'Sans numéro',
                          snippet: order.deliveryAddress ?? 'Adresse inconnue',
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          order.status == 2 ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueOrange,
                        ),
                      ),
                    );
                  }
                }
              }

              return GoogleMap(
                initialCameraPosition: _martiniqueCamera,
                markers: markers,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _mapController!.setMapStyle(_darkMapStyle);
                },
                myLocationEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: true,
              );
            },
          ),
        ),
      ],
    );
  }
}
