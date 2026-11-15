# Widget shape

Read when writing the first widget in a new app, or when unsure how the rules look together.
It shows the "Always" rules of the skill as code; it adds no rule of its own.

```dart
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item});
  final ItemEntity item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(context.m),             // token names: see responsive.dart
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(context.cardRadius),  // a token, never a number
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: context.headingFont)),
          SizedBox(height: context.xs),
          Text(item.subtitle,
              style: TextStyle(fontSize: context.captionFont, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
```
