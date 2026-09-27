---
name: Precision Enterprise Ops
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#444653'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#757684'
  outline-variant: '#c4c5d5'
  surface-tint: '#3755c3'
  primary: '#00288e'
  on-primary: '#ffffff'
  primary-container: '#1e40af'
  on-primary-container: '#a8b8ff'
  inverse-primary: '#b8c4ff'
  secondary: '#4648d4'
  on-secondary: '#ffffff'
  secondary-container: '#6063ee'
  on-secondary-container: '#fffbff'
  tertiary: '#2d3449'
  on-tertiary: '#ffffff'
  tertiary-container: '#434b60'
  on-tertiary-container: '#b4bbd5'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dde1ff'
  primary-fixed-dim: '#b8c4ff'
  on-primary-fixed: '#001453'
  on-primary-fixed-variant: '#173bab'
  secondary-fixed: '#e1e0ff'
  secondary-fixed-dim: '#c0c1ff'
  on-secondary-fixed: '#07006c'
  on-secondary-fixed-variant: '#2f2ebe'
  tertiary-fixed: '#dae2fd'
  tertiary-fixed-dim: '#bec6e0'
  on-tertiary-fixed: '#131b2e'
  on-tertiary-fixed-variant: '#3f465c'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0em
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: 0.005em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
  code-md:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: -0.01em
  sla-timer:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-desktop: 1.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system delivers an enterprise-grade, high-density IT operations interface balancing speed, absolute legibility, and quiet intelligence. Drawing cues from high-performance systems like Linear, Stripe, and Vercel, the design favors clarity over decoration. 

Every visual affordance serves triage velocity, cognitive calm during high-severity incidents, and frictionless navigation. Artificial intelligence is framed not as an expressive conversational gimmick, but as an ambient, dependable copilot—signaled through understated structural framing, crisp indigo badging, and predictable inline utilities.

The interface evokes uncompromising trust, surgical precision, and unhurried control. High-contrast typography, strict spatial rhythm, and structured data hierarchy ensure operators handle complex enterprise infrastructure without visual fatigue.

## Colors

The palette enforces strict WCAG 2.1 AA (4.5:1 minimum) compliance across all interactive states and analytical badges.

### Core Canvas & Structure
- **Background (`#F8FAFC`)**: Canvas base creating clean separation from active cards.
- **Surface (`#FFFFFF`)**: Primary content cards, modals, dropdowns, and active table rows.
- **Surface Muted (`#F1F5F9`)**: Neutral chips, table headers, code-blocks, and inactive rail containers.
- **Border (`#E2E8F0`)**: Crisp 1px geometric divisions throughout the system.
- **Border Subtle (`#F1F5F9`)**: Secondary horizontal rules and internal list dividers.

### Typography Tokens
- **Text Primary (`#0F172A`)**: Titles, primary metrics, high-emphasis tickets, form input text (14.8:1 against white).
- **Text Secondary (`#64748B`)**: Metadata, labels, table headers, breadcrumbs, placeholder text (4.6:1 against white).
- **Text Inverse (`#FFFFFF`)**: Solid primary button labels and filled status tags.

### Action & Copilot Accents
- **Primary Interactive (`#1E40AF`)**: Primary buttons, selected tab indicators, active navigation icons.
- **Primary Hover (`#1D4ED8`)**: Focused and hovered primary action states.
- **AI Accent (`#6366F1`)**: Reserved exclusively for AI triage suggestions, auto-categorization tags, and summary wrappers. Used as a solid micro-accent, outline, or 8% tinted background—never as large gradients.

### Triage Priority & Status Matrix
- **P1 Critical (`#DC2626`)**: Severe outages, critical blocker tickets. Background tint: `#FEF2F2`.
- **P2 High (`#EA580C`)**: Degraded service, escalated requests. Background tint: `#FFF7ED`.
- **P3 Normal (`#2563EB`)**: Routine provisioning, maintenance. Background tint: `#EFF6FF`.
- **P4 Low (`#64748B`)**: Informational tasks, scheduled queries. Background tint: `#F8FAFC`.
- **Status Resolved (`#16A34A`)**: Complete or healthy services. Background tint: `#F0FDF4`.
- **Status Warning (`#D97706`)**: Impending SLA breach or unassigned alerts. Background tint: `#FFFBEB`.

