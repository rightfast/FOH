# FOH design system

FOH uses the **Signal Desk** visual system: a calm native Mac utility informed
by stage-management cue sheets and signal-routing diagrams. It should feel
precise and dependable without imitating professional mixing software.

## Principles

1. Show the signal. Current input and output relationships should be visible,
   not hidden inside decorative cards.
2. Color has one job at a time. Orange means selection or action, green means a
   confirmed live or ready state, amber means attention, and red means failure
   or destruction.
3. Prefer rules to containers. Related rows share a surface and use hairline
   separators. A bordered panel is reserved for a meaningful functional group.
4. Stay native. Use standard Mac controls, keyboard behavior, SF Symbols, and
   system typography. Brand character comes from composition and state, not
   custom control chrome.
5. Keep product truth visible. FOH selects macOS defaults and observes device
   state; it does not imply DSP, per-app mixing, or virtual routing.

## Palette

| Role | Light | Dark | Usage |
| --- | --- | --- | --- |
| Canvas | `#F2EBDD` | `#1D1C1A` | Window ground |
| Panel | `#F8F4EA` | `#252421` | Functional groups |
| Raised | `#FFFDF7` | `#2D2B27` | Selected device within a route |
| Ink | `#252522` | `#F1EBDD` | Primary text |
| Muted | `#6E695F` | `#AAA398` | Secondary text |
| Rule | `#CEC5B5` | `#4B4842` | Hairline structure |
| Signal | `#C84E24` | `#F07145` | Selection and primary action |
| Live | `#286247` | `#63B58C` | Confirmed ready or active state |
| Caution | `#9B5A18` | `#E0A253` | Paused, unavailable, needs attention |
| Danger | `#A43F3B` | `#E57A74` | Errors and destructive actions |

Never use the system blue accent as FOH's identity color. Status must remain
understandable through a symbol and label when color is unavailable.

## Shape and structure

- Functional panels use a 7-point continuous radius and a 0.7-point rule.
- Selected navigation uses a two-point signal-orange marker and a quiet tint.
- Lists share one enclosing surface; individual rows are not floating cards.
- Pills are not used for general status. Compact rectangular marks are allowed
  for short state labels such as Default.
- Shadows, gradients, decorative blur, and glass are not part of the system.

## Typography and motion

Use the macOS system family. Page titles are 28-point semibold. Device names
and section headings use native headline styles; measurements and counts use
tabular figures. Avoid eyebrow text and all-caps decoration. Motion is limited
to direct state transitions and the onboarding page change, with Reduce Motion
support.

## Reference composition

The approved Route Map comp is stored at
`.impeccable/mocks/signal-desk-route-map.png`. It establishes the two parallel
signal paths and density, but its invented Add Device action, output activity
meter, oversized device icons, and extra enclosing borders are not literal
requirements.
