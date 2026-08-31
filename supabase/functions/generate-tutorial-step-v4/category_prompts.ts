import type { TutorialCategory } from "../_shared/tutorial_vocabulary.ts";

/// Per-category guideline guidance.
///
/// [landmarks] names the facial structures to mark and what "correct" looks
/// like for that category. [prohibition] names the specific way this category
/// tends to get rendered wrong — every one of them is a way of accidentally
/// applying makeup instead of annotating it, and each is phrased in that
/// category's own vocabulary because a generic "do not apply pigment" has
/// already proven too abstract to bind a model reliably.
///
/// [analysis], [hardRules], [prefer], and [avoid] began as the representative
/// gate's fields, populated for Blush, Eyeshadow, Eyeliner, and Lips only so the
/// other five stayed byte-for-byte identical while the architecture was proven.
/// V4-QA-3 propagated them to all nine, so every category now follows the same
/// shape. They remain optional in the type rather than required: the field is
/// what makes a category reviewed, and a future tenth category should have to
/// earn its guidance rather than inherit an empty list by compulsion.
///
/// [analysis] is the difference between a plausible tutorial and a faithful
/// one. Without it the model is free to answer "where does blush usually go?";
/// with it, it must answer "where did blush go in THIS final preview?" — and
/// the questions are listed explicitly because an instruction to "compare
/// carefully" does not tell a model what to compare.
///
/// [prefer] and [avoid] were added in V4-QA-2B. Device evidence showed the
/// representative guidelines were readable but drifted toward standard makeup
/// diagrams — a generic cat-eye, a template lip outline, a symmetrical cheek
/// rectangle. Naming the *shape of the wrong answer* turns out to bind better
/// than asking once more for the right one, because the failure is not that the
/// model misunderstood the task; it is that a conventional diagram is the more
/// probable image.
///
/// V4-QA-2B still failed device QA on exact target fidelity, and the cause was
/// structural rather than a lack of emphasis. [landmarks] was written as a
/// description of the category in general — "Blush occupies the cheek area",
/// "Eyeliner follows the lash line" — and it is the last category-specific text
/// the model reads before the drawing rules. Each observed failure traced to one
/// sentence in it: Lips listed the natural border first and the target border
/// conditionally, and the guide traced natural anatomy; Eyeliner gave the wing
/// equal weight with four other clauses and an unconditional lower-lash clause,
/// and the wing came out under-specified; Blush said "outline the region" and
/// supplied the convention "commonly upward and outward", and produced a generic
/// container. So in V4-QA-2C the representative four were rewritten from
/// category description into target extraction: what to find in IMAGE B, in what
/// order, and what not to draw when IMAGE B does not show it.
///
/// The set is exhaustive over the vocabulary: a missing entry would be a
/// compile-time gap rather than a silent fallback to generic wording.
export interface CategoryGuidance {
  landmarks: string;
  prohibition: string;
  /// The absolute, category-specific ban on rendering this makeup at all.
  ///
  /// Required for every category, unlike the fields below it. V4-QA-2D found
  /// visible makeup under the guides across multiple steps, so the ban is
  /// global — a category outside the representative gate is exempt from
  /// fidelity work, never from this.
  ///
  /// Phrased as the specific cosmetic effect each category produces, because a
  /// shared "do not apply makeup" has repeatedly proven too abstract: the model
  /// does not seem to classify "a soft glow on the cheekbone" as an instance of
  /// it until the glow itself is named.
  noMakeup: readonly string[];
  /// The explicit visual-difference questions to answer before drawing.
  analysis?: string;
  /// Short, absolute rules for the failure this category actually exhibits.
  hardRules?: readonly string[];
  /// The guide elements that carry teaching value for this category.
  prefer?: readonly string[];
  /// The specific generic diagram this category collapses into when unguided.
  avoid?: readonly string[];
}

