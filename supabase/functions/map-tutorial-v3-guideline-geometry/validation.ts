import {
  CATEGORY_ROLES,
  COORDINATE_SPACE,
  type GeometryRole,
  GEOMETRY_SCHEMA_VERSION,
  LIMITS,
  type PrimitiveKind,
  ROLE_KINDS,
} from "./types.ts";

/**
 * Strict server-side geometry validation.
 *
 * Mirrors `TutorialV3GeometryValidator` in
 * `lib/features/tutorial_v3/domain/validation/tutorial_v3_geometry_validator.dart`.
 * The client validates again when it renders, but the server is the gate that
 * decides what may be persisted — a model response is never trusted because it
 * parsed.
 *
 * The guiding rule is **reject, never repair**. Out-of-range coordinates are
 * not clamped, unknown keys are not dropped, and a malformed primitive does not
 * get skipped so the rest can render. Any of those would store an overlay that
 * looks authoritative while pointing somewhere wrong.
 */
export class GeometryRejected extends Error {
  constructor(readonly reasons: string[]) {
    super(reasons.join(" "));
  }
}

const DOCUMENT_KEYS = new Set([
  "schema_version",
  "category",
  "coordinate_space",
  "primitives",
]);

const PRIMITIVE_KEYS = new Set([
  "kind",
  "role",
  "vertices",
  "center",
  "radius_x",
  "radius_y",
  "rotation",
  "start",
  "end",
  "position",
]);

const POINT_KEYS = new Set(["x", "y"]);

export interface ValidatedGeometry {
  schema_version: number;
  category: string;
  coordinate_space: string;
  primitives: Record<string, unknown>[];
}

export function parseAndValidateGeometry(
  raw: string,
  expectedCategory: string,
): ValidatedGeometry {
  let payload: unknown;
  try {
    payload = JSON.parse(stripCodeFence(raw));
  } catch {
    throw new GeometryRejected(["The geometry was not valid JSON."]);
  }
  if (
    typeof payload !== "object" || payload === null || Array.isArray(payload)
  ) {
    throw new GeometryRejected(["The geometry must be a JSON object."]);
  }
  const root = payload as Record<string, unknown>;
  const reasons: string[] = [];

  rejectUnknownKeys(root, DOCUMENT_KEYS, "document", reasons);

  if (root.schema_version !== GEOMETRY_SCHEMA_VERSION) {
    reasons.push(
      `Unsupported geometry schema version ${root.schema_version}; ` +
        `this build reads ${GEOMETRY_SCHEMA_VERSION}.`,
    );
  }
  if (root.coordinate_space !== COORDINATE_SPACE) {
    reasons.push(
      `coordinate_space must be "${COORDINATE_SPACE}", got "${root.coordinate_space}".`,
    );
  }
  if (root.category !== expectedCategory) {
    // The server asked about one step; a response about another category
    // cannot be trusted to describe this one.
    reasons.push(
      `category mismatch: expected "${expectedCategory}", got "${root.category}".`,
    );
  }

  const rawPrimitives = root.primitives;
  if (!Array.isArray(rawPrimitives) || rawPrimitives.length === 0) {
    reasons.push("primitives must be a non-empty list.");
    throw new GeometryRejected(reasons);
  }
  if (rawPrimitives.length > LIMITS.maxPrimitives) {
    reasons.push(
      `too many primitives (${rawPrimitives.length}); the limit is ${LIMITS.maxPrimitives}.`,
    );
  }

  const primitives: Record<string, unknown>[] = [];
  for (let index = 0; index < rawPrimitives.length; index += 1) {
    const primitive = validatePrimitive(
      rawPrimitives[index],
      index,
      expectedCategory,
      reasons,
    );
    if (primitive) primitives.push(primitive);
  }

  if (reasons.length > 0) throw new GeometryRejected(reasons);

  return {
    schema_version: GEOMETRY_SCHEMA_VERSION,
    category: expectedCategory,
    coordinate_space: COORDINATE_SPACE,
    primitives,
  };
}

