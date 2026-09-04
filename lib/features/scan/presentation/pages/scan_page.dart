import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../analysis/presentation/controllers/face_analysis_state.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/entities/selfie_source.dart';
import '../controllers/scan_controller.dart';
import '../controllers/scan_state.dart';

class ScanPage extends ConsumerWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final analysisState = ref.watch(faceAnalysisControllerProvider);
    final selfie = state.selfie;
    final isBusy = state.isBusy || analysisState.isBusy;
    // Described, never quantified: nothing here knows what fraction of an
    // upload or a model call has elapsed, so nothing claims to.
    final progressLabel = switch (state.stage) {
      ScanStage.acquiring => 'Opening your photos…',
      ScanStage.validatingLocal => 'Checking photo…',
      _ => analysisState.isBusy ? 'Analyzing your features…' : null,
    };
    // The acquisition state: nothing chosen, nothing wrong, nothing analysed.
    //
    // Only this state gets the fixed non-scrolling composition, and the reason
    // is that only this state has bounded content. A rejected photo shows the
    // validator's own message, an analysis failure shows the server's, and
    // neither has a length this screen controls — pinning those into a fixed
    // column is how a recovery action ends up off-screen. Everything past
    // acquisition keeps the scrolling layout it already had.
    final isChoosing =
        selfie == null &&
        state.errorMessage == null &&
        analysisState.message == null &&
        analysisState.status == FaceAnalysisStatus.idle;

    ref.listen<FaceAnalysisState>(faceAnalysisControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.status != FaceAnalysisStatus.success &&
          next.status == FaceAnalysisStatus.success &&
          context.mounted) {
        context.push(AppConstants.analysisRoute);
      }
    });

    return Scaffold(
      appBar: FaceTuneTopBar(
        title: 'New scan',
        actions: [
          if (selfie != null || analysisState.status != FaceAnalysisStatus.idle)
            IconButton(
              tooltip: 'Start over',
              onPressed: isBusy ? null : () => _beginNewScan(ref),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      // Reserved space, not an overlay. The two acquisition actions are the
      // point of this screen, so they own layout the body is measured against
      // and can never end up below the fold — the same architecture the
      // Palette's persistent CTA uses.
      bottomNavigationBar: isChoosing
          ? _AcquisitionActions(
              isBusy: isBusy,
              galleryLabel: _galleryLabel(state, false),
              compactGalleryLabel: _compactGalleryLabel(state),
              onTakePhoto: () => context.push(AppConstants.liveScanRoute),
              onChooseGallery: () => _chooseFromGallery(ref),
            )
          : null,
      body: SafeArea(
        child: PageFrame(
          // The action bar already clears the navigation and gesture areas.
          // Keeping PageFrame's tail as well would reserve the same space
          // twice, which is exactly the height this screen cannot spare.
          padding: isChoosing
              ? PageFrame.defaultPadding.copyWith(bottom: AppSpacing.md)
              : PageFrame.defaultPadding,
          child: isChoosing
              ? _AcquisitionBody(progressLabel: progressLabel)
              : ListView(
                  children: [
                    Text(
                      selfie == null
                          ? "Let's find your best look."
                          : 'Preview your selfie',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      selfie == null
                          ? 'Use a clear, front-facing photo in natural light.'
                          : 'Make sure your face is clear before continuing.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.muted(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SelfieFrame(state: state, progressLabel: progressLabel),
                    const SizedBox(height: AppSpacing.lg),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ScanError(
                        message: state.errorMessage!,
                        title: state.stage == ScanStage.validationFailed
                            ? 'This photo needs another try'
                            : null,
                        canOpenSettings: state.canOpenSettings,
                        canRetryValidation: state.canRetryValidation,
                        canReselect: state.canReselect,
                        onOpenSettings: controller.openSettings,
                        onRetryValidation: controller.validateForAnalysis,
                        onReselect: () => _chooseFromGallery(ref),
                      ),
                    ],
                    if (analysisState.message != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _AnalysisError(
                        state: analysisState,
                        onRetry: selfie != null && state.localValidation != null
                            ? () => ref
                                  .read(faceAnalysisControllerProvider.notifier)
                                  .analyze(
                                    selfie: selfie,
                                    localValidation: state.localValidation!,
                                  )
                            : null,
                        onReselect: () => _chooseFromGallery(ref),
                        onSignIn: () => _recoverExpiredSession(ref),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    // Choosing a photo is now the whole gallery interaction. It used
                    // to be the first of three taps — choose, then "Validate selfie",
                    // then "Analyze selfie" — and neither of the other two offered a
                    // decision. Selection is the intent; the app acts on it.
                    if (analysisState.status == FaceAnalysisStatus.success) ...[
                      PrimaryButton(
                        label: 'View analysis',
                        icon: Icons.visibility_outlined,
                        onPressed: isBusy
                            ? null
                            : () => context.push(AppConstants.analysisRoute),
                      ),
                    ] else ...[
                      PrimaryButton(
                        label: 'Take a photo',
                        icon: Icons.camera_alt_outlined,
                        // Opens the in-app live camera rather than handing off to
                        // the OS picker. Local guidance can only exist where the
                        // frames are, and the OS camera never gave us any.
                        onPressed: isBusy
                            ? null
                            : () => context.push(AppConstants.liveScanRoute),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        key: const ValueKey('gallery-choose'),
                        label: _galleryLabel(state, selfie != null),
                        icon: Icons.photo_library_outlined,
                        onPressed: isBusy
                            ? null
                            : () => _chooseFromGallery(ref),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  String _galleryLabel(ScanState state, bool hasSelfie) {
    if (state.isBusy && state.activeSource == SelfieSource.gallery) {
      return 'Preparing selfie...';
    }
    return hasSelfie ? 'Choose another photo' : 'Choose from gallery';
  }

  /// The gallery label for a button that is sharing a row.
  ///
  /// Only reachable from the acquisition state, where no selfie exists yet, so
  /// there is no "another photo" case to shorten.
  String _compactGalleryLabel(ScanState state) {
    if (state.isBusy && state.activeSource == SelfieSource.gallery) {
      return 'Preparing selfie...';
    }
    return 'Choose gallery';
  }

  /// Picks a photo and runs the whole sequence.
  ///
  /// Any previous analysis is cleared first, so a new photo can never be
  /// confused with the result of the last one.
  Future<void> _chooseFromGallery(WidgetRef ref) async {
    ref.read(faceAnalysisControllerProvider.notifier).clear();
    await ref
        .read(scanControllerProvider.notifier)
        .chooseFromGalleryAndAnalyze();
  }

  Future<void> _beginNewScan(WidgetRef ref) async {
    ref.read(faceAnalysisControllerProvider.notifier).clear();
    await ref.read(scanControllerProvider.notifier).beginNewScan();
  }

  Future<void> _recoverExpiredSession(WidgetRef ref) {
    return ref.read(authControllerProvider.notifier).recoverExpiredSession();
  }
}

/// The framing guide shown before a photo exists.
///
/// It fills whatever slot it is given rather than claiming a 3:4 block, which
/// is what let it push the actions off a phone screen. It is a drawing, and
/// nothing more: it does not detect a face, count people, check framing, or
/// look at the camera. Nothing here reads an image.
class _FaceGuide extends StatelessWidget {
  const _FaceGuide({this.progressLabel});

  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final info = AppTone.info.resolve(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: info.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: info.border, width: AppBorders.emphasis),
        ),
        // Passthrough rather than expand: this guide is given a tight height
        // when it is absorbing slack, and a minimum-only one when the page is
        // scrolling. Passing the incoming constraints through lets the same
        // widget fill the first and grow past the second — an expanding Stack
        // needs a bounded height and would fail the second outright.
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            const _FaceGuideContent(),
            if (progressLabel != null)
              Positioned.fill(child: _ProgressScrim(label: progressLabel!)),
          ],
        ),
      ),
    );
  }
}

/// The guide's mark and its one line of copy.
class _FaceGuideContent extends StatelessWidget {
  const _FaceGuideContent();

  @override
  Widget build(BuildContext context) {
    final info = AppTone.info.resolve(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Proportional to the slot, not to a device. Floored so the mark stays
        // a face rather than a bullet, and capped at what it used to be so a
        // tall screen does not turn it into a poster.
        final iconSize = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * 0.4).clamp(
                AppIconSizes.lg,
                AppIconSizes.hero * 2,
              )
            : AppIconSizes.hero * 2;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.face_rounded, size: iconSize, color: info.accent),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                // "Guide", not "frame": the shape on screen is advice about
                // where to put your face, and calling it a frame invited the
                // reading that something was watching it.
                'Center your face in the guide',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: info.onSurface),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The busy veil drawn over the guide or the chosen photo.
class _ProgressScrim extends StatelessWidget {
  const _ProgressScrim({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.32),
    child: Center(
      // Fixed white: this sits on a scrim over the user own photo, whose
      // brightness the theme knows nothing about.
      child: AppProgress(
        size: AppProgressSize.large,
        color: Colors.white,
        semanticLabel: label,
      ),
    ),
  );
}

/// The two ways into a photo, side by side.
///
/// Side by side is the point: stacked, two full-width buttons cost 124pt of a
/// screen that has to hold a framing guide as well. They fall back to stacked
/// only when a label would otherwise wrap or truncate — a measured decision,
/// not a device check, so it holds for a long label, a large text scale, and a
/// narrow phone alike.
class _AcquisitionActions extends StatelessWidget {
  const _AcquisitionActions({
    required this.isBusy,
    required this.galleryLabel,
    required this.compactGalleryLabel,
    required this.onTakePhoto,
    required this.onChooseGallery,
  });

  final bool isBusy;

  /// What the gallery action is called when it has a row to itself.
  final String galleryLabel;

  /// What it is called when it is sharing a row.
  ///
  /// "Choose from gallery" does not fit half a phone's width beside a primary
  /// button — measured, not assumed. Rather than let it wrap, ellipsise, or
  /// force both actions to stack, the shorter form is used for the side-by-side
  /// arrangement only.
  final String compactGalleryLabel;

  final VoidCallback onTakePhoto;
  final VoidCallback onChooseGallery;

  static const String _takePhotoLabel = 'Take a photo';

  /// Width a button spends on everything that is not its label: Material's
  /// leading and trailing padding for an icon button, the icon itself, and the
  /// gap between icon and text.
  ///
  /// A measured constant rather than a guess — the theme sets no padding, so
  /// these buttons inherit Material's, and `scan_entry_page_test.dart` pins the
  /// figure against a real laid-out button so a framework change fails a test
  /// instead of silently wrapping a label.
  static const double _buttonChrome = 66;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.dividerTheme.color ?? theme.dividerColor,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final rowSpace = width - AppSpacing.sm;
                  final photoNeeds = _needs(context, _takePhotoLabel);
                  final fullNeeds = _needs(context, galleryLabel);
                  final compactNeeds = _needs(context, compactGalleryLabel);

                  // Prefer the full wording, in a row, and give up each of
                  // those in turn rather than let a label wrap: full label in
                  // a row, then the short label in a row, then stacked.
                  final double? galleryInRow;
                  final String rowGalleryLabel;
                  if (photoNeeds + fullNeeds <= rowSpace) {
                    galleryInRow = fullNeeds;
                    rowGalleryLabel = galleryLabel;
                  } else if (photoNeeds + compactNeeds <= rowSpace) {
                    galleryInRow = compactNeeds;
                    rowGalleryLabel = compactGalleryLabel;
                  } else {
                    galleryInRow = null;
                    rowGalleryLabel = galleryLabel;
                  }

                  final primary = PrimaryButton(
                    label: _takePhotoLabel,
                    icon: Icons.camera_alt_outlined,
                    // Opens the in-app live camera rather than handing off to
                    // the OS picker. Local guidance can only exist where the
                    // frames are, and the OS camera never gave us any.
                    onPressed: isBusy ? null : onTakePhoto,
                  );
                  final secondary = SecondaryButton(
                    key: const ValueKey('gallery-choose'),
                    // Stacked, the button has the whole width, so it can carry
                    // the long form even when a row could not.
                    label: galleryInRow == null
                        ? (fullNeeds <= width
                              ? galleryLabel
                              : compactGalleryLabel)
                        : rowGalleryLabel,
                    icon: Icons.photo_library_outlined,
                    onPressed: isBusy ? null : onChooseGallery,
                  );

                  if (galleryInRow == null) {
                    // Primary stays first when they stack.
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        primary,
                        const SizedBox(height: AppSpacing.sm),
                        secondary,
                      ],
                    );
                  }

                  // Equal halves whenever both labels fit in one, which is the
                  // arrangement that reads as deliberate. When they do not,
                  // width is split in proportion to what each label actually
                  // needs — a near-equal split that fits beats a perfectly
                  // equal one that wraps.
                  final half = rowSpace / 2;
                  final equal = photoNeeds <= half && galleryInRow <= half;
                  return Row(
                    children: [
                      Expanded(
                        flex: equal ? 1000 : (photoNeeds * 10).round(),
                        child: primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: equal ? 1000 : (galleryInRow * 10).round(),
                        child: secondary,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// How wide a button carrying [label] must be to keep it on one line.
  ///
  /// Measured at the reader's own text scale, so raising text size rearranges
  /// the row for the same reason a long translation would.
  static double _needs(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width + _buttonChrome;
  }
}

class _SelfieFrame extends StatelessWidget {
  const _SelfieFrame({required this.state, this.progressLabel});

  final ScanState state;

  /// What the app is doing right now, or null when it is waiting on the user.
  ///
  /// Drives both the scrim and what a screen reader announces, so the two can
  /// never disagree about whether anything is happening.
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final selfie = state.selfie;
    final info = AppTone.info.resolve(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: AspectRatio(
        // Was a fixed 340pt box. A selfie is portrait, so an aspect ratio
        // frames it correctly on a 320pt phone and a 720pt tablet alike,
        // instead of letterboxing on one and cropping on the other.
        aspectRatio: 3 / 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: info.surface,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: info.border, width: AppBorders.emphasis),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (selfie == null)
                const _FaceGuideContent()
              else
                LayoutBuilder(
                  builder: (context, constraints) => Image.file(
                    File(selfie.originalPath),
                    fit: BoxFit.cover,
                    // The on-device original can be 2048 px; the preview box is
                    // now measured rather than assumed.
                    cacheWidth: decodeWidthFor(context, constraints),
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Preview unavailable. Please choose another image.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: info.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
              if (progressLabel != null) _ProgressScrim(label: progressLabel!),
            ],
          ),
        ),
      ),
    );
  }
}

/// The acquisition screen: choose a source, having been told how.
///
/// A fixed composition on a normal phone. The face guide is the only elastic
/// element, so it absorbs whatever height the device has spare and the rest of
/// the screen keeps its natural size.
///
/// Below [_fixedCompositionFloor] the same content is scrolled instead. That is
/// not a device carve-out: at large accessibility text the intro alone can run
/// four lines, and there is no honest arrangement of five text blocks and a
/// guide that fits a short viewport. Scrolling the guidance is the one fallback
/// that hides nothing — and because the actions live in the bar below, they
/// stay reachable either way.
class _AcquisitionBody extends StatelessWidget {
  const _AcquisitionBody({this.progressLabel});

  final String? progressLabel;

  /// Body height, at the ambient text scale, below which the fixed composition
  /// stops fitting. Scaled rather than compared raw: the content grows with the
  /// reader's text size, so the threshold has to as well.
  static const double _fixedCompositionFloor = 420;

  /// What the guide keeps in the scrolling fallback, where nothing constrains
  /// it. Below this it stops reading as a framing guide and becomes a band with
  /// an icon in it.
  static const double _guideFallbackHeight = 240;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intro = <Widget>[
      Text("Let's find your best look.", style: theme.textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Use a clear, front-facing photo in natural light.',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: AppColors.muted(context),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
    const trailing = <Widget>[
      SizedBox(height: AppSpacing.md),
      _CompactGuidance(),
      SizedBox(height: AppSpacing.xxs),
      _PhotoTipsButton(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final floor = MediaQuery.textScalerOf(
          context,
        ).scale(_fixedCompositionFloor);
        if (constraints.maxHeight >= floor) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...intro,
              // The one elastic element on the screen, and the reason nothing
              // here needs a hardcoded height.
              //
              // `Expanded` settles the vertical axis only. Horizontally this
              // column aligns to the start, which hands every child a *loose*
              // width and lets it size to its own content — so the guide was
              // coming out as wide as its caption and no wider, leaving a dead
              // column beside it. The width is asked for explicitly rather than
              // inherited by luck.
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: _FaceGuide(progressLabel: progressLabel),
                ),
              ),
              ...trailing,
            ],
          );
        }
        return ListView(
          children: [
            ...intro,
            // A floor, not a height. At large text the guide's own copy runs
            // several lines, and pinning it to a constant is what made it
            // overflow instead of simply being taller.
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: _guideFallbackHeight,
              ),
              child: _FaceGuide(progressLabel: progressLabel),
            ),
            ...trailing,
          ],
        );
      },
    );
  }
}

