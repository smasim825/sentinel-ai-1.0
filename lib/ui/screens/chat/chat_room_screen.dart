import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/app_state.dart';
import '../../../models/message_model.dart';
import '../../../services/chat_service.dart';
import 'live_location_map_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String? otherName;

  const ChatRoomScreen({
    super.key, 
    required this.chatId, 
    required this.currentUserId,
    this.otherName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSendingImage = false;
  bool _isSharingLocation = false;
  StreamSubscription<Position>? _locationSubscription;
  bool _isTextEmpty = true;

  @override
  void initState() {
    super.initState();
    _msgController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final empty = _msgController.text.trim().isEmpty;
    if (empty != _isTextEmpty) {
      setState(() {
        _isTextEmpty = empty;
      });
    }
  }

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    _chatService.sendMessage(widget.chatId, widget.currentUserId, _msgController.text);
    _msgController.clear();
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() => _isSendingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await _chatService.uploadChatMedia(widget.chatId, bytes, "jpg");
      if (url != null) {
        debugPrint("Sent Image URL: $url");
        await _chatService.sendMessage(widget.chatId, widget.currentUserId, "", imageUrl: url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload failed. Check Firebase Storage rules or network.")));
      }
    } catch (e) {
      debugPrint("Send Image Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send image: $e")));
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "";
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _msgController.removeListener(_onTextChanged);
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleLiveLocation() async {
    if (_isSharingLocation) {
      await _locationSubscription?.cancel();
      await _chatService.stopLiveLocation(widget.chatId, widget.currentUserId);
      setState(() => _isSharingLocation = false);
    } else {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location services are disabled on this device.")));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permissions are permanently denied. Please enable them in settings.")));
        return;
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        setState(() => _isSharingLocation = true);
        _locationSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
        ).listen((position) {
          _chatService.updateLiveLocation(
            widget.chatId, 
            widget.currentUserId, 
            position.latitude, 
            position.longitude,
            heading: position.heading,
            accuracy: position.accuracy,
            speed: position.speed,
          );
        }, onError: (e) {
          debugPrint("Location Stream Error: $e");
          setState(() => _isSharingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Location error: $e")));
        });
        
        _chatService.sendMessage(widget.chatId, widget.currentUserId, "📍 Started sharing live location");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permission required. If on Web, ensure you are using HTTPS or localhost.")));
      }
    }
  }

  void _showThreadInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1A30) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.security, color: Color(0xFFE91E63)),
              SizedBox(width: 8),
              Text("Sentinel Safety Thread"),
            ],
          ),
          content: const Text(
            "This chat room is secured and monitored. Here, you can coordinate safety check-ins, view live locations, and play back captured audio evidence if an SOS alert is triggered.",
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("DISMISS", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatar(String? name) {
    final displayName = name ?? "Contact";
    final initials = displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : "?",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1A30).withOpacity(0.95) : Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.image_rounded,
                    color: Colors.purple,
                    label: "Send Image",
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: _isSharingLocation ? Icons.location_off_rounded : Icons.location_on_rounded,
                    color: _isSharingLocation ? Colors.red : Colors.green,
                    label: _isSharingLocation ? "Stop Location" : "Share Location",
                    onTap: () {
                      Navigator.pop(context);
                      _toggleLiveLocation();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(MessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1A30).withOpacity(0.95) : Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: isDark ? Colors.white70 : Colors.black54),
                title: const Text("Copy Text"),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Copied to clipboard"), duration: Duration(seconds: 1)),
                  );
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text("Delete Message", style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _chatService.deleteMessage(widget.chatId, msg.id);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF151224).withOpacity(0.85) : Theme.of(context).primaryColor.withOpacity(0.95),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAvatar(widget.otherName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherName ?? "Contact",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    children: [
                      PulsingDot(color: Colors.greenAccent),
                      SizedBox(width: 6),
                      Text(
                        "Active Safety Thread",
                        style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showThreadInfoDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [Color(0xFF0C091A), Color(0xFF1E1736)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFF3EEFA), Color(0xFFE5DDF5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
            ),
          ),
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFFE91E63).withOpacity(0.08)
                    : const Color(0xFFE91E63).withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF9C27B0).withOpacity(0.08)
                    : const Color(0xFF9C27B0).withOpacity(0.04),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getMonitoringStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final monitors = snapshot.data!.docs
                          .where((doc) => doc.id != widget.currentUserId)
                          .map((doc) => (doc.data() as Map<String, dynamic>)['name'] ?? "Someone")
                          .toList();
                      
                      if (monitors.isNotEmpty) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red.shade800.withOpacity(0.9), Colors.red.shade600.withOpacity(0.9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.visibility, color: Colors.white, size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "LIVE SECURITY MONITORING",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${monitors.join(', ')} is watching your location",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PulsingDot(color: Colors.redAccent),
                                    SizedBox(width: 6),
                                    Text(
                                      "LIVE",
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getLiveLocationsStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.indigo.shade900.withOpacity(0.35) : Colors.indigo.shade50.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.indigoAccent.withOpacity(0.2) : Colors.indigo.shade200.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.indigoAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Live location sharing is active",
                                style: TextStyle(
                                  color: isDark ? Colors.indigo.shade100 : Colors.indigo.shade900, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.map, size: 16),
                              label: const Text("VIEW MAP"),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.indigoAccent,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => LiveLocationMapScreen(
                                    chatId: widget.chatId,
                                    currentUserId: widget.currentUserId,
                                    currentUserName: context.read<AppState>().currentUser?.name ?? "User",
                                    otherName: widget.otherName ?? "User",
                                  )
                                ));
                              },
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                Expanded(
                  child: StreamBuilder<List<MessageModel>>(
                    stream: _chatService.getChatStream(widget.chatId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_off, size: 48, color: Colors.red),
                                const SizedBox(height: 16),
                                const Text("Cloud Connection Issue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(
                                  "Error: ${snapshot.error}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final messages = snapshot.data!;
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.senderId == widget.currentUserId;
                          final isSOS = msg.text.contains("🚨 SOS ALERT");

                          if (isSOS) {
                            return _buildSosAlertCard(msg);
                          }
                          return _buildMessageBubble(msg, isMe);
                        },
                      );
                    },
                  ),
                ),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLocationMsg = msg.text.contains("📍") && (msg.text.contains("sharing live location") || msg.text.contains("Live Location Shared"));
    final isAudioEvidenceMsg = msg.text.contains("🔴 SOS TRIGGERED — Audio Evidence:");

    Color? bubbleColor;
    Gradient? bubbleGradient;

    if (isMe) {
      if (isLocationMsg) {
        bubbleGradient = const LinearGradient(
          colors: [Color(0xFF3F51B5), Color(0xFF2196F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else if (isAudioEvidenceMsg) {
        bubbleGradient = LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else {
        bubbleGradient = const LinearGradient(
          colors: [
            Color(0xFFFF4081),
            Color(0xFFE91E63),
            Color(0xFF9C27B0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      }
    } else {
      if (isAudioEvidenceMsg) {
        bubbleGradient = LinearGradient(
          colors: [Colors.red.shade900.withOpacity(0.85), Colors.red.shade700.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else {
        bubbleColor = isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.9);
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(msg, isMe),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: CustomPaint(
              painter: ChatBubblePainter(
                isMe: isMe,
                color: bubbleColor ?? Colors.transparent,
                gradient: bubbleGradient,
              ),
              child: Container(
                padding: isMe
                    ? const EdgeInsets.fromLTRB(14, 10, 22, 10)
                    : const EdgeInsets.fromLTRB(22, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () async {
                          if (msg.imageUrl != null) {
                            await launchUrl(Uri.parse(msg.imageUrl!), mode: LaunchMode.externalApplication);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            msg.imageUrl!,
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 220,
                                width: 220,
                                color: isDark ? Colors.white12 : Colors.grey.shade200,
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 220,
                                height: 110,
                                color: isDark ? Colors.white12 : Colors.grey.shade300,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.broken_image, color: Colors.grey),
                                    const Text("Image Error (CORS?)", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text("TAP TO OPEN MANUALLY", style: TextStyle(fontSize: 8, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (isLocationMsg)
                      Column(
                        children: [
                          const Icon(Icons.map, color: Colors.white, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            msg.text,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => LiveLocationMapScreen(
                                  chatId: widget.chatId,
                                  currentUserId: widget.currentUserId,
                                  currentUserName: context.read<AppState>().currentUser?.name ?? "User",
                                  otherName: widget.otherName ?? "User",
                                )
                              ));
                            },
                            icon: const Icon(Icons.pin_drop),
                            label: const Text("View Live Location"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.indigo,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      )
                    else if (isAudioEvidenceMsg)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final lines = msg.text.split('\n');
                                if (lines.length > 1) {
                                   final url = Uri.parse(lines.last.trim());
                                   await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.play_arrow_rounded, color: Colors.red.shade700, size: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Audio Evidence",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: List.generate(16, (index) {
                                      final height = (index % 3 + 1) * 3.0 + (index % 2) * 5.0;
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                        width: 2.5,
                                        height: height,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(index < 8 ? 1.0 : 0.4),
                                          borderRadius: BorderRadius.circular(1.5),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (msg.text.isNotEmpty)
                      Text(
                        msg.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : (isDark ? Colors.white.withOpacity(0.95) : Colors.black87),
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(msg.timestamp),
                            style: TextStyle(
                              color: isMe ? Colors.white70 : (isDark ? Colors.white38 : Colors.black45),
                              fontSize: 9,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.done_all_rounded,
                              size: 12,
                              color: Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSosAlertCard(MessageModel msg) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade900.withOpacity(0.15),
            Colors.red.shade700.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PulsingDot(color: Colors.red),
              const SizedBox(width: 10),
              Text(
                "EMERGENCY ALERT", 
                style: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            msg.text, 
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.9) : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "Triggered at ${_formatTime(msg.timestamp)}",
              style: TextStyle(color: Colors.red.shade400, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                if (_isSendingImage)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueGrey),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: Colors.blueGrey, size: 28),
                    onPressed: _showAttachmentSheet,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      controller: _msgController,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        hintText: "Safety check or update...",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: _isTextEmpty
                      ? IconButton(
                          key: const ValueKey("loc_quick"),
                          icon: Icon(
                            _isSharingLocation ? Icons.location_disabled : Icons.location_on_rounded, 
                            color: _isSharingLocation ? Colors.redAccent : Colors.blueGrey,
                            size: 24,
                          ),
                          onPressed: _toggleLiveLocation,
                        )
                      : Container(
                          key: const ValueKey("send_action"),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF4081), Color(0xFFE91E63)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                            onPressed: _sendMessage,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PulsingDot extends StatefulWidget {
  final Color color;
  const PulsingDot({super.key, required this.color});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(_animation.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5),
                blurRadius: 4 * _animation.value,
                spreadRadius: 2 * _animation.value,
              )
            ],
          ),
        );
      },
    );
  }
}

class ChatBubblePainter extends CustomPainter {
  final bool isMe;
  final Color color;
  final Gradient? gradient;

  ChatBubblePainter({
    required this.isMe,
    required this.color,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double r = 16.0;
    final double w = size.width;
    final double h = size.height;
    final path = Path();

    if (isMe) {
      path.moveTo(r, 0);
      path.lineTo(w - r - 8, 0);
      path.quadraticBezierTo(w - 8, 0, w - 8, r);
      path.lineTo(w - 8, h - r - 6);
      path.quadraticBezierTo(w - 8, h - 8, w, h);
      path.quadraticBezierTo(w - 10, h - 2, w - 18, h - 2);
      path.lineTo(r, h);
      path.quadraticBezierTo(0, h, 0, h - r);
      path.lineTo(0, r);
      path.quadraticBezierTo(0, 0, r, 0);
    } else {
      path.moveTo(r + 8, 0);
      path.lineTo(w - r, 0);
      path.quadraticBezierTo(w, 0, w, r);
      path.lineTo(w, h - r);
      path.quadraticBezierTo(w, h, w - r, h);
      path.lineTo(18, h - 2);
      path.quadraticBezierTo(10, h - 2, 0, h);
      path.quadraticBezierTo(8, h - 8, 8, h - r - 6);
      path.lineTo(8, r);
      path.quadraticBezierTo(8, 0, r + 8, 0);
    }
    path.close();

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    final paint = Paint()..style = PaintingStyle.fill;
    if (gradient != null) {
      paint.shader = gradient!.createShader(Rect.fromLTWH(0, 0, w, h));
    } else {
      paint.color = color;
    }
    canvas.drawPath(path, paint);

    if (!isMe) {
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity(0.15);
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ChatBubblePainter oldDelegate) =>
      oldDelegate.isMe != isMe ||
      oldDelegate.color != color ||
      oldDelegate.gradient != gradient;
}