## Typography

The type system is engineered around two high-precision typefaces: `Inter` for structural clarity across dense data grids and forms, and `JetBrains Mono` for non-proportional alignment in SLA count-down timers, system error traces, machine hostnames, and IP tables.

### Rules of Usage
- **Numeric Alignment**: JetBrains Mono must be utilized on all operational counters, ticket references (e.g., `INC-8942`), and SLA countdown clocks to prevent layout shift during second-by-second updates.
- **Optical Balance**: Headings utilize negative letter spacing to lock text tightly at medium and large scales, preventing loose silhouettes.
- **Form Controls & Metadata**: Field labels, micro badges, and category chips utilize uppercase or title-case `label-sm` and `label-md` with slight positive tracking to maximize rapid scanning.

## Layout & Spacing

The layout model is anchored by an 8px grid discipline (`0.5rem` baseline), supporting dense data presentation without visual clutter.

### Desktop Structure
- **Navigation Rail**: A fixed 72px width Material 3 enterprise rail docked to the left edge of the screen, housing primary operational views (Tickets, SLA Monitor, Knowledge Base, Automations, Settings). Expandable drawer extends to 240px when pinned by operators.
- **Main Canvas**: Fluid multi-pane workspace with a standard 12-column sub-grid, `1.5rem` gutters, and `1.5rem` screen margins.
- **Split Triage Layout**: 400px fixed-width ticket queue on the left, fluid center workspace for incident investigation and message stream, and an optional 360px collapsible panel on the right for AI diagnostics, asset context, and SLA telemetry.

### Tablet & Mobile Structure
- **Breakpoints**: 
  - Mobile: `< 768px`
  - Tablet: `768px - 1024px`
  - Desktop: `> 1024px`
- **Mobile Navigation**: The left navigation rail converts strictly into a 56px fixed bottom navigation bar displaying high-frequency destinations (Triage, Search, My Incidents, Profile).
- **Responsive Stacking**: Multi-pane triage reflows into a single full-screen drilldown flow. Center workspace takes 100% viewport width, while contextual inspector tools become bottom action sheets.

## Elevation & Depth

Visual hierarchy is communicated through structural 1px borders paired with subtle, low-spread 0–2dp elevation shadows. The interface avoids aggressive atmospheric shadows or diffused colored glows.

- **Level 0 (Base / Flat)**: 
  - `box-shadow: none; border: 1px solid #E2E8F0;`
  - Used for background canvas elements, static table cells, list containers, and persistent sidebars.
- **Level 1 (Card Rest / Micro Surface)**: 
  - `box-shadow: 0 1px 2px 0 rgba(15, 23, 42, 0.04); border: 1px solid #E2E8F0;`
  - Applied to ticket cards, workspace modules, metric widgets, and input fields.
- **Level 2 (Hover / Active Float)**: 
  - `box-shadow: 0 4px 6px -1px rgba(15, 23, 42, 0.06), 0 2px 4px -2px rgba(15, 23, 42, 0.04); border: 1px solid #CBD5E1;`
  - Applied to hovered interactive cards, active popovers, triage list items under cursor, and pinned filters.
- **Level 3 (Modal / Context Menus / Command Palettes)**: 
  - `box-shadow: 0 10px 15px -3px rgba(15, 23, 42, 0.08), 0 4px 6px -4px rgba(15, 23, 42, 0.03); border: 1px solid #CBD5E1;`
  - Used for quick-command palettes (Cmd+K), full triage modals, and flyout diagnostic drawers.

