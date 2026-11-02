/**
 * CCP-10 — the accepted CCP-9 case plan, as data.
 *
 * Nothing here runs anything. `ccp10_harness_test.ts` proves this file against the
 * accepted plan's counts and call ceilings, against the server contract, and
 * against the shared color vectors.
 */

export const STAGE_1_CEILING = 54;
export const TOTAL_CEILING = 420;

export const LIVE_AUTHORIZATION = {
  1: "CCP-10-STAGE-1:8-cases:54-calls",
  2: "CCP-10-STAGE-2:79-cases:420-calls",
} as const;

export type Stage = 1 | 2;
export type SelfieSlot = "S1" | "S2" | "S3";
export type AccountId = "S1a" | "S1b" | "S2a" | "S2b" | "S3a" | "S3b";

export const ACCOUNTS: readonly AccountId[] = [
  "S1a",
  "S1b",
  "S2a",
  "S2b",
  "S3a",
  "S3b",
];
export const STAGE_1_ACCOUNTS: readonly AccountId[] = ["S1a", "S2a", "S3a"];

export function selfieOf(account: AccountId): SelfieSlot {
  return account.slice(0, 2) as SelfieSlot;
}

export const STYLES = [
  "natural",
  "everyday",
  "office",
  "soft_glam",
  "full_glam",
  "bridal",
  "korean",
  "clean_girl",
  "party",
  "date_night",
  "no_makeup_makeup",
  "old_money",
] as const;

export const BASE: Readonly<Record<string, string>> = {
  Red: "#C8102E",
  Teal: "#0F8B8D",
  Violet: "#6A2FB5",
  Gold: "#C9A227",
  Blue: "#1F6FD6",
  Pink: "#E75480",
  Orange: "#E8711A",
  Green: "#2E7D4F",
  White: "#F5F2EC",
  Bronze: "#8A5A34",
  Navy: "#1F2F6B",
  Berry: "#7A2E4A",
  Nude: "#D9A58B",
  Peach: "#F2A07B",
  Taupe: "#9C8574",
  Brown: "#5C3A21",
};

export type Category = "blush" | "eyeshadow" | "eyeliner" | "lipstick";

export interface Choice {
  category: Category;
  finish: string;
  label: string;
  base: string;
  adjusted: string;
}

function choice(
  category: Category,
  finish: string,
  label: string,
  adjusted?: string,
): Choice {
  const base = BASE[label];
  if (!base) throw new Error(`Unknown swatch ${label}`);
  return { category, finish, label, base, adjusted: adjusted ?? base };
}

export interface LookCase {
  kind: "look";
  id: string;
  block: "A" | "B" | "C" | "D" | "E" | "H";
  stage: Stage;
  style: string;
  account: AccountId;
  choices: Choice[];
  /** H only: the palette this edit derives from. */
  derivedFrom?: string;
}

export interface VariationCase {
  kind: "variation";
  id: string;
  block: "F";
  stage: 2;
  parent: string;
}

export interface TutorialCase {
  kind: "tutorial";
  id: string;
  block: "G";
  stage: 2;
  parent: string;
}

export interface ProbeCase {
  kind: "probe";
  id: string;
  block: "N";
  stage: 2;
  category: Category;
  probe: "hue" | "dark" | "absent";
}

export type EvalCase = LookCase | VariationCase | TutorialCase | ProbeCase;

const CATEGORY_ORDER: readonly Category[] = [
  "lipstick",
  "blush",
  "eyeshadow",
  "eyeliner",
];
export const A_COLORS = ["Red", "Teal", "Violet", "Gold"] as const;

type Draft = Omit<LookCase, "kind" | "stage" | "style" | "account">;

function blockA(): Draft[] {
  return CATEGORY_ORDER.flatMap((category) =>
    A_COLORS.map((label) => ({
      id: `A-${category}-${label}`,
      block: "A" as const,
      choices: [choice(category, "matte", label)],
    }))
  );
}

function blockB(): Draft[] {
  const single = (
    id: string,
    category: Category,
    label: string,
    adjusted: string,
  ): Draft => ({
    id: `B-${id}`,
    block: "B",
    choices: [choice(category, "matte", label, adjusted)],
  });
  return [
    single("lipstick-light", "lipstick", "Red", "#F5D6DB"),
    single("lipstick-dark", "lipstick", "Red", "#290A0F"),
    single("lipstick-high_saturation", "lipstick", "Red", "#FF002A"),
    single("lipstick-low_saturation", "lipstick", "Red", "#86797B"),
    single("eyeshadow-light", "eyeshadow", "Blue", "#D6E4F5"),
    single("eyeshadow-dark", "eyeshadow", "Blue", "#0A1829"),
    single("eyeshadow-high_saturation", "eyeshadow", "Blue", "#006FFF"),
    single("eyeshadow-low_saturation", "eyeshadow", "Blue", "#797F86"),
    single("blush-light", "blush", "Pink", "#F5D6DF"),
    single("blush-low_saturation", "blush", "Pink", "#86797D"),
    single("eyeliner-dark", "eyeliner", "Violet", "#180A29"),
    single("eyeliner-high_saturation", "eyeliner", "Violet", "#7000FF"),
  ];
}

