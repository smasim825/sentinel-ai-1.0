import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/chat_service.dart';

class LiveLocationMapScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String currentUserName;
  final String otherName;

  const LiveLocationMapScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherName,
  });

  @override
  State<LiveLocationMapScreen> createState() => _LiveLocationMapScreenState();
}

class _LiveLocationMapScreenState extends State<LiveLocationMapScreen> {
  final ChatService _chatService = ChatService();
  final Completer<GoogleMapController> _controller = Completer();
  StreamSubscription<Position>? _positionSubscription;
  
  Map<String, Marker> _markers = {};
  LatLng? _myLocation;
  LatLng? _otherLocation;
  
  String _distanceText = "Calculating...";
  String _myStatus = "Stationary";
  String _otherStatus = "Stationary";
  String _myDirection = "N";
  String _otherDirection = "N";
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _checkInitialSharing();
  }

  void _checkInitialSharing() async {
    // Check if I am already sharing
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('live_locations')
        .doc(widget.currentUserId)
        .get();
    
    if (doc.exists && doc.data()?['isSharing'] == true) {
      _startTracking();
    }
  }

  void _startTracking() async {
    setState(() => _isSharing = true);
    
    // Configure location updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // Update every 2 meters
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
        _myStatus = position.speed > 0.5 ? "Moving" : "Stationary";
        _myDirection = _getCardinalDirection(position.heading);
      });

      _chatService.updateLiveLocation(
        widget.chatId, 
        widget.currentUserId, 
        position.latitude, 
        position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
      );

      _updateCamera();
    });
  }

  void _stopTracking() async {
    await _positionSubscription?.cancel();
    await _chatService.stopLiveLocation(widget.chatId, widget.currentUserId);
    setState(() {
      _isSharing = false;
      _myLocation = null;
    });
  }

  String _getCardinalDirection(double heading) {
    if (heading < 0) heading += 360;
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    int index = ((heading + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  void _processLocationData(List<QueryDocumentSnapshot> docs) {
    final Map<String, Marker> newMarkers = {};
    LatLng? otherLoc;
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String uid = doc.id;
      final double lat = data['lat'] ?? 0.0;
      final double lng = data['lng'] ?? 0.0;
      final double speed = data['speed'] ?? 0.0;
      final double heading = data['heading'] ?? 0.0;
      final bool sharing = data['isSharing'] ?? false;

      if (!sharing) continue;

      final isMe = uid == widget.currentUserId;
      final pos = LatLng(lat, lng);
      
      if (!isMe) {
        otherLoc = pos;
        _otherStatus = speed > 0.5 ? "Moving" : "Stationary";
        _otherDirection = _getCardinalDirection(heading);
      }

      newMarkers[uid] = Marker(
        markerId: MarkerId(uid),
        position: pos,
        rotation: heading,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(isMe ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(title: isMe ? "You" : widget.otherName),
      );
    }

    _markers = newMarkers;
    _otherLocation = otherLoc;
    
    if (_myLocation != null && _otherLocation != null) {
      double dist = Geolocator.distanceBetween(
        _myLocation!.latitude, _myLocation!.longitude,
        _otherLocation!.latitude, _otherLocation!.longitude
      );
      _distanceText = dist > 1000 
          ? "${(dist / 1000).toStringAsFixed(2)} km" 
          : "${dist.toStringAsFixed(0)} m";
    }
    
    // Auto-center camera if it's the first data load
    if (_markers.isNotEmpty && !_controller.isCompleted == false) {
      _updateCamera();
    }
  }

  Future<void> _updateCamera() async {
    if (_myLocation == null && _otherLocation == null) return;
    if (!_controller.isCompleted) return;
    
    final controller = await _controller.future;
    
    if (_myLocation != null && _otherLocation == null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 15));
    } else if (_myLocation != null && _otherLocation != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _myLocation!.latitude < _otherLocation!.latitude ? _myLocation!.latitude : _otherLocation!.latitude,
          _myLocation!.longitude < _otherLocation!.longitude ? _myLocation!.longitude : _otherLocation!.longitude,
        ),
        northeast: LatLng(
          _myLocation!.latitude > _otherLocation!.latitude ? _myLocation!.latitude : _otherLocation!.latitude,
          _myLocation!.longitude > _otherLocation!.longitude ? _myLocation!.longitude : _otherLocation!.longitude,
        ),
      );
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: Text("Mutual Live Location", style: GoogleFonts.outfit(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getLiveLocationsStream(widget.chatId),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _processLocationData(snapshot.data!.docs);
          }

          bool mutualSharing = _isSharing && _otherLocation != null;

          return Stack(
            children: [
              GoogleMap(
                key: const ValueKey("sentinel_map"), // Keep state on rebuild
                initialCameraPosition: const CameraPosition(target: LatLng(23.8103, 90.4125), zoom: 12),
                markers: Set<Marker>.of(_markers.values),
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                style: _darkMapStyle,
                onMapCreated: _onMapCreated,
              ),

              // Telemetry Overlay
              if (mutualSharing)
                Positioned(
                  top: 20, left: 16, right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE91E8C).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _telemetryItem("Distance", _distanceText, Icons.straighten_rounded),
                            _telemetryItem("My Dir", _myDirection, Icons.explore_rounded),
                            _telemetryItem("Their Dir", _otherDirection, Icons.explore_outlined),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statusBadge("You: $_myStatus"),
                            _statusBadge("${widget.otherName}: $_otherStatus"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Sharing Status Warning
              if (!_isSharing || _otherLocation == null)
                Positioned(
                  top: 100, left: 40, right: 40,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.privacy_tip_rounded, color: Colors.orange, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          !_isSharing 
                            ? "Sharing is OFF" 
                            : "Waiting for ${widget.otherName}...",
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          !_isSharing 
                            ? "You must start sharing your location to see others." 
                            : "They must also enable location sharing to see you.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Controls
              Positioned(
                bottom: 30, left: 30, right: 30,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSharing ? Colors.redAccent : const Color(0xFFE91E8C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 10,
                  ),
                  onPressed: _isSharing ? _stopTracking : _startTracking,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isSharing ? Icons.location_off_rounded : Icons.location_on_rounded),
                      const SizedBox(width: 10),
                      Text(
                        _isSharing ? "STOP SHARING" : "SHARE MY LIVE LOCATION",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _telemetryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFE91E8C), size: 18),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _statusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11)),
    );
  }

  static const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1d2c4d"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8ec3b9"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1a3646"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b6878"
      }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#334e87"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#283d6a"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#304a7d"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0e1626"
      }
    ]
  }
]
''';
}
