import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'player_pane.dart';

/// Immersive full-window player route for a single cid.
class PlayerPage extends StatelessWidget {
  const PlayerPage({
    super.key,
    required this.videoId,
    required this.cid,
    this.aid = 0,
    this.bvid = '',
    this.title = '',
    this.qn = 0,
  });

  final String videoId;
  final int cid;
  final int aid;
  final String bvid;
  final String title;
  final int qn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: PlayerPane(
          videoId: videoId,
          cid: cid,
          aid: aid,
          bvid: bvid,
          title: title,
          qn: qn,
          immersive: true,
          showBack: true,
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
    );
  }
}