function blockC(): Draft[] {
  const rows: Array<[Category, string, string[]]> = [
    ["blush", "Pink", ["satin", "shimmer"]],
    ["eyeshadow", "Bronze", ["satin", "shimmer", "metallic", "glitter"]],
    ["eyeliner", "Navy", ["satin", "glossy"]],
    ["lipstick", "Berry", ["satin", "cream", "glossy"]],
  ];
  return rows.flatMap(([category, label, finishes]) =>
    finishes.map((finish) => ({
      id: `C-${category}-${finish}`,
      block: "C" as const,
      choices: [choice(category, finish, label)],
    }))
  );
}

const D1_CHOICES = [
  choice("lipstick", "matte", "Red"),
  choice("blush", "satin", "Orange"),
  choice("eyeliner", "matte", "Violet"),
  choice("eyeshadow", "metallic", "Gold"),
];

function blockD(): Draft[] {
  const multi = (id: string, choices: Choice[]): Draft => ({
    id,
    block: "D",
    choices,
  });
  return [
    multi("D1", D1_CHOICES),
    multi("D2", [
      choice("lipstick", "matte", "Teal"),
      choice("blush", "satin", "Pink"),
    ]),
    multi("D3", [
      choice("eyeshadow", "shimmer", "Green"),
      choice("eyeliner", "satin", "Green"),
    ]),
    multi("D4", [
      choice("lipstick", "glossy", "Blue"),
      choice("eyeshadow", "matte", "Orange"),
      choice("eyeliner", "matte", "White"),
    ]),
    multi("D5", [
      choice("lipstick", "matte", "Red", "#F5D6DB"),
      choice("blush", "matte", "Orange", "#F5E3D6"),
      choice("eyeshadow", "matte", "Violet", "#E4D6F5"),
      choice("eyeliner", "matte", "Teal", "#D6F4F5"),
    ]),
    multi("D6", [
      choice("lipstick", "matte", "Red", "#290A0F"),
      choice("blush", "matte", "Orange", "#29170A"),
      choice("eyeshadow", "matte", "Teal", "#0A2829"),
      choice("eyeliner", "matte", "Violet", "#180A29"),
    ]),
    multi("D7", [
      choice("lipstick", "satin", "Nude"),
      choice("blush", "satin", "Peach"),
      choice("eyeshadow", "matte", "Taupe"),
      choice("eyeliner", "matte", "Brown"),
    ]),
    multi("D8", [
      choice("lipstick", "matte", "Red", "#FF002A"),
      choice("blush", "satin", "Orange", "#FF6C00"),
      choice("eyeshadow", "glitter", "Gold", "#FFC200"),
      choice("eyeliner", "glossy", "Violet", "#7000FF"),
    ]),
  ];
}

/** The Stage 1 cases, fixed to the three Stage 1 accounts. */
const STAGE_1: Readonly<Record<string, AccountId>> = {
  "A-lipstick-Red": "S1a",
  "A-lipstick-Teal": "S2a",
  "A-eyeliner-Violet": "S3a",
  "A-blush-Gold": "S1a",
  "B-lipstick-dark": "S2a",
  "C-eyeshadow-glitter": "S3a",
  "D1": "S1a",
  "D6": "S2a",
};
/**
 * S1a is left out: it already carries D1's whole style block and its derivatives.
 * The preview quota is 30 attempts per hour per user, and every look can use two.
 */
const ROTATION: readonly AccountId[] = ["S1b", "S2b", "S3b", "S2a", "S3a"];

function buildLooks(): LookCase[] {
  let rotation = 0;
  const looks = [...blockA(), ...blockB(), ...blockC(), ...blockD()].map(
    (draft, index): LookCase => {
      const fixed = STAGE_1[draft.id];
      return {
        kind: "look",
        ...draft,
        stage: fixed ? 1 : 2,
        style: STYLES[index % STYLES.length],
        account: fixed ?? ROTATION[rotation++ % ROTATION.length],
      };
    },
  );
  const styleBlock = [
    "natural",
    "no_makeup_makeup",
    "office",
    "clean_girl",
    "old_money",
    "full_glam",
  ].map((style): LookCase => ({
    kind: "look",
    id: `E-${style}`,
    block: "E",
    stage: 2,
    style,
    account: "S1a",
    choices: D1_CHOICES,
  }));
  const parent = (id: string) => looks.find((look) => look.id === id)!;
  const edits: LookCase[] = [
    {
      kind: "look",
      id: "H1",
      block: "H",
      stage: 2,
      style: parent("D1").style,
      account: parent("D1").account,
      derivedFrom: "D1",
      choices: D1_CHOICES.map((c) =>
        c.category === "blush" ? choice("blush", c.finish, "Violet") : c
      ),
    },
    {
      kind: "look",
      id: "H2",
      block: "H",
      stage: 2,
      style: parent("A-lipstick-Red").style,
      account: parent("A-lipstick-Red").account,
      derivedFrom: "A-lipstick-Red",
      choices: [choice("lipstick", "glossy", "Red")],
    },
  ];
  return [...looks, ...styleBlock, ...edits];
}

