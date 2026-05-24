import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetName;

  const MapScreen({super.key, this.targetUserId, this.targetName});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  String? _errorMessage;
  final Set<Marker> _markers = {};
  final LocationService _locationService = LocationService();
  
  // Stream for target user
  Stream<DocumentSnapshot>? _targetStream;

  @override
  void initState() {
    super.initState();
    _initLocation();
    if (widget.targetUserId != null) {
      _initTargetTracking();
    }
  }

  void _initTargetTracking() {
    _targetStream = FirebaseFirestore.instance
        .collection('locations')
        .doc(widget.targetUserId)
        .snapshots();
  }

  Future<void> _initLocation() async {
    setState(() => _errorMessage = null);
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
          _markers.add(
            Marker(
              markerId: const MarkerId('me'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: const InfoWindow(title: 'My Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            )
          );
        });
        if (widget.targetUserId == null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              15,
            ),
          );
        }
      } else {
        setState(() => _errorMessage = "Could not get location. Check permissions.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Location Error: $e");
    }
  }

  Future<void> _openSafePlaceSearch(String query) async {
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open Google Maps."))
        );
      }
    }
  }

  void _showHelpOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Find Nearby Safe Places", 
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download_for_offline, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: const Text(
                      "Safety Tip: Open your Google Maps app and download an 'Offline Map' of your area to use this feature without internet.",
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.local_police, color: Color(0xFF7B61FF), size: 32),
              title: Text("Police Stations", style: GoogleFonts.outfit(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _openSafePlaceSearch("police+stations");
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital, color: Color(0xFFE91E8C), size: 32),
              title: Text("Hospitals", style: GoogleFonts.outfit(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _openSafePlaceSearch("hospitals");
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_pharmacy, color: Color(0xFF4CAF50), size: 32),
              title: Text("Pharmacies", style: GoogleFonts.outfit(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _openSafePlaceSearch("pharmacies");
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          title: Text("Safety Map", style: GoogleFonts.outfit())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: GoogleFonts.outfit(color: const Color(0xFFE91E8C))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initLocation,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A2E)), 
                child: Text("Retry", style: GoogleFonts.outfit()),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0D0D1A),
        title: Text(widget.targetName != null ? "Tracking ${widget.targetName}" : "Sentinel Map", 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold))
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C)))
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    zoom: 14,
                  ),
                  style: _darkMapStyle, // Optional: add dark map style if available
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  onMapCreated: (controller) => _mapController = controller,
                ),
                
                // Target Tracking Logic
                if (widget.targetUserId != null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: _targetStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        final lat = data['latitude'] as double;
                        final lng = data['longitude'] as double;
                        final targetPos = LatLng(lat, lng);

                        // Privacy Check: Only show location if SOS is active
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).get(),
                          builder: (context, userSnap) {
                            bool isSosActive = false;
                            if (userSnap.hasData && userSnap.data!.exists) {
                              isSosActive = (userSnap.data!.data() as Map<String, dynamic>)['isSosActive'] ?? false;
                            }

                            if (!isSosActive) {
                              return Positioned(
                                bottom: 120,
                                left: 20,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.privacy_tip_rounded, color: Colors.orange, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "Privacy Protected: ${widget.targetName}'s location is only visible during an active SOS.",
                                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Update marker ONLY if SOS is active
                            _markers.add(
                              Marker(
                                markerId: MarkerId(widget.targetUserId!),
                                position: targetPos,
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                infoWindow: InfoWindow(title: widget.targetName ?? "Monitee"),
                              )
                            );

                            return Positioned(
                              bottom: 120,
                              left: 20,
                              right: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: -5)],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white24,
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          child: const Icon(Icons.emergency_share_rounded, color: Colors.white, size: 28),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "LIVE TRACKING: ${widget.targetName?.toUpperCase()}",
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white, 
                                                  fontWeight: FontWeight.bold, 
                                                  fontSize: 15,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.battery_3_bar_rounded, color: Colors.white70, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Battery: ${data['battery_level'] ?? '??'}%",
                                                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Real-time Active",
                                                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            _mapController?.animateCamera(CameraUpdate.newLatLngZoom(targetPos, 16));
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.center_focus_strong, color: Color(0xFFE91E8C), size: 22),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox();
                    },
                  ),

                // GPS Data Overlays
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A40)),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gps_fixed, color: Color(0xFF4CAF50), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "GPS Active: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}",
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18, color: Colors.white60),
                          onPressed: _initLocation,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: "recenter",
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            onPressed: () {
              if (_currentPosition != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(LatLng(_currentPosition!.latitude, _currentPosition!.longitude))
                );
              }
            },
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: "police",
            onPressed: _showHelpOptions,
            label: Text('Find Help Nearby', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.local_hospital),
            backgroundColor: const Color(0xFFE91E8C),
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  // Helper for dark map theme (standard JSON style for Google Maps)
  static const String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#242f3e"}]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#242f3e"}]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#746855"}]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#d59563"}]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#d59563"}]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [{"color": "#263c3f"}]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#6b9a76"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#38414e"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#212a37"}]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#9ca5b9"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [{"color": "#746855"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#1f2827"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#f3d19c"}]
    },
    {
      "featureType": "transit",
      "elementType": "geometry",
      "stylers": [{"color": "#2f3948"}]
    },
    {
      "featureType": "transit.station",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#d59563"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#17263c"}]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#515c6d"}]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#17263c"}]
    }
  ]
  ''';
}
