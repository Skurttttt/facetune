import 'package:flutter/material.dart';

import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/services/auth_validators.dart';

/// One rule of the password contract, as the user sees it.
@immutable
class PasswordRequirement {
  const PasswordRequirement._(this.label, this._test);

  final String label;
  final bool Function(String password) _test;

  bool isMetBy(String password) => _test(password);

  /// The rules [AuthValidators.password] enforces, in its own order, with its
  /// own patterns.
  ///
  /// This is a *reading* of that validator, not a second policy: it decides
  /// nothing. Whether a password is accepted is still only the validator's
  /// answer, and a test holds the two to the same verdict for every input. If
  /// the validator changes, this list must change with it.
  static final all = <PasswordRequirement>[
    PasswordRequirement._('At least 8 characters', (p) => p.length >= 8),
    PasswordRequirement._(
      'At least one letter',
      (p) => RegExp('[A-Za-z]').hasMatch(p),
    ),
    PasswordRequirement._(
      'At least one number',
      (p) => RegExp('[0-9]').hasMatch(p),
    ),
  ];
}

/// Live guidance under a new-password field.
///
/// Presentation only. It listens to the field's own controller, so it repaints
/// on each keystroke without rebuilding the page, reading a provider, or making
/// a request.
///
/// Every criterion carries an icon, words, and a spoken state, so no state is
/// conveyed by colour alone. Unmet criteria stay neutral while the user types;
/// only once [showUnmetAsErrors] is set — after a submit attempt — do they turn
/// to the error treatment.
class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({
    required this.controller,
    super.key,
    this.showUnmetAsErrors = false,
  });

  final TextEditingController controller;
  final bool showUnmetAsErrors;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final requirement in PasswordRequirement.all)
          _RequirementRow(
            label: requirement.label,
            state: requirement.isMetBy(value.text)
                ? _RowState.met
                : showUnmetAsErrors
                ? _RowState.unmet
                : _RowState.pending,
          ),
      ],
    ),
  );
}

/// Says whether the confirmation matches, once there is enough to say.
///
/// Silent while the confirmation is empty or is still a prefix of the password
/// being typed, so it does not announce a mismatch on the first keystroke.
/// "Passwords match" appears only when [AuthValidators.confirmedPassword]
/// itself would accept the confirmation.
class PasswordMatchFeedback extends StatelessWidget {
  const PasswordMatchFeedback({
    required this.password,
    required this.confirmation,
    super.key,
    this.showMismatch = true,
  });

  final TextEditingController password;
  final TextEditingController confirmation;

  /// Off once the confirmation field shows its own live error, so a mismatch
  /// is never reported twice. "Passwords match" is unaffected.
  final bool showMismatch;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([password, confirmation]),
    builder: (context, _) {
      final state = _matchState(password.text, confirmation.text);
      if (state == null || (!state && !showMismatch)) {
        return const SizedBox.shrink();
      }
      return Semantics(
        liveRegion: true,
        child: _RequirementRow(
          label: state ? 'Passwords match' : 'Passwords do not match',
          state: state ? _RowState.met : _RowState.unmet,
          announceState: false,
        ),
      );
    },
  );

  static bool? _matchState(String password, String confirmation) {
    if (confirmation.isEmpty) {
      return null;
    }
    if (AuthValidators.confirmedPassword(confirmation, password) == null) {
      return true;
    }
    if (confirmation == password) {
      // Identical, but the password itself is not acceptable yet; the
      // checklist above already says why.
      return null;
    }
    if (confirmation.length < password.length &&
        password.startsWith(confirmation)) {
      return null;
    }
    return false;
  }
}

enum _RowState { pending, met, unmet }

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.label,
    required this.state,
    this.announceState = true,
  });

  final String label;
  final _RowState state;

  /// Appends "met" / "not met" to the spoken label. Off where the words
  /// already say it.
  final bool announceState;

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = switch (state) {
      _RowState.pending => (
        Icons.radio_button_unchecked_rounded,
        AppColors.muted(context),
      ),
      _RowState.met => (
        Icons.check_circle_rounded,
        AppTone.success.resolve(context).accent,
      ),
      _RowState.unmet => (
        AppTone.danger.icon,
        AppTone.danger.resolve(context).accent,
      ),
    };
    final spoken = announceState
        ? '$label, ${state == _RowState.met ? 'met' : 'not met'}'
        : label;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Semantics(
        label: spoken,
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: AppIconSizes.sm, color: colour),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: state == _RowState.pending
                        ? AppColors.muted(context)
                        : colour,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