export const LOOKS: readonly LookCase[] = buildLooks();

export const VARIATIONS: readonly VariationCase[] = [
  "D1",
  "D2",
  "A-lipstick-Teal",
  "A-eyeliner-Gold",
  "B-eyeshadow-light",
  "C-eyeshadow-glitter",
].map((parent) => ({
  kind: "variation",
  id: `F-${parent}`,
  block: "F",
  stage: 2,
  parent,
}));

export const TUTORIALS: readonly TutorialCase[] = [
  "D1",
  "D6",
  "D4",
  "D2",
  "A-eyeliner-Violet",
  "B-blush-low_saturation",
].map((parent) => ({
  kind: "tutorial",
  id: `G-${parent}`,
  block: "G",
  stage: 2,
  parent,
}));

export const PROBES: readonly ProbeCase[] = CATEGORY_ORDER.flatMap((category) =>
  (["hue", "dark", "absent"] as const).map((probe) => ({
    kind: "probe" as const,
    id: `N-${category}-${probe}`,
    block: "N" as const,
    stage: 2 as const,
    category,
    probe,
  }))
);

export const ALL_CASES: readonly EvalCase[] = [
  ...LOOKS,
  ...VARIATIONS,
  ...TUTORIALS,
  ...PROBES,
];

/** Cases deliberately sent twice with one operation id, to prove replay. */
export const REPLAY_CASES: readonly string[] = [
  "A-lipstick-Red",
  "D1",
  "C-eyeshadow-glitter",
];

export function lookById(id: string): LookCase {
  const look = LOOKS.find((entry) => entry.id === id);
  if (!look) throw new Error(`Unknown look ${id}`);
  return look;
}

export function accountOfVariation(variation: VariationCase): AccountId {
  return lookById(variation.parent).account;
}

const HUE_PARTNER: Readonly<Record<string, string>> = {
  Red: "Teal",
  Teal: "Red",
  Violet: "Gold",
  Gold: "Violet",
};
const DARK_OF: Readonly<Record<string, string>> = {
  Red: "#290A0F",
  Teal: "#0A2829",
  Violet: "#180A29",
  Gold: "#29210A",
};
const NEXT_CATEGORY: Readonly<Record<Category, Category>> = {
  lipstick: "blush",
  blush: "eyeshadow",
  eyeshadow: "eyeliner",
  eyeliner: "lipstick",
};

/** The palette a probe judges a preview of category + color against. */
export function probeTarget(
  probe: ProbeCase,
  sourceLabel: string,
): Choice {
  switch (probe.probe) {
    case "hue":
      return choice(probe.category, "matte", HUE_PARTNER[sourceLabel]);
    case "dark":
      return choice(
        probe.category,
        "matte",
        sourceLabel,
        DARK_OF[sourceLabel],
      );
    case "absent":
      return choice(NEXT_CATEGORY[probe.category], "matte", sourceLabel);
  }
}

/** The clear-cut probes hard gate H8 judges. Lightness is measured only. */
export function isClearCutProbe(probe: ProbeCase): boolean {
  return probe.probe !== "dark";
}

export const TUTORIAL_CATEGORY: Readonly<Record<Category, string>> = {
  blush: "blush",
  eyeshadow: "eyeshadow",
  eyeliner: "eyeliner",
  lipstick: "lips",
};

// ---------------------------------------------------------------------------
// Worst-case provider calls, from each client's real retry bound
// ---------------------------------------------------------------------------

export const WORST_CASE = {
  analysis: 2,
  recommendation: 2,
  /** Two attempts, each one image and one validator call. */
  preview: 4,
  manifest: 2,
  guideline: 2,
  probe: 1,
} as const;

export function stepsOf(tutorial: TutorialCase): number {
  return lookById(tutorial.parent).choices.length;
}

export function worstCaseFor(evalCase: EvalCase): number {
  switch (evalCase.kind) {
    case "look":
      return WORST_CASE.recommendation + WORST_CASE.preview;
    case "variation":
      return WORST_CASE.preview;
    case "tutorial":
      return WORST_CASE.manifest + stepsOf(evalCase) * WORST_CASE.guideline;
    case "probe":
      return WORST_CASE.probe;
  }
}

export function worstCaseThroughStage(stage: Stage): number {
  const accounts = stage === 1 ? STAGE_1_ACCOUNTS.length : ACCOUNTS.length;
  const cases = ALL_CASES.filter((c) => c.stage <= stage);
  return accounts * WORST_CASE.analysis +
    cases.reduce((sum, c) => sum + worstCaseFor(c), 0);
}