/// The two compact lines that replaced the permanent five-row card.
///
/// Same requirements, a quarter of the height. The full five are one tap away
/// in [_PhotoTipsButton], which is where a reader who wants them will look —
/// and a reader who does not now gets their screen back.
class _CompactGuidance extends StatelessWidget {
  const _CompactGuidance();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.muted(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The middot separates two requirements for the eye but reads as
        // nothing at all to a screen reader, so each line carries a spoken
        // form of the same content.
        Text(
          'One person · Face fully visible',
          style: style,
          semanticsLabel: 'One person. Face fully visible.',
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Even lighting · Clear, front-facing photo',
          style: style,
          semanticsLabel: 'Even lighting. Clear, front-facing photo.',
        ),
      ],
    );
  }
}

/// Opens the full guidance without spending screen on it.
class _PhotoTipsButton extends StatelessWidget {
  const _PhotoTipsButton();

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TertiaryButton(
      key: const ValueKey('photo-tips'),
      label: 'Photo tips',
      icon: Icons.info_outline_rounded,
      onPressed: () =>
          showAppBottomSheet<void>(context, child: const _PhotoTipsSheet()),
    ),
  );
}

/// The five rules, in their original wording, on the app's own sheet.
///
/// Information only. Opening it starts nothing: no camera, no analysis, no
/// network, no AI. It reads a const list and draws it.
class _PhotoTipsSheet extends StatelessWidget {
  const _PhotoTipsSheet();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A heading, because five icon rows with no label read as decoration.
        // These are the checks the selfie is about to be measured against, and
        // saying so turns a list into an explanation.
        Text(
          'For the best result',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        const _TipRow(Icons.person_outline_rounded, 'One person only'),
        const _TipRow(Icons.face_outlined, 'Face fully visible'),
        const _TipRow(Icons.light_mode_outlined, 'Good, even lighting'),
        const _TipRow(Icons.blur_off_rounded, 'Avoid heavy blur'),
        const _TipRow(Icons.screen_rotation_outlined, 'Avoid extreme angles'),
        const SizedBox(height: AppSpacing.sm),
        // A sheet is dismissed, not navigated back from. An explicit control
        // says so, and gives a reader who cannot drag a way out.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TertiaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    ),
  );
}