### AI Surface Treatment
AI assistance modules maintain identical Level 1 or Level 2 physical elevation, signaled solely by a crisp border rule (`border: 1px solid #C7D2FE`) and an internal highlight ring (`inset 0 0 0 1px #EEF2FF`).

## Shapes

The geometric architecture relies on a consistent 8px (`0.5rem`) corner radius across primary UI containers to retain an efficient, industrial character.

- **Cards & Data Panels**: `8px` (`0.5rem`) border-radius with 16px (`1rem`) internal padding.
- **Form Controls & Buttons**: `6px` (`0.375rem`) border-radius for inputs, dropdowns, and button groups, maintaining structural alignment with the card container.
- **Chips, SLA Badges, and Pill Statuses**: Fully rounded (`9999px`) or compact `4px` (`0.25rem`) geometric tags depending on density tier. Priority tags default to `4px` radius for tabular stability.
- **Modals & Drawers**: `8px` (`0.5rem`) on desktop; bottom sheets on mobile utilize `12px 12px 0 0`.

## Components

### Buttons
- **Primary**: Background `#1E40AF`, Text `#FFFFFF`, 6px radius, hover state `#1D4ED8`. Active state `#1E3A8A`. Disabled state `#94A3B8`.
- **Secondary / Outline**: Background `#FFFFFF`, Border 1px `#E2E8F0`, Text `#0F172A`, hover background `#F8FAFC`.
- **Ghost**: Background transparent, Text `#64748B`, hover background `#F1F5F9`, hover text `#0F172A`.
- **Destructive**: Background `#DC2626`, Text `#FFFFFF`, hover `#B91C1C`.
- **Sizing**: Default height 36px (compact desktop) or 48px touch target on mobile devices via padding wrappers or minimum dimension constraints.

### Chips & Badges
- **Priority Badges**:
  - `P1`: Background `#FEF2F2`, Text `#DC2626`, Border `#FCA5A5`.
  - `P2`: Background `#FFF7ED`, Text `#EA580C`, Border `#FDBA74`.
  - `P3`: Background `#EFF6FF`, Text `#2563EB`, Border `#93C5FD`.
  - `P4`: Background `#F8FAFC`, Text `#64748B`, Border `#CBD5E1`.
- **AI Assist Tag**: Height 20px, font size 11px, Background `#EEF2FF`, Text `#4F46E5`, Border `1px solid #C7D2FE`. Paired with a static micro spark icon.

### Form Inputs & Selects
- 1px border `#E2E8F0`, 6px radius, background `#FFFFFF`, text `#0F172A`, placeholder `#94A3B8`.
- Focus state: Border `#1E40AF` with a non-blurring ring offset: `box-shadow: 0 0 0 1px #1E40AF`.
- Validation errors: Border `#DC2626`, focus ring `#DC2626`.

### Cards & Ticket Modules
- Outer container: 8px border radius, 1px `#E2E8F0` border, `#FFFFFF` background, exactly 16px (`1rem`) internal padding.
- Interactive rows in list views feature a subtle left border strip (3px) displaying ticket priority on active hover.

### Navigation Rail (Desktop)
- Fixed 72px rail width. Background `#FFFFFF`, right border 1px `#E2E8F0`.
- Rail icon targets: 48x48px hit area, 24px icon, centered label below (11px, `#64748B`).
- Active item indicator: Background `#EFF6FF`, Icon and Text `#1E40AF`, with a 3px vertical pill on the inner rail edge.

### Bottom Navigation Bar (Mobile)
- Fixed 56px height (plus safe-area-inset-bottom). Background `#FFFFFF`, top border 1px `#E2E8F0`.
- 4 primary destinations evenly spaced with 48x48px touch boundaries.

### SLA Countdown Timers
- Rendered in `JetBrains Mono`, 12px weight 500.
- Normal: Text `#64748B`.
- Warning (< 30 min): Text `#D97706`, Background `#FFFBEB`, Border 1px `#FDE68A`.
- Breached: Text `#DC2626`, Background `#FEF2F2`, Border 1px `#FECACA`.