// Property-based testing example (fast-check + Vitest) — common/rules/testing.md.
//
// Copy to tests/ and replace splitAmount with your own code. An example test
// checks inputs you picked; a property test states what must hold for *every*
// input, lets fast-check search for a counterexample, and shrinks it.
//
// Run: npx vitest run tests/property-example.test.ts
// (fast-check is in typescript-react/templates/dev-dependencies.txt)
// Checked by tests/enforcement-pbt.bats: it injects a bug the example below
// misses and expects the property test to fail with a "Counterexample".
import fc from "fast-check";
import { describe, expect, it } from "vitest";

/** Split totalCents into `parts` shares that differ by at most one cent. */
function splitAmount(totalCents: number, parts: number): number[] {
  if (!Number.isInteger(parts) || parts <= 0) {
    throw new RangeError("parts must be a positive integer");
  }
  const base = Math.floor(totalCents / parts);
  const remainder = totalCents - base * parts;
  return [
    ...Array<number>(remainder).fill(base + 1),
    ...Array<number>(parts - remainder).fill(base),
  ];
}

const totals = fc.integer({ min: 0, max: 1_000_000_000 });
const partCounts = fc.integer({ min: 1, max: 1000 });

describe("splitAmount", () => {
  it("shares add up to the total", () => {
    fc.assert(
      fc.property(totals, partCounts, (total, parts) => {
        const sum = splitAmount(total, parts).reduce((a, b) => a + b, 0);
        expect(sum).toBe(total);
      }),
    );
  });

  it("shares are fair (differ by at most one)", () => {
    fc.assert(
      fc.property(totals, partCounts, (total, parts) => {
        const shares = splitAmount(total, parts);
        expect(shares).toHaveLength(parts);
        expect(Math.max(...shares) - Math.min(...shares)).toBeLessThanOrEqual(
          1,
        );
      }),
    );
  });

  it("documents the intent with one readable example", () => {
    expect(splitAmount(100, 3)).toEqual([34, 33, 33]);
  });
});
