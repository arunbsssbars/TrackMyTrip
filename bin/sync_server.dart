import 'dart:convert';
import 'dart:io';

final Map<String, Map<String, dynamic>> _rooms = {};
final Map<String, Set<WebSocket>> _tripWebSockets = {};

final List<Map<String, dynamic>> _mockUsers = [
  {
    'id': 'usr_sarah_101',
    'username': 'sarah_travels',
    'displayName': 'Sarah Jenkins',
    'email': 'sarah.j@example.com',
    'colorHex': '0xFFEC4899',
    'bio': 'Mountain hiker, road trip enthusiast & amateur photographer 🏔️',
    'latitude': 37.7749,
    'longitude': -122.4194,
  },
  {
    'id': 'usr_mike_102',
    'username': 'mike_trekker',
    'displayName': 'Mike Chen',
    'email': 'mike.chen@example.com',
    'colorHex': '0xFF3B82F6',
    'bio': 'Always seeking the next scenic route and best local coffee ☕',
    'latitude': 37.7849,
    'longitude': -122.4094,
  },
  {
    'id': 'usr_elena_103',
    'username': 'elena_hikes',
    'displayName': 'Elena Rostova',
    'email': 'elena.r@example.com',
    'colorHex': '0xFF10B981',
    'bio': 'Campfire storyteller, navigator, foodie ⛺',
    'latitude': 37.7649,
    'longitude': -122.4294,
  },
  {
    'id': 'usr_alex_104',
    'username': 'alex_explorer',
    'displayName': 'Alex Morgan',
    'email': 'alex.m@example.com',
    'colorHex': '0xFFF59E0B',
    'bio': 'National Parks explorer & drone videographer 🚁',
    'latitude': 37.7949,
    'longitude': -122.4394,
  },
  {
    'id': 'usr_priya_105',
    'username': 'priya_wanderer',
    'displayName': 'Priya Sharma',
    'email': 'priya.s@example.com',
    'colorHex': '0xFF8B5CF6',
    'bio': 'Weekend road-tripper & budget master 🚗💨',
    'latitude': 37.7549,
    'longitude': -122.3994,
  },
];

void main() async {
  const port = 8086;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('TripTracker AWS-Mock Sync Server running on port $port');

  await for (HttpRequest request in server) {
    _handleRequest(request);
  }
}

void _handleRequest(HttpRequest request) async {
  final response = request.response;

  // Add CORS headers
  response.headers.add('Access-Control-Allow-Origin', '*');
  response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Origin, Accept');

  if (request.method == 'OPTIONS') {
    response.statusCode = HttpStatus.ok;
    await response.close();
    return;
  }

  final pathSegments = request.uri.pathSegments;

  // 1. WebSocket Live Stream: /ws/trips/<trip_id>
  if (pathSegments.length >= 3 && pathSegments[0] == 'ws' && pathSegments[1] == 'trips') {
    final tripId = pathSegments[2];
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      _tripWebSockets.putIfAbsent(tripId, () => <WebSocket>{}).add(socket);
      stdout.writeln('WebSocket client connected to trip: $tripId');

      socket.listen(
        (data) {
          // Broadcast message to all other companions in this trip room (AppSync Pub/Sub)
          final subscribers = _tripWebSockets[tripId];
          if (subscribers != null) {
            for (final client in subscribers) {
              if (client != socket && client.readyState == WebSocket.open) {
                client.add(data);
              }
            }
          }
        },
        onDone: () {
          _tripWebSockets[tripId]?.remove(socket);
          stdout.writeln('WebSocket client disconnected from trip: $tripId');
        },
        onError: (err) {
          _tripWebSockets[tripId]?.remove(socket);
        },
      );
      return;
    }
  }

  // 2. User Directory Search: /api/users/search?q=<query>
  if (pathSegments.length >= 3 && pathSegments[0] == 'api' && pathSegments[1] == 'users' && pathSegments[2] == 'search') {
    final query = (request.uri.queryParameters['q'] ?? '').trim().toLowerCase().replaceAll('@', '');
    final matches = _mockUsers.where((u) {
      if (query.isEmpty) return true;
      final un = (u['username'] as String).toLowerCase();
      final name = (u['displayName'] as String).toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      return un.contains(query) || name.contains(query) || email.contains(query);
    }).toList();

    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(matches));
    await response.close();
    return;
  }

  // 3. Room State Sync: /api/rooms/<room_code>
  if (pathSegments.length >= 3 && pathSegments[0] == 'api' && pathSegments[1] == 'rooms') {
    final code = pathSegments[2].toUpperCase().trim();

    if (request.method == 'GET') {
      if (_rooms.containsKey(code)) {
        response.headers.contentType = ContentType.json;
        response.statusCode = HttpStatus.ok;
        response.write(jsonEncode(_rooms[code]));
      } else {
        response.statusCode = HttpStatus.notFound;
        response.write(jsonEncode({'error': 'Room not found'}));
      }
      await response.close();
      return;
    }

    if (request.method == 'POST' || request.method == 'PUT') {
      try {
        final bodyStr = await utf8.decoder.bind(request).join();
        final bodyJson = jsonDecode(bodyStr) as Map<String, dynamic>;
        _rooms[code] = bodyJson;

        response.headers.contentType = ContentType.json;
        response.statusCode = HttpStatus.ok;
        response.write(jsonEncode({'success': true, 'code': code}));
      } catch (e) {
        response.statusCode = HttpStatus.badRequest;
        response.write(jsonEncode({'error': e.toString()}));
      }
      await response.close();
      return;
    }
  }

  // 4. Health check
  if (request.uri.path == '/' || request.uri.path == '/health' || request.uri.path == '/api/health') {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({
      'status': 'ok',
      'service': 'TripTracker AWS Mock Sync Server',
      'active_rooms': _rooms.length,
      'active_ws_trips': _tripWebSockets.length,
    }));
    await response.close();
    return;
  }

  response.statusCode = HttpStatus.notFound;
  response.write(jsonEncode({'error': 'Not found'}));
  await response.close();
}