export const CATEGORY_GUIDANCE: Record<TutorialCategory, CategoryGuidance> = {
  // ---------------------------------------------------------------------
  // Outside the representative gate. Unchanged, deliberately. Their turn is
  // V4-QA-3, and only after the representative four have passed device QA.
  // ---------------------------------------------------------------------
  foundation: {
    landmarks:
      "Compare the complexion in IMAGE A against IMAGE B and mark only the " +
      "area whose coverage actually changed. Do not outline the whole face by " +
      "default: many looks even out the centre of the face and leave the " +
      "outer cheeks, temples, and jaw close to bare, and marking a full-face " +
      "perimeter would teach the wrong coverage. Mark the outer limit of the " +
      "coverage you can actually see, the boundaries where it must fade out " +
      "rather than stop — commonly the jawline, the hairline, and the ears — " +
      "and the direction it was blended outward. If an area was deliberately " +
      "left uncovered, outline that instead of covering it.",
    analysis:
      "Compare the skin in IMAGE A and IMAGE B, then answer:\n" +
      "- What actually changed: which areas are more even in IMAGE B, and " +
      "which look the same as IMAGE A?\n" +
      "- Extent: is this full-face coverage, or is it concentrated on the " +
      "centre of the face?\n" +
      "- Outer limit: how far out does the coverage reach before the skin " +
      "matches IMAGE A again?\n" +
      "- Fade boundaries: where must it disappear rather than end in a line — " +
      "jaw, hairline, ears, neck?\n" +
      "- Left bare: is any area deliberately uncovered?\n" +
      "- Blend direction: which way was it worked outward?\n" +
      "If the two complexions look essentially the same and you cannot tell " +
      "coverage from lighting, mark the smallest area you are confident about " +
      "rather than outlining the face.",
    prohibition:
      "Do not tint, even out, smooth, or re-tone any skin. The skin beneath " +
      "your markings must keep every freckle, mole, pore, and unevenness " +
      "visible in IMAGE A.",
    noMakeup: [
      "DO NOT ADD VISIBLE FOUNDATION.",
      "DO NOT EVEN OUT THE SKIN TONE.",
      "DO NOT SMOOTH SKIN OR BLUR TEXTURE.",
      "DO NOT REMOVE IMPERFECTIONS.",
      "DO NOT ADD COSMETIC COVERAGE OF ANY KIND.",
      "Show only coverage boundaries, fade limits, and blend directions.",
    ],
    hardRules: [
      "DO NOT OUTLINE THE WHOLE FACE UNLESS IMAGE B SHOWS COVERAGE ACROSS ALL OF IT.",
      "MARK THE COVERAGE THAT CHANGED, NOT THE AREA A SPONGE COULD REACH.",
    ],
    prefer: [
      "the outer limit of the visible coverage",
      "fade boundaries where coverage must disappear rather than stop",
      "one or two outward blend directions",
    ],
    avoid: [
      "a full-face perimeter drawn by default",
      "an outline that follows the edge of the face rather than the edge of the coverage",
      "a mark on every feature of the face because foundation is broad",
    ],
  },
  concealer: {
    landmarks:
      "Compare IMAGE A and IMAGE B and mark only the discrete areas that were " +
      "visibly brightened or evened. Concealer is targeted, so the guide " +
      "should usually be one or two small zones, not a standing set. Do not " +
      "draw an under-eye triangle because that is where concealer normally " +
      "goes — draw it only where IMAGE B is actually brighter than IMAGE A. " +
      "For each zone you can genuinely see, mark its boundary, where it must " +
      "fade into the surrounding skin, and the blending direction outward " +
      "from it.",
    analysis:
      "Compare IMAGE A and IMAGE B, then answer:\n" +
      "- Under-eye: is it actually brighter in IMAGE B, and if so over what " +
      "shape and how far down the cheek?\n" +
      "- Specific spots: is any individual blemish, redness, or shadow evened " +
      "out?\n" +
      "- Around the nose or the inner corner: is anything corrected there?\n" +
      "- Boundary of each zone: where exactly does each corrected area end?\n" +
      "- Fade: where must each zone disappear into untouched skin?\n" +
      "- Blend direction: which way outward from each zone?\n" +
      "Mark only the zones you can see. If foundation alone explains the " +
      "difference, there is nothing here to mark, and marking a default zone " +
      "would teach a correction that was never made.",
    prohibition:
      "Do not brighten, lighten, or smooth the under-eye area or any blemish. " +
      "Every mark you draw must be an outline or an arrow, never a lightened " +
      "patch.",
    noMakeup: [
      "DO NOT BRIGHTEN UNDER-EYES.",
      "DO NOT CONCEAL BLEMISHES.",
      "DO NOT REMOVE DISCOLORATION.",
      "DO NOT CHANGE SKIN TONE OR CREATE CORRECTED SKIN.",
      "Show only placement, boundaries, anchors, and blend directions.",
    ],
    hardRules: [
      "DO NOT DRAW AN UNDER-EYE TRIANGLE UNLESS IMAGE B IS VISIBLY BRIGHTER THERE.",
      "MARK ONLY ZONES THAT CHANGED. IF NONE DID, MARK ALMOST NOTHING.",
    ],
    prefer: [
      "one or two zone boundaries, only where a correction is visible",
      "a fade edge for each zone",
      "an outward blend direction per zone",
    ],
    avoid: [
      "the standard under-eye triangle drawn from habit",
      "matching symmetrical zones under both eyes when only one area changed",
      "a set of default concealer spots around the nose, chin, and forehead",
    ],
  },
  contour_bronzer: {
    landmarks:
      "Compare IMAGE A and IMAGE B and mark only the regions that were " +
      "actually deepened. Contour has a standard map — cheekbone, temple, " +
      "jawline, nose — and drawing all four because they are the usual set is " +
      "the main way this category goes wrong. Take each one separately and " +
      "mark it only if you can genuinely see added depth there in IMAGE B. " +
      "Many looks contour the cheekbone alone. For each band you do mark, " +
      "show its upper and lower boundary and the direction it was blended so " +
      "it has no hard edge.",
    analysis:
      "Compare IMAGE A and IMAGE B, then answer each separately:\n" +
      "- Cheekbone: is the hollow beneath it deeper in IMAGE B? Where does " +
      "the band start and stop along the face?\n" +
      "- Temple: is there added depth at the temple or along the hairline?\n" +
      "- Jawline: was the jaw or the area beneath it deepened?\n" +
      "- Nose: are the sides of the nose deepened? Mark this only if it is " +
      "genuinely visible, which is uncommon.\n" +
      "- For each band you can see: what is its upper boundary, its lower " +
      "boundary, and its angle across the face?\n" +
      "- Blend direction: which way must each band soften?\n" +
      "Mark only the bands you answered yes to. A look that deepened the " +
      "cheekbone alone gets one band, not four.",
    prohibition:
      "Do not add any brown, bronze, tan, or shadow tone to the face. Do not " +
      "darken, slim, or sculpt the face. Mark a region that is unclear in the " +
      "FINAL image only if you can see it; otherwise leave it unmarked.",
    noMakeup: [
      "DO NOT ADD BROWN SHADING.",
      "DO NOT ADD WARMTH OR BRONZE THE SKIN.",
      "DO NOT SCULPT THE FACE.",
      "DO NOT VISUALLY NARROW OR RESHAPE ANY FEATURE.",
      "Show only placement paths, boundaries, fade regions, and blend directions.",
    ],
    hardRules: [
      "DO NOT DRAW THE STANDARD CONTOUR MAP. MARK ONLY BANDS YOU CAN SEE.",
      "DO NOT MARK THE NOSE UNLESS IMAGE B VISIBLY SHOWS DEPTH THERE.",
    ],
    prefer: [
      "one band per region that genuinely changed",
      "an upper and lower boundary for each band",
      "one blend direction per band",
    ],
    avoid: [
      "the standard three-shape contour map drawn as a set",
      "cheekbone, temple, jaw, and nose all marked because they are conventional",
      "a band drawn along a natural shadow that is present in IMAGE A too",
    ],
  },

  // ---------------------------------------------------------------------
  // Representative gate. Refined in V4-QA-2B from device evidence.
  // ---------------------------------------------------------------------
  blush: {
    landmarks:
      "Find the blush in IMAGE B by comparing it against IMAGE A, then mark " +
      "the footprint it actually occupies. Do not outline a cheek; mark the " +
      "bounds of the colour you can see. Those bounds are usually smaller, " +
      "higher, and further out than a conventional cheek shape, so the marked " +
      "area must be the one the four bounds enclose and no larger. Mark where " +
      "the colour is strongest, and the direction it fades. If IMAGE B shows " +
      "little or no colour low on the cheek or close to the nose, the marking " +
      "must not reach there.\n" +
      "Mark the FOOTPRINT, not the ROUTE. The footprint is the area where " +
      "colour is actually visible in IMAGE B. The route is everywhere a brush " +
      "could plausibly travel while applying it — down through the mid cheek, " +
      "around the apple, out along the jaw. The route is not the target and " +
      "must not be drawn. If the visible blush is high and subtle, the guide " +
      "is high and small, even though a brush could have reached much further.",
    analysis:
      "Compare the cheeks in IMAGE A and IMAGE B, then answer:\n" +
      "- Highest visible point: where does the colour stop at the top?\n" +
      "- Lowest visible point: where does it stop at the bottom? This is the " +
      "bound most often drawn too low.\n" +
      "- Innermost point: how close to the nose does any colour actually " +
      "reach?\n" +
      "- Outermost point: how far toward the temple, ear, or hairline?\n" +
      "- Strongest concentration: where is it most saturated? That is where " +
      "the product was set down first.\n" +
      "- Fade direction: which way does it soften?\n" +
      "- Lift: is the colour carried up toward the temple, or does it sit " +
      "level across the cheek?\n" +
      "- Centre cheek: is the centre strong, soft, or untouched?\n" +
      "- Softest fade boundary: where does the colour become invisible?\n" +
      "Those four bounds define the footprint. Mark the footprint, not a " +
      "cheek-shaped container drawn around it, and not the path a brush might " +
      "take to produce it. Do not assume apple-of-cheek, lifted, temple-swept, " +
      "horizontal, or nose placement — mark whichever IMAGE B actually shows, " +
      "and nothing else.\n" +
      "The analysis above is detailed; the drawing must not be. One boundary " +
      "around the footprint, one anchor at the strongest point if it helps, " +
      "and at most one or two fade arrows is the whole guide. Do not add a " +
      "mark per question answered.",
    prohibition:
      "Do not add any pink, peach, coral, or red flush to the cheeks. The " +
      "cheeks beneath your markings must stay exactly the colour they are in " +
      "IMAGE A.",
    noMakeup: [
      "DO NOT TINT THE CHEEKS.",
      "DO NOT ADD PINK, ROSE, OR PEACH PIGMENT.",
      "DO NOT CREATE A FLUSHED EFFECT.",
      "DO NOT SIMULATE APPLIED BLUSH.",
      "Show only the target footprint, anchors, fade boundary, and blend direction.",
    ],
    hardRules: [
      "DO NOT ADD PINK PIGMENT.",
      "DO NOT ADD ROSE PIGMENT.",
      "DO NOT TINT THE CHEEK.",
      "DO NOT SIMULATE APPLIED BLUSH.",
      "DO NOT BEAUTIFY THE SKIN.",
    ],
    prefer: [
      "a boundary enclosing the visible footprint and nothing more",
      "an anchor where the colour is strongest",
      "one fade direction, where blending genuinely moves",
    ],
    avoid: [
      "an oversized generic rectangle or oval covering most of the cheek",
      "a broad default blush container drawn around the colour rather than on it",
      "a footprint lower or wider than the colour visible in IMAGE B",
      "a long U-shaped or sweeping path through the mid and lower cheek — that is a blending route, not the target",
      "full mid-cheek coverage, or a generic apple-of-cheek zone, unless IMAGE B genuinely shows colour throughout it",
      "decorative hatching that answers no application question",
      "an identical mirrored shape on both cheeks drawn merely because there are two cheeks",
    ],
  },
  highlighter: {
    landmarks:
      "Compare IMAGE A and IMAGE B and outline only the small areas that " +
      "visibly gained brightness. There is a classic five-point highlight map " +
      "— tops of the cheekbones, brow bone, inner corner of the eye, bridge " +
      "of the nose, Cupid's bow — and marking all five because they are the " +
      "conventional set is the main way this category goes wrong. Check each " +
      "point separately and mark it only where IMAGE B is genuinely brighter " +
      "than IMAGE A. Keep every outline tight: highlighter sits in narrow " +
      "traces, so a broad region is already the wrong shape.",
    analysis:
      "Compare IMAGE A and IMAGE B, then answer each point separately:\n" +
      "- Cheekbone tops: brighter in IMAGE B? Over how narrow a strip, and " +
      "how far along the bone?\n" +
      "- Brow bone: is there added light beneath the arch?\n" +
      "- Inner corner of the eye: anything placed there?\n" +
      "- Bridge of the nose: brighter, and along what length?\n" +
      "- Cupid's bow: is the peak of the lip brightened?\n" +
      "- For each yes: how narrow is the trace, and where exactly does it " +
      "begin and end?\n" +
      "Mark only the points you answered yes to. Distinguish added highlighter " +
      "from light that is already on the face in IMAGE A — a nose or cheekbone " +
      "catching the light in both images is not highlighter.",
    prohibition:
      "Do not add shimmer, glow, sheen, sparkle, or any brightening to the " +
      "skin. Draw the boundary of where the light sits; never draw the light " +
      "itself.",
    noMakeup: [
      "DO NOT ADD GLOW.",
      "DO NOT BRIGHTEN HIGH POINTS.",
      "DO NOT ADD SHIMMER, SHINE, OR ANY REFLECTIVE COSMETIC APPEARANCE.",
      "Show only placement boundaries or reference marks.",
    ],
    hardRules: [
      "DO NOT DRAW THE CLASSIC FIVE-POINT HIGHLIGHT MAP. MARK ONLY POINTS YOU CAN SEE.",
      "EXISTING LIGHT ON THE FACE IN IMAGE A IS NOT HIGHLIGHTER.",
    ],
    prefer: [
      "a tight outline per point that genuinely brightened",
      "a start and end where a trace runs along a bone",
    ],
    avoid: [
      "the classic five-point map marked as a set",
      "broad regions where highlighter sits as a narrow trace",
      "a point marked because the face catches light there in both images",
    ],
  },
  eyebrows: {
    landmarks:
      "Compare the brows in IMAGE A and IMAGE B and mark only what changed. " +
      "Brows are the category most prone to construction geometry — the " +
      "three-line mapping, cross-hairs from the nose, a full outline around " +
      "the whole brow — and none of that teaches anything unless the shape " +
      "actually moved. Mark the start at the inner end, the arch at its " +
      "highest point, or the tail where the brow ends only where those differ " +
      "from IMAGE A, plus the direction the hairs were groomed or drawn where " +
      "that is what changed. If only the tail was extended, mark the tail.",
    analysis:
      "Compare the brows in IMAGE A and IMAGE B, then answer:\n" +
      "- Did the shape change at all, or only the density and definition?\n" +
      "- Start: does the inner end begin in a different place?\n" +
      "- Arch: is the highest point higher, or moved along the brow?\n" +
      "- Tail: is it longer, shorter, or angled differently?\n" +
      "- Fullness: is any area filled in IMAGE B that is sparse in IMAGE A? " +
      "Where exactly?\n" +
      "- Stroke direction: which way were the hairs drawn or groomed?\n" +
      "- Which parts are identical in both images?\n" +
      "Mark only what changed. If the brows are merely tidier and the shape is " +
      "the same, a stroke direction and nothing else may be the whole guide.",
    prohibition:
      "Do not fill, darken, thicken, or redraw the eyebrows themselves. The " +
      "brows beneath your markings must remain exactly as they are in IMAGE A.",
    noMakeup: [
      "DO NOT FILL BROWS.",
      "DO NOT DARKEN OR RECOLOR BROW HAIRS.",
      "DO NOT THICKEN BROWS.",
      "DO NOT APPLY BROW PRODUCT.",
      "Show only anchors, the target boundary, arch and tail references, and stroke-direction guides.",
    ],
    hardRules: [
      "DO NOT DRAW BROW CONSTRUCTION GEOMETRY — NO MAPPING LINES FROM THE NOSE, NO CROSS-HAIRS.",
      "MARK ONLY THE PART OF THE BROW THAT CHANGED.",
    ],
    prefer: [
      "an anchor at whichever of start, arch, or tail actually moved",
      "a target boundary only where the shape was extended",
      "one stroke direction where grooming is what changed",
    ],
    avoid: [
      "the three-line brow mapping, or any line projected from the nose or eye",
      "a full outline around a brow whose shape did not change",
      "start, arch, and tail all marked when only one of them moved",
    ],
  },
  eyeshadow: {
    landmarks:
      "Compare the eye area in IMAGE A against IMAGE B and mark the zones that " +
      "actually changed. Separate two different things: where eyeshadow exists " +
      "at all, and where it is most intense. Mark the mobile lid boundary, the " +
      "crease or transition boundary if one is visible, the outer V if the " +
      "outer corner was deepened, and the inner corner only if something was " +
      "placed there. Where IMAGE B is lighter across the inner and mid lid and " +
      "clearly heavier at the outer corner, that weighting is the most " +
      "important thing to communicate — one even zone would misrepresent it. " +
      "Mark only the zones you can see were used: a look that used the lid " +
      "alone must be marked on the lid alone.",
    analysis:
      "Answer these about the eye area before drawing anything:\n" +
      "- Lid zone: was the mobile lid covered, and how far up does the " +
      "coverage reach?\n" +
      "- Crease: was the crease defined at all? If not, do not draw a crease " +
      "line.\n" +
      "- Crease height: if it was, does the colour sit in the natural crease, " +
      "or above it? How far above?\n" +
      "- Outer corner / outer V: was the outer corner deepened, and how far " +
      "inward and upward does it extend?\n" +
      "- Inner corner: was anything placed at the inner corner? Mark it only " +
      "if you can see it.\n" +
      "- Upper transition: where does the colour stop and the bare brow bone " +
      "begin?\n" +
      "- Lower lash line: was anything applied beneath the lower lashes? Mark " +
      "it only if visible.\n" +
      "- Blend direction: which way does each zone soften into the next?\n" +
      "- Softest edge: where does the colour fade out entirely?\n" +
      "- Intensity structure: which area is darkest, and which is lightest? " +
      "If the outer corner is clearly heavier than the inner and mid lid, that " +
      "weighting is the single most important thing your marking must " +
      "communicate. Show it through where the boundaries sit and where the " +
      "anchor goes, never by shading anything.\n" +
      "- Bilateral relationship: both eyes should be marked coherently. Mark " +
      "them differently only where the FINAL image genuinely differs — do not " +
      "force identical geometry onto a naturally asymmetric face, and do not " +
      "invent an asymmetry that is not there.\n" +
      "Do not produce a standard eyeshadow diagram. Mark the zones this look " +
      "actually used.",
    prohibition:
      "Do not add any eyeshadow colour, depth, or shading to the lids. Draw " +
      "zone boundaries and blending arrows only.",
    noMakeup: [
      "DO NOT APPLY EYESHADOW PIGMENT.",
      "DO NOT DARKEN OR RECOLOR THE EYELIDS.",
      "DO NOT TINT THE CREASE.",
      "DO NOT ADD SHIMMER, GLITTER, OR SMOKY SHADING.",
      "Show only lid, crease, transition, outer-corner, and blend-direction guides.",
    ],
    hardRules: [
      "DO NOT APPLY EYESHADOW PIGMENT.",
      "DO NOT DARKEN THE EYELID.",
      "DO NOT RECOLOR THE EYELID.",
      "DO NOT TINT THE CREASE.",
      "DO NOT ADD SHIMMER.",
      "DO NOT ADD GLITTER.",
      "DO NOT ADD SMOKY SHADING.",
      "DO NOT PARTIALLY RECREATE THE FINISHED EYE MAKEUP.",
    ],
    prefer: [
      "a lid boundary",
      "a crease or transition boundary, only where one is visible",
      "an outer-corner boundary when the outer corner was deepened",
      "one mark distinguishing the most intense area from the rest",
      "a small number of blend directions",
    ],
    avoid: [
      "filled or shaded colour zones of any kind",
      "a darkened eyelid",
      "a generic semicircular eye template",
      "one even zone when IMAGE B is clearly weighted toward the outer corner",
      "lower-eye guides when the lower lash line was untouched",
      "an arrow for every boundary",
    ],
  },
  eyeliner: {
    landmarks:
      "Compare the eyes in IMAGE A and IMAGE B and reconstruct the liner that " +
      "was actually drawn, in this order of importance: first the upper " +
      "lash-line path and where it begins; then the wing — its origin, its " +
      "angle, and the curvature of its upper edge; then the wing endpoint; " +
      "then the thickness and how it changes along the line. Only after all of " +
      "those, consider the lower lash line, and mark it ONLY if IMAGE B " +
      "visibly changed it. The wing is the dominant target feature: its " +
      "direction, length, and endpoint must match what IMAGE B shows rather " +
      "than any conventional cat-eye proportion. If IMAGE B shows no wing, do " +
      "not draw one.",
    analysis:
      "Compare the eyes in IMAGE A and IMAGE B, in this priority order:\n" +
      "1. Upper lash-line path: at which point does the liner begin — the " +
      "inner corner, or partway out — and what path does it follow?\n" +
      "2. Wing origin: at what point does the line lift away from the lash " +
      "line?\n" +
      "3. Wing angle: what direction does it travel — toward the tail of the " +
      "brow, flatter, or steeper? Does it rise, run level, or drop?\n" +
      "4. Wing curvature: is its upper edge straight, or does it curve?\n" +
      "5. Wing length: how far does it extend past the eye?\n" +
      "6. Wing endpoint: where exactly does it stop? A short subtle flick and " +
      "a long dramatic wing are different instructions; mark the one you see.\n" +
      "7. Thickness: how thick at its thickest, and does it stay even, taper " +
      "inward, or thicken toward the outer corner?\n" +
      "8. Inner line: is the inner third lined at all?\n" +
      "9. Lower lash line: did IMAGE B change it at all?\n" +
      "- Bilateral relationship: mark both eyes coherently, following the " +
      "head angle in IMAGE A rather than forcing mirrored geometry.\n" +
      "The wing is the dominant target feature; if the guide gets only one " +
      "thing right, it must be the wing. If there is no wing in IMAGE B, do " +
      "not draw one. If the lower lash line is unchanged, draw nothing below " +
      "the eye — do not give lower-eye geometry equal weight merely because " +
      "eyeliner can be worn there.",
    prohibition:
      "Do not draw black or coloured liner on the lash line. Your marking must " +
      "sit beside or above the lash line as an annotation, clearly " +
      "distinguishable from liner itself, and must never look like makeup.",
    noMakeup: [
      "DO NOT APPLY EYELINER.",
      "DO NOT DARKEN THE LASH LINE.",
      "DO NOT FILL A WING.",
      "DO NOT ADD BLACK COSMETIC PIGMENT.",
      "DO NOT RECREATE THE FINAL EYELINER APPEARANCE.",
      "Show only the target path, wing direction, endpoint, and boundary guides.",
    ],
    hardRules: [
      "DO NOT APPLY BLACK EYELINER.",
      "DO NOT DARKEN THE LASH LINE.",
      "DO NOT FILL THE WING.",
      "DO NOT ADD EYE MAKEUP PIGMENT.",
      "DRAW ONLY THE INSTRUCTIONAL PATH / BOUNDARY / DIRECTION GUIDE.",
    ],
    prefer: [
      "a clean target path along the upper lash line",
      "a clear wing path where a wing exists",
      "a marked endpoint where the wing actually stops",
      "one direction indicator, only if it adds something the path does not",
    ],
    avoid: [
      "a decorative closed oval around the whole eye, unless IMAGE B truly shows liner all the way around",
      "a generic symmetrical cat-eye",
      "a wing longer, sharper, higher, lower, or more curved than the one in IMAGE B",
      "an arrow running off toward the temple with no endpoint",
      "any lower-eye guidance when IMAGE B shows no lower-liner change",
    ],
  },
  lips: {
    landmarks:
      "The target is the lip shape in IMAGE B, not the lip anatomy in IMAGE A. " +
      "The mark that matters is the target border — the outline the user has " +
      "to produce. Use the natural border from IMAGE A only where it differs " +
      "from the target, so the difference itself is visible; where the two " +
      "coincide, one line is enough and a second would teach nothing. Mark the " +
      "Cupid's bow only where its definition changed, each corner where the " +
      "target ends somewhere the natural lip does not, and the lower lip " +
      "boundary where fullness changed. If the target border sits outside the " +
      "natural one, show where and by how much; if it sits inside, show that " +
      "instead. Do not simply trace the lips that are already there.",
    analysis:
      "Answer these about the lips before drawing anything:\n" +
      "- Natural border: where does the lip edge sit in IMAGE A?\n" +
      "- Target border: where does it sit in the FINAL image? If the two are " +
      "the same, mark one border, not two.\n" +
      "- Cupid's bow: was its peak sharpened, softened, raised, or left " +
      "alone?\n" +
      "- Upper-lip peaks: are the two peaks level, and did their height " +
      "change?\n" +
      "- Centre dip: is the dip between the peaks deeper, shallower, or " +
      "unchanged?\n" +
      "- Corners: were the corners kept, or redrawn?\n" +
      "- Corner extension: does the colour run out past the natural corner, " +
      "and how far?\n" +
      "- Lower lip: did the lower boundary change in fullness or shape?\n" +
      "- Overline: mark an overline only where the FINAL border genuinely " +
      "sits outside the natural one. Do not add an overline because a fuller " +
      "lip would look better.\n" +
      "- Underline: if the border was brought inside the natural lip, mark " +
      "that instead.\n" +
      "- Fullness: is the overall shape fuller, flatter, or unchanged?\n" +
      "- Which parts of the border in IMAGE B extend beyond IMAGE A, and by " +
      "how much? Which parts are identical?\n" +
      "Then ask the question the guide has to answer: where would the user " +
      "need to draw outside, inside, or along the natural lip boundary to " +
      "reproduce IMAGE B? That answer is the guide. Do not output a generic " +
      "lip-outline diagram, and do not settle for tracing the natural lips.",
    prohibition:
      "Do not fill, tint, gloss, or colour the lips. The lips beneath your " +
      "markings must stay exactly the colour they are in IMAGE A.",
    noMakeup: [
      "DO NOT ADD LIPSTICK OR LIP GLOSS.",
      "DO NOT TINT THE LIPS.",
      "DO NOT INCREASE LIP SATURATION OR SHINE.",
      "DO NOT SMOOTH THE LIPS.",
      "DO NOT MAKE THE LIPS APPEAR FULLER THROUGH COSMETIC RENDERING — only the guide may show the target shape.",
      "Show only the target border, anchors, corners, Cupid's bow, and necessary direction guides.",
    ],
    hardRules: [
      "DO NOT APPLY LIPSTICK.",
      "DO NOT APPLY LIP GLOSS.",
      "DO NOT ADD LIP TINT.",
      "DO NOT RECOLOR THE LIPS.",
      "DO NOT CHANGE LIP TEXTURE.",
      "DO NOT ENLARGE OR RESHAPE THE PHYSICAL LIPS.",
      "ONLY ADD THE INSTRUCTIONAL TARGET BORDER / ANCHORS / DIRECTIONS.",
    ],
    prefer: [
      "the target border, as the primary and most prominent mark",
      "Cupid's bow anchor points where the definition actually changed",
      "corner endpoints where the target ends somewhere the natural lip does not",
      "a fill or blend direction only where the border alone is not enough",
    ],
    avoid: [
      "a generic diamond or textbook lip diagram",
      "a trace of the natural lip outline when the target border differs from it",
      "an arrow for every segment of the border",
      "an overline the FINAL image does not show, or a widened mouth",
      "any gloss, sheen, or pigment simulation",
    ],
  },
};

export function categoryGuidance(
  category: TutorialCategory,
): CategoryGuidance | null {
  return CATEGORY_GUIDANCE[category] ?? null;
}

/// The categories covered by the representative quality gate.
///
/// Exported so a test can prove the gate's scope from the data rather than
/// from a list written twice, and so V4-QA-3 has an explicit boundary to move.
export const REPRESENTATIVE_CATEGORIES: readonly TutorialCategory[] = [
  "blush",
  "eyeshadow",
  "eyeliner",
  "lips",
];
