// FaceTune Web Admin entrypoint (WA-2).
//
// Built separately from the consumer app:
//
//     flutter build web -t lib/admin_main.dart --dart-define-from-file=config/production.json
//
// so the admin bundle contains only what `lib/admin/` reaches. See
// docs/WEB_ADMIN_SETUP.md.
import 'admin/app/admin_bootstrap.dart';

Future<void> main() => bootstrapAdmin();
