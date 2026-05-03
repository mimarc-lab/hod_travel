import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/client_media_item.dart';
import 'client_media_viewer_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientHeroMedia
//
// Cinematic full-width hero image shown at the top of the client itinerary.
// 45% of viewport height on wide, 38% on narrow. Gradient overlay at bottom.
// Tapping opens the full-screen viewer.
// ─────────────────────────────────────────────────────────────────────────────

class ClientHeroMedia extends StatelessWidget {
  final ClientMediaItem        hero;
  final List<ClientMediaItem>  allItems;

  const ClientHeroMedia({
    super.key,
    required this.hero,
    required this.allItems,
  });

  @override
  Widget build(BuildContext context) {
    final wide    = MediaQuery.sizeOf(context).width >= 900;
    final height  = MediaQuery.sizeOf(context).height * (wide ? 0.45 : 0.38);
    final headers = _storageHeaders();
    final heroIdx = allItems.indexOf(hero);

    return GestureDetector(
      onTap: () => showClientMediaViewer(
        context,
        items:        allItems,
        initialIndex: heroIdx < 0 ? 0 : heroIdx,
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            Image.network(
              hero.displayUrl,
              headers:      headers,
              fit:          BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1A1A1A)),
            ),

            // Bottom gradient — lets content overlay text if needed
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x55000000)],
                  stops:  [0.55, 1.0],
                ),
              ),
            ),

            // Caption (optional, very understated)
            if (hero.caption?.isNotEmpty == true)
              Positioned(
                left:   24,
                right:  24,
                bottom: 20,
                child:  Text(
                  hero.caption!,
                  style: const TextStyle(
                    color:      Colors.white70,
                    fontSize:   11,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Map<String, String> _storageHeaders() {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return token != null ? {'Authorization': 'Bearer $token'} : {};
}
