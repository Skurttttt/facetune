import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../shared/widgets/app_ui.dart';

class PreviewResultPage extends StatefulWidget {
  const PreviewResultPage({super.key});

  @override
  State<PreviewResultPage> createState() => _PreviewResultPageState();
}

class _PreviewResultPageState extends State<PreviewResultPage> {
  double reveal = .58;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your Soft Glam look'),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share_rounded)),
      ],
    ),
    body: SafeArea(
      child: PageFrame(
        child: ListView(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              child: SizedBox(
                height: 390,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0x227D2947),
                          BlendMode.softLight,
                        ),
                        child: Image.asset(
                          'assets/images/beauty_portrait.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      ClipRect(
                        clipper: _RevealClipper(reveal),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Color(0x08000000),
                            BlendMode.saturation,
                          ),
                          child: Image.asset(
                            'assets/images/beauty_portrait.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        left: constraints.maxWidth * reveal - 1,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 2, color: Colors.white),
                      ),
                      Positioned(
                        left: constraints.maxWidth * reveal - 22,
                        top: 176,
                        child: const CircleAvatar(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.rose,
                          child: Icon(Icons.compare_arrows_rounded),
                        ),
                      ),
                      const Positioned(
                        left: 14,
                        top: 14,
                        child: _ImageLabel('Before'),
                      ),
                      const Positioned(
                        right: 14,
                        top: 14,
                        child: _ImageLabel('After'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Slider(
              value: reveal,
              onChanged: (value) => setState(() => reveal = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            const SectionHeader('Your palette'),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Swatch(Color(0xFFC58D6E), 'Warm beige'),
                _Swatch(Color(0xFFD88983), 'Peach rose'),
                _Swatch(Color(0xFF795052), 'Cocoa'),
                _Swatch(Color(0xFFA95F6E), 'Rosewood'),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader('Makeup breakdown'),
            const SizedBox(height: AppSpacing.sm),
            const _BreakdownTile(
              'Complexion',
              'Luminous warm-beige base with softly sculpted contours.',
            ),
            const _BreakdownTile(
              'Eyes',
              'Cocoa shadow, diffused liner, and a satin inner highlight.',
            ),
            const _BreakdownTile(
              'Cheeks & lips',
              'Peach-rose blush paired with a muted rosewood lip.',
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Save this look',
              icon: Icons.favorite_border_rounded,
              onPressed: () => context.go(AppConstants.savedRoute),
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Generate another variation',
              icon: Icons.refresh_rounded,
              onPressed: () {},
            ),
          ],
        ),
      ),
    ),
  );
}

class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.value);
  final double value;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * value, size.height);

  @override
  bool shouldReclip(_RevealClipper oldClipper) => oldClipper.value != value;
}

class _ImageLabel extends StatelessWidget {
  const _ImageLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white)),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    child: Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile(this.title, this.description);
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.petal,
            foregroundColor: AppColors.rose,
            child: Icon(Icons.brush_outlined),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