class _ScanError extends StatelessWidget {
  const _ScanError({
    required this.message,
    required this.canOpenSettings,
    required this.canRetryValidation,
    required this.canReselect,
    required this.onOpenSettings,
    required this.onRetryValidation,
    required this.onReselect,
    this.title,
  });

  final String message;

  /// A heading for the failure, when one adds something.
  ///
  /// A rejected photo gets one, because "This photo needs another try" frames
  /// what follows as a fixable property of the image rather than as an error
  /// the user caused. The message beneath it is the validator's own words —
  /// never a substitute reason invented to sound friendlier.
  final String? title;

  final bool canOpenSettings;
  final bool canRetryValidation;
  final bool canReselect;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetryValidation;
  final VoidCallback onReselect;

  @override
  Widget build(BuildContext context) => AppNotice(
    // Was the success tint. Every recovery action and every condition below is
    // unchanged — only which surface the failure is drawn on.
    tone: AppTone.danger,
    title: title,
    message: message,
    liveRegion: true,
    actions: [
      if (canOpenSettings)
        TertiaryButton(
          label: 'Open Settings',
          icon: Icons.settings_outlined,
          onPressed: onOpenSettings,
        ),
      if (canRetryValidation)
        TertiaryButton(
          label: 'Retry validation',
          icon: Icons.refresh_rounded,
          onPressed: onRetryValidation,
        ),
      if (canReselect)
        TertiaryButton(
          label: 'Choose another photo',
          icon: Icons.photo_library_outlined,
          onPressed: onReselect,
        ),
    ],
  );
}

