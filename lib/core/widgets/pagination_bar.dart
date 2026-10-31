import 'package:flutter/material.dart';

/// « 21–40 sur 134 » avec page précédente / suivante. Un callback null désactive le bouton.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.offset,
    required this.count,
    required this.total,
    this.onPrevious,
    this.onNext,
  });

  final int offset;
  final int count;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(
            child: Text(
              count == 0 ? '0 sur $total' : '${offset + 1}–${offset + count} sur $total',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Page précédente', icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
          IconButton(tooltip: 'Page suivante', icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ]),
      );
}