function validatePrimitive(
  raw: unknown,
  index: number,
  category: string,
  reasons: string[],
): Record<string, unknown> | null {
  const where = `primitive ${index}`;
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    reasons.push(`${where} is not an object.`);
    return null;
  }
  const map = raw as Record<string, unknown>;
  rejectUnknownKeys(map, PRIMITIVE_KEYS, where, reasons);

  const kind = map.kind;
  if (
    typeof kind !== "string" ||
    !["region", "ellipse", "polyline", "arrow", "marker"].includes(kind)
  ) {
    reasons.push(`${where} has unknown kind "${kind}".`);
    return null;
  }
  const role = map.role;
  if (typeof role !== "string" || !(role in ROLE_KINDS)) {
    reasons.push(`${where} has unknown role "${role}".`);
    return null;
  }

  const allowedKinds = ROLE_KINDS[role as GeometryRole];
  if (!allowedKinds.includes(kind as PrimitiveKind)) {
    reasons.push(
      `${where} uses kind "${kind}" for role "${role}", which only accepts ${
        allowedKinds.join(", ")
      }.`,
    );
    return null;
  }
  const allowedRoles = CATEGORY_ROLES[category] ?? [];
  if (!allowedRoles.includes(role as GeometryRole)) {
    reasons.push(
      `${where} uses role "${role}", which "${category}" does not allow.`,
    );
    return null;
  }

  switch (kind) {
    case "region":
    case "polyline": {
      const vertices = points(map.vertices, where, "vertices", reasons);
      if (!vertices) return null;
      const min = kind === "region"
        ? LIMITS.minRegionVertices
        : LIMITS.minPolylineVertices;
      const max = kind === "region"
        ? LIMITS.maxRegionVertices
        : LIMITS.maxPolylineVertices;
      if (vertices.length < min || vertices.length > max) {
        reasons.push(
          `${where} ${kind} needs ${min}–${max} vertices, got ${vertices.length}.`,
        );
        return null;
      }
      return { kind, role, vertices };
    }
    case "ellipse": {
      const center = point(map.center, where, "center", reasons);
      const radiusX = finite(map.radius_x, where, "radius_x", reasons);
      const radiusY = finite(map.radius_y, where, "radius_y", reasons);
      const rotation = map.rotation === undefined || map.rotation === null
        ? 0
        : finite(map.rotation, where, "rotation", reasons);
      if (
        center === null || radiusX === null || radiusY === null ||
        rotation === null
      ) {
        return null;
      }
      for (const [name, value] of [["radius_x", radiusX], ["radius_y", radiusY]] as const) {
        if (value < LIMITS.minRadius || value > LIMITS.maxRadius) {
          reasons.push(
            `${where} ${name} ${value} is outside ${LIMITS.minRadius}–${LIMITS.maxRadius}.`,
          );
          return null;
        }
      }
      const ellipse: Record<string, unknown> = {
        kind,
        role,
        center,
        radius_x: radiusX,
        radius_y: radiusY,
      };
      if (rotation !== 0) ellipse.rotation = rotation;
      return ellipse;
    }
    case "arrow": {
      const start = point(map.start, where, "start", reasons);
      const end = point(map.end, where, "end", reasons);
      if (!start || !end) return null;
      const length = Math.sqrt(
        (end.x - start.x) ** 2 + (end.y - start.y) ** 2,
      );
      if (length < LIMITS.minArrowLength) {
        reasons.push(
          `${where} arrow length ${length.toFixed(4)} is below ${LIMITS.minArrowLength}; it shows no direction.`,
        );
        return null;
      }
      return { kind, role, start, end };
    }
    case "marker": {
      const at = point(map.position, where, "position", reasons);
      if (!at) return null;
      return { kind, role, position: at };
    }
  }
  return null;
}

function rejectUnknownKeys(
  map: Record<string, unknown>,
  allowed: Set<string>,
  where: string,
  reasons: string[],
): void {
  const unknown = Object.keys(map).filter((key) => !allowed.has(key)).sort();
  if (unknown.length > 0) {
    // Style, text and code fields land here. The model may not control
    // presentation, so their presence is a contract breach, not noise.
    reasons.push(`${where} has unsupported fields: ${unknown.join(", ")}.`);
  }
}

interface Point {
  x: number;
  y: number;
}

function points(
  raw: unknown,
  where: string,
  field: string,
  reasons: string[],
): Point[] | null {
  if (!Array.isArray(raw)) {
    reasons.push(`${where} ${field} must be a list.`);
    return null;
  }
  const result: Point[] = [];
  for (let index = 0; index < raw.length; index += 1) {
    const parsed = point(raw[index], where, `${field}[${index}]`, reasons);
    if (!parsed) return null;
    result.push(parsed);
  }
  return result;
}

function point(
  raw: unknown,
  where: string,
  field: string,
  reasons: string[],
): Point | null {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    reasons.push(`${where} ${field} must be an object with x and y.`);
    return null;
  }
  const map = raw as Record<string, unknown>;
  const unknown = Object.keys(map).filter((key) => !POINT_KEYS.has(key));
  if (unknown.length > 0) {
    reasons.push(`${where} ${field} has unsupported fields: ${unknown.join(", ")}.`);
    return null;
  }
  const x = finite(map.x, where, `${field}.x`, reasons);
  const y = finite(map.y, where, `${field}.y`, reasons);
  if (x === null || y === null) return null;
  if (x < 0 || x > 1 || y < 0 || y > 1) {
    // Deliberately not clamped: out of range means the model misunderstood the
    // coordinate space, and a clamped point draws a confidently wrong overlay.
    reasons.push(
      `${where} ${field} (${x}, ${y}) is outside the normalized 0–1 range.`,
    );
    return null;
  }
  return { x, y };
}

function finite(
  raw: unknown,
  where: string,
  field: string,
  reasons: string[],
): number | null {
  if (typeof raw !== "number") {
    reasons.push(`${where} ${field} must be a number.`);
    return null;
  }
  if (!Number.isFinite(raw)) {
    reasons.push(`${where} ${field} is not a finite number.`);
    return null;
  }
  return raw;
}

/** Models sometimes wrap JSON in a markdown fence despite the schema. */
export function stripCodeFence(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed.startsWith("```")) return trimmed;
  return trimmed.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}
