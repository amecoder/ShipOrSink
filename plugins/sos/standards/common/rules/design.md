---
paths:
  - "**/*.{tsx,jsx,css,scss}"
---

# Product And UI Design Rules

Interfaces must be usable under real working conditions, not only as static screenshots.

## Product UX

- Build the primary workflow first; do not ship a marketing shell instead of the usable product surface.
- Use dense, predictable layouts for operational SaaS tools and expressive layouts only when the domain calls for it.
- Make empty, loading, error, disabled, and success states explicit.
- Keep navigation stable across viewport sizes.

## Visual System

- Preserve the existing design system before adding new visual language.
- Use spacing, typography, contrast, and motion consistently.
- Avoid one-note palettes dominated by a single hue family.
- Avoid decorative UI that competes with task completion.
- Cards are for repeated items, modals, and framed tools; do not nest cards inside cards.

## Accessibility

- Target WCAG 2.1 AA for color contrast, focus states, keyboard navigation, labels, and semantic structure.
- Buttons and controls need accessible names.
- Do not rely on color alone to communicate state.
- Text must not overflow or overlap at mobile, tablet, or desktop widths.

## Responsive Behavior

- Define stable dimensions for boards, grids, toolbars, counters, and fixed-format controls.
- Use CSS Grid and Flexbox before absolute positioning.
- Verify desktop and mobile layouts with real browser screenshots for meaningful UI changes.
- Do not scale font sizes directly with viewport width.
