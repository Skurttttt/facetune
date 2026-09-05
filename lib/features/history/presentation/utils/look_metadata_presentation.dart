import '../models/history_feed_item.dart';

/// The four things a FaceTune look says about itself, in one vocabulary.
///
/// History and Home draw different cards — a horizontal row and a compact
/// portrait tile — but they must not describe the same record in two different
/// languages. Before this existed Home rendered a style name over an ISO date
/// (`2026-09-05`) while History rendered a title, a mode, a supporting fact and
/// `Sep 5 · 2:41 PM`; the same session read as two unrelated things depending on
/// which screen you were standing on.
///
/// This is presentation vocabulary only. Every field is copied from the
/// [HistoryFeedItem] adapter that already reads one authority, so nothing here
/// can invent a fact or fill one mode's line from the other's.
typedef LookMetadataPresentation = ({
  String title,
  String modeLabel,
  String secondaryMetadata,
  String formattedDateTime,
});

/// Reads one look's four lines off the adapter for its own authority.
///
/// Pure and cheap: field reads and a string build, no I/O. In particular it
/// touches no image URL, so putting metadata on a card costs no signing call.
///
/// [now] is injected only so the year rule in [formatLookTimestamp] is testable.
LookMetadataPresentation lookMetadataOf(
  HistoryFeedItem item, {
  DateTime? now,
}) => (
  title: item.styleName,
  modeLabel: item.modeLabel,
  secondaryMetadata: item.metadataLabel,
  formattedDateTime: formatLookTimestamp(item.occurredAt, now: now),
);

/// `Sep 5 · 2:41 PM`, with the year only when it is not the current one.
///
/// A two-year-old session rendered as "Sep 5" is not a shorter truth, it is a
/// different one, so the year appears exactly when it is needed to keep the
/// line honest.
///
/// Lifted out of the History card widget in POLISH-P2. It was a static on a
/// widget, which meant the only way for Home to format a date the same way was
/// to import History's card — so Home had quietly grown a second formatter
/// instead, and the two disagreed.
String formatLookTimestamp(DateTime value, {DateTime? now}) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = value.toLocal();
  final currentYear = (now ?? DateTime.now()).toLocal().year;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  final day = '${months[date.month - 1]} ${date.day}';
  final calendar = date.year == currentYear ? day : '$day, ${date.year}';
  return '$calendar · $hour:$minute $period';
}
