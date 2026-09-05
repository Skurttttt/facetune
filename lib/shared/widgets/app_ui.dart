/// FaceTune's shared presentation primitives.
///
/// Import this rather than reaching for individual files, so a screen picks up
/// the whole system and there is one place to see what the system contains.
///
/// Anything exported here must be free of business logic and free of state
/// authority: these widgets render what they are handed. A primitive that reads
/// a provider or decides what data means belongs in its feature, not here.
library;

export 'app_shell.dart';
export 'buttons/button_progress.dart';
export 'buttons/primary_button.dart';
export 'buttons/secondary_button.dart';
export 'buttons/tertiary_button.dart';
export 'content/detail_row.dart';
export 'content/look_card_metadata.dart';
export 'content/section_header.dart';
export 'content/top_level_headers.dart';
export 'feedback/app_notice.dart';
export 'feedback/app_progress.dart';
export 'feedback/final_preview_loading_view.dart';
export 'feedback/loading_state.dart';
export 'feedback/makeup_plan_loading_view.dart';
export 'feedback/skeleton_card.dart';
export 'feedback/status_state.dart';
export 'layout/page_frame.dart';
export 'media/beauty_image.dart';
export 'media/color_swatch.dart';
export 'media/image_states.dart';
export 'media/private_image.dart';
export 'navigation/facetune_back_button.dart';
export 'navigation/facetune_nav_metrics.dart';
export 'navigation/facetune_top_bar.dart';
export 'overlays/app_overlays.dart';
export 'surfaces/app_card.dart';
