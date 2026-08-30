import 'dart:io';

import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the per-category guideline modules and the product
/// presentation adapters.
///
/// Deno is not installed here, so `category_prompts_test.ts` cannot be
/// executed. These assert the same properties against the TypeScript source.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const dir = 'supabase/functions/generate-tutorial-step-v4';
  final categories = source('$dir/category_prompts.ts');
  final prompt = source('$dir/prompt.ts');
  final presentation = source('$dir/product_presentation.ts');
  final index = source('$dir/index.ts');
  final config = source('supabase/functions/_shared/tutorial_ai_config.ts');

  /// The category keys declared in the guidance record, in order.
  List<String> guidanceKeys() {
    final block = RegExp(
      r'CATEGORY_GUIDANCE: Record<TutorialCategory, CategoryGuidance> = \{([\s\S]*?)\n\};',
    ).firstMatch(categories)!.group(1)!;
    return RegExp(
      r'^  ([a-z_]+): \{',
      multiLine: true,
    ).allMatches(block).map((match) => match.group(1)!).toList();
  }

  group('every supported category has guidance', () {
    test('the guidance record covers the vocabulary exactly, in order', () {
      expect(
        guidanceKeys(),
        TutorialCategory.orderedVocabulary
            .map((category) => category.code)
            .toList(),
        reason: 'a missing category would fail closed, but silently',
      );
    });

    test('every category is renderable now, not just the pilot', () {
      expect(config, contains('RENDERABLE_CATEGORIES'));
      expect(config, contains('>(TUTORIAL_CATEGORIES)'));
      expect(
        config,
        isNot(contains('PILOT_CATEGORIES')),
        reason: 'the V4-9 pilot gate is superseded',
      );
    });

    test('enabling a category without guidance still fails closed', () {
      expect(index, contains('isRenderableCategory(context.category)'));
      expect(index, contains('categoryGuidance(context.category)'));
      expect(index, contains('if (guidance === null)'));
      expect(index, contains('category_not_available'));
    });
  });

  group('each category names its own landmarks', () {
    const expected = <String, List<String>>{
      'foundation': <String>['perimeter', 'blended outward', 'jawline'],
      'concealer': <String>['under-eye', 'blending direction', 'fade'],
      'contour_bronzer': <String>['cheekbone', 'temple', 'jawline', 'nose'],
      'blush': <String>['apple', 'cheekbone', 'upward and outward'],
      'highlighter': <String>['brow bone', 'inner corner', "Cupid's bow"],
      'eyebrows': <String>['arch', 'tail', 'direction'],
      'eyeshadow': <String>['mobile lid', 'crease', 'outer V', 'inner corner'],
      'eyeliner': <String>['lash line', 'wing', 'curvature', 'endpoint'],
      'lips': <String>[
        "Cupid's bow",
        'corners',
        'lower lip boundary',
        'border',
      ],
    };

    for (final entry in expected.entries) {
      test('${entry.key} marks its documented structures', () {
        final block = RegExp(
          '  ${entry.key}: \\{([\\s\\S]*?)\\n  \\},',
        ).firstMatch(categories)!.group(1)!;
        for (final fragment in entry.value) {
          expect(
            block,
            contains(fragment),
            reason: '${entry.key} must reference "$fragment"',
          );
        }
      });
    }
  });

  group('each category forbids its own way of applying makeup', () {
    const expected = <String, String>{
      'foundation': 'Do not tint, even out, smooth, or re-tone any skin',
      'concealer': 'Do not brighten, lighten, or smooth',
      'contour_bronzer': 'Do not add any brown, bronze, tan, or shadow tone',
      'blush': 'Do not add any pink, peach, coral, or red flush',
      'highlighter': 'Do not add shimmer, glow, sheen, sparkle',
      'eyebrows': 'Do not fill, darken, thicken, or redraw the eyebrows',
      'eyeshadow': 'Do not add any eyeshadow colour, depth, or shading',
      'eyeliner': 'Do not draw black or coloured liner on the lash line',
      'lips': 'Do not fill, tint, gloss, or colour the lips',
    };

    test('every prohibition is category-specific, not generic', () {
      expected.forEach((category, fragment) {
        expect(
          categories,
          contains(fragment),
          reason: '$category needs its own prohibition wording',
        );
      });
    });

    test('contour is told not to render brown shading', () {
      // The sentence wraps across TypeScript string concatenation, so assert
      // the fragment that actually appears in source.
      expect(categories, contains('darken, slim, or sculpt the face'));
    });

    test('contour and highlighter mark only what is visible', () {
      expect(categories, contains('those you can genuinely see'));
      expect(categories, contains('only if you can see it'));
      expect(categories, contains('visibly gained brightness'));
    });
  });

  group('invariant rules live in one builder', () {
    test('authority rules are written once, not per category', () {
      for (final rule in <String>[
        'PLACEMENT COMES FROM IMAGE B ONLY',
        'DRAW ONLY GUIDELINES',
        'NEVER APPLY MAKEUP',
        'NO TEXT OF ANY KIND',
        'PRESERVE THE PHOTOGRAPH',
        'ONLY THIS CATEGORY',
      ]) {
        expect(
          RegExp(RegExp.escape(rule)).allMatches(prompt).length,
          1,
          reason: '$rule must exist once so it cannot drift per category',
        );
        expect(categories, isNot(contains(rule)));
      }
    });

    test('the canonical preview outranks convention and face analysis', () {
      expect(
        prompt,
        contains('Do not use a standard, textbook, or flattering placement.'),
      );
      expect(
        prompt,
        contains(
          'Face shape, eye shape, lip shape, and the chosen style may help you '
          'interpret what you see, but they never override it',
        ),
      );
    });

    test('the category and its prohibition are interpolated per request', () {
      expect(prompt, contains(r'${options.category}'));
      expect(prompt, contains(r'${options.guidance.landmarks}'));
      expect(prompt, contains(r'${options.guidance.prohibition}'));
    });
  });

  group('excluded and unsupported categories are rejected', () {
    test('inclusion is enforced by the resolver, before any prompt', () {
      final resolver = source(
        'supabase/functions/_shared/tutorial_source_resolver.ts',
      );
      expect(resolver, contains('category_not_included'));
      expect(resolver, contains('unsupported_category'));
      expect(
        index,
        contains('resolveTutorialSource(client, userId,'),
        reason: 'the renderer never bypasses the manifest gate',
      );
    });

    test('the gate runs before any spending', () {
      final gate = index.indexOf('if (guidance === null)');
      final quota = index.indexOf('consumeAiQuota(');
      final gemini = index.indexOf('requestGeminiGuideline(');
      expect(gate, greaterThan(-1));
      expect(gate, lessThan(quota));
      expect(gate, lessThan(gemini));
    });
  });

  group('1K remains locked', () {
    test('the resolution is unchanged and still defined once', () {
      expect(
        config,
        contains('export const TUTORIAL_OUTPUT_RESOLUTION = "1K" as const'),
      );
      expect(RegExp('"1K"').allMatches(config).length, 1);
      expect(
        categories + prompt + presentation + index,
        isNot(contains('0.5K')),
      );
    });

    test('the prompt version was bumped for the changed wording', () {
      expect(config, contains('"tutorial_guideline_v4_2"'));
      expect(config, isNot(contains('"tutorial_guideline_v4_1"')));
    });
  });

  group('Standard Mode presentation stays brand-neutral', () {
    test('it carries shade descriptions, never products to buy', () {
      expect(presentation, contains('shadeName'));
      expect(presentation, contains('A colour description, never a product'));
      // "retailer" appears once, in the comment stating it is excluded. What
      // must be absent is a FIELD carrying any of these.
      for (final forbidden in <String>[
        'brandName:',
        'retailer:',
        'price:',
        'purchaseUrl:',
        'productLine:',
      ]) {
        expect(presentation, isNot(contains(forbidden)));
      }
    });

    test('empty upstream fields become null, not blank display values', () {
      expect(
        presentation,
        contains('entry.finish.length > 0 ? entry.finish : null'),
      );
    });
  });

  group('My Makeup Kit presentation mirrors the snapshot', () {
    test('every snapshot field is carried through unchanged', () {
      for (final field in <String>[
        'productId',
        'inventoryCategory',
        'productName',
        'colorHex',
        'colorLabel',
        'finish',
        'foundationDepth',
        'foundationUndertone',
      ]) {
        expect(presentation, contains(field));
      }
    });

    test('nothing is invented for a missing field', () {
      expect(presentation, contains('Never substituted with a'));
      expect(
        presentation,
        isNot(contains("?? 'Unnamed")),
        reason: 'an unnamed product must stay unnamed',
      );
      expect(presentation, isNot(contains('|| "Unknown"')));
    });

    test('several items per step are preserved in order', () {
      expect(presentation, contains('products.map((product)'));
      expect(presentation, contains('a Lips step can distinguish the'));
    });

    test('live inventory is never consulted', () {
      expect(presentation, isNot(contains('makeup_kit_products')));
      expect(presentation, contains('immutable snapshot'));
    });
  });

  group('Flutter renders the words, the image never does', () {
    test('presentation travels in the response, not the prompt', () {
      expect(index, contains('products: presentation'));
      expect(
        RegExp(r'products: presentation').allMatches(index).length,
        2,
        reason: 'both the reused and freshly generated paths return it',
      );
      expect(index, contains('never sent to the image model'));
    });

    test('the presentation module never builds prompt text', () {
      expect(presentation, isNot(contains('IMAGE A')));
      expect(presentation, isNot(contains('IMAGE B')));
      expect(presentation, isNot(contains('tutorialGuidelinePrompt')));
    });

    test('the prompt still forbids writing product names into the image', () {
      expect(
        prompt,
        contains('brand names, product names, shade names, colour codes'),
      );
      expect(prompt, contains('do not write it in the image'));
    });
  });

  group('nothing beyond this phase was built', () {
    test('no generate-all, no AI visual QA, no cumulative images', () {
      for (final token in <String>[
        'generateAll',
        'generate_all',
        'visualQa',
        'reviewer',
        'cumulative',
      ]) {
        expect(index.toLowerCase(), isNot(contains(token.toLowerCase())));
      }
    });

    test('the backend carries no UI concerns', () {
      // V4-12 added the tutorial UI, which is expected. What must stay true is
      // that the Edge Function knows nothing about it.
      expect(index, isNot(contains('Widget')));
      expect(index, isNot(contains('flutter')));
    });
  });
}