class _AnalysisError extends StatelessWidget {
  const _AnalysisError({
    required this.state,
    required this.onReselect,
    required this.onSignIn,
    this.onRetry,
  });

  final FaceAnalysisState state;
  final VoidCallback? onRetry;
  final VoidCallback onReselect;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final needsSignIn =
        state.status == FaceAnalysisStatus.authenticationFailure;
    final needsAnotherPhoto =
        state.status == FaceAnalysisStatus.validationFailure ||
        (state.status == FaceAnalysisStatus.geminiFailure && !state.retryable);
    return AppNotice(
      tone: AppTone.danger,
      title: 'Analysis paused',
      message: state.message ?? 'Please try again.',
      liveRegion: true,
      // The same three-way choice as before, in the same order and under the
      // same conditions: retry if the failure is retryable, otherwise sign in,
      // otherwise choose another photo.
      actions: [
        if (state.retryable && onRetry != null)
          TertiaryButton(
            label: 'Retry analysis',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          )
        else if (needsSignIn)
          TertiaryButton(
            label: 'Sign in again',
            icon: Icons.login_rounded,
            onPressed: onSignIn,
          )
        else if (needsAnotherPhoto)
          TertiaryButton(
            label: 'Choose another photo',
            icon: Icons.photo_library_outlined,
            onPressed: onReselect,
          ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs + 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.rose, size: AppIconSizes.sm),
        const SizedBox(width: AppSpacing.sm),
        // Expanded so a tip wraps instead of overflowing once the reader
        // raises their text size.
        Expanded(child: Text(label)),
      ],
    ),
  );
}
