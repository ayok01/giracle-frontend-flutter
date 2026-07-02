import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message.dart';
import 'authed_image.dart';

class MessageAttachments extends StatelessWidget {
  const MessageAttachments({
    super.key,
    required this.files,
    required this.baseUrl,
  });

  final List<MessageFileAttached> files;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: files.map((f) => _FileTile(file: f, baseUrl: baseUrl)).toList(),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.baseUrl});
  final MessageFileAttached file;
  final String baseUrl;

  Future<void> _open() async {
    final uri = Uri.parse('$baseUrl/message/file/${file.id}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _humanSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final url = '$baseUrl/message/file/${file.id}';
    if (file.type.startsWith('image')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AuthedNetworkImage(
            url: url,
            fit: BoxFit.cover,
            placeholder: (ctx) => Container(
              height: 120,
              color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __) => const Icon(Icons.broken_image),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(file.actualFileName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(_humanSize(file.size)),
          trailing: IconButton(
            icon: const Icon(Icons.download),
            onPressed: _open,
          ),
          onTap: _open,
        ),
      ),
    );
  }
}

class MessageUrlPreviews extends StatelessWidget {
  const MessageUrlPreviews({super.key, required this.previews});
  final List<MessageUrlPreview> previews;

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (previews.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: previews.map((p) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(p.url),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.imageLink != null && p.imageLink!.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: p.imageLink!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (p.faviconLink.isNotEmpty)
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CachedNetworkImage(
                                  imageUrl: p.faviconLink,
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.link, size: 16),
                                ),
                              )
                            else
                              const Icon(Icons.link, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p.title.isEmpty ? p.url : p.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (p.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            p.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
