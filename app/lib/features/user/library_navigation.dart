import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route id for `/video/:id` from bvid or aid.
String libraryVideoRouteId({required String bvid, required int aid}) {
  final id = bvid.isNotEmpty ? bvid : 'av$aid';
  if (id == 'av0' || id.isEmpty) return '';
  return id;
}

/// Push the watch page for a library list item.
void openLibraryVideo(
  BuildContext context, {
  required String bvid,
  required int aid,
  Object? heroTag,
}) {
  final id = libraryVideoRouteId(bvid: bvid, aid: aid);
  if (id.isEmpty) return;
  context.push(
    '/video/${Uri.encodeComponent(id)}',
    extra: heroTag,
  );
}
