---
name: Academic Monolith
colors:
  surface: '#fcf8fa'
  surface-dim: '#dcd9db'
  surface-bright: '#fcf8fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f5'
  surface-container: '#f0edef'
  surface-container-high: '#eae7e9'
  surface-container-highest: '#e4e2e4'
  on-surface: '#1b1b1d'
  on-surface-variant: '#45464d'
  inverse-surface: '#303032'
  inverse-on-surface: '#f3f0f2'
  outline: '#76777d'
  outline-variant: '#c6c6cd'
  surface-tint: '#565e74'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#131b2e'
  on-primary-container: '#7c839b'
  inverse-primary: '#bec6e0'
  secondary: '#515f74'
  on-secondary: '#ffffff'
  secondary-container: '#d5e3fc'
  on-secondary-container: '#57657a'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#271901'
  on-tertiary-container: '#98805d'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae2fd'
  primary-fixed-dim: '#bec6e0'
  on-primary-fixed: '#131b2e'
  on-primary-fixed-variant: '#3f465c'
  secondary-fixed: '#d5e3fc'
  secondary-fixed-dim: '#b9c7df'
  on-secondary-fixed: '#0d1c2e'
  on-secondary-fixed-variant: '#3a485b'
  tertiary-fixed: '#fcdeb5'
  tertiary-fixed-dim: '#dec29a'
  on-tertiary-fixed: '#271901'
  on-tertiary-fixed-variant: '#574425'
  background: '#fcf8fa'
  on-background: '#1b1b1d'
  surface-variant: '#e4e2e4'
typography:
  headline-lg:
    fontFamily: Outfit
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Outfit
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
  headline-md:
    fontFamily: Outfit
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  amharic-body:
    fontFamily: Noto Sans Ethiopic
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 26px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  container-max: 1200px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style
This design system centers on high-contrast minimalism and structural clarity, drawing heavy inspiration from editorial design and tool-based interfaces like Notion. The brand personality is authoritative yet invisible—prioritizing content and learning over interface decoration. 

The aesthetic is characterized by a "print-on-screen" feel: heavy use of white space (or deep black in dark mode), sharp lines, and a total absence of gradients or soft shadows. It targets an educational demographic that requires focus and information density. The emotional response should be one of professional reliability, intellectual rigor, and functional efficiency.

## Colors
The palette is strictly functional, utilizing a high-contrast monochromatic base to establish hierarchy. 

- **Light Mode:** Uses a pure `#FFFFFF` canvas. Text and primary structural borders use `#0F172A` (Slate 900) for maximum legibility.
- **Dark Mode:** Transitions to a deep `#0A0A0A` background with `#FFFFFF` text and borders to maintain the high-contrast "ink-on-paper" impact.
- **Accents:** Only used for semantic status indicators (Success, Pending, Error). These should be used sparingly as small pips, thin borders, or text labels—never as large background fills.
- **Constraint:** No purple hues and no gradients are permitted under any circumstances.

## Typography
The typographic system uses **Outfit** for headlines to provide a subtle geometric character, while **Inter** handles all functional body text and UI labels for its exceptional clarity.

For Amharic content, **Noto Sans Ethiopic** is the standard, paired at equivalent optical sizes to the English counterparts. Headlines should use tight letter spacing (`-0.02em`) to mimic professional typesetting. Use `label-caps` for table headers and small metadata categories.

## Layout & Spacing
The design system follows a strict 4px grid. Layouts are print-inspired, utilizing a 12-column fixed grid for desktop and a single-column fluid flow for mobile.

Spacing should feel "tight" and efficient. Avoid excessive padding in favor of clear structural dividers (borders). Elements are grouped using small 8px or 12px gaps, while major sections are separated by 32px or 48px increments. Alignment is always strictly horizontal or vertical; avoid staggered or organic layouts.

## Elevation & Depth
Depth is created through **structural outlines** rather than shadows. This system avoids all blurs and ambient shadows.

- **Level 0 (Base):** Default background.
- **Level 1 (Sheet):** Defined by a 1px solid border (`#0F172A` in light, `#FFFFFF` in dark).
- **Active State:** Represented by a 2px border or a solid color fill with inverted text.
- **Interactions:** Hover states should use a subtle background tint (`#F1F5F9` in light mode) or a thickness change in the border.

## Shapes
Shapes are primarily sharp or minimally rounded to maintain a serious, academic tone. A "Soft" (`0.25rem`) corner radius is the maximum allowed for standard components like buttons and cards. Complex data containers or code blocks should remain perfectly sharp (`0px`) to emphasize the grid-based nature of the system.

## Components

### Buttons
- **Primary:** Solid `#0F172A` background with white text. No shadow. 1px border.
- **Secondary:** White background with 1px solid border. 
- **Active/Press:** Shift 2px down/right if mimicking a tactile click, or simply invert colors.

### Input Fields
- **Default:** 1px solid border. Sharp corners. Label positioned above the field in `label-caps`.
- **Focus:** 2px solid border. No glow/outer shadow.

### Cards
- Standard cards use a 1px border and 16px padding. 
- No background color difference from the main canvas unless used for "Callouts" (mimicking Notion's callout blocks with a very subtle neutral tint).

### Chips & Tags
- Rectangular with 2px rounded corners. 
- Use semantic colors (`Success`, `Pending`, `Error`) only for the text or a small 6px bullet inside the chip. Backgrounds remain neutral or white.

### Lists & Tables
- High-density. Horizontal dividers only. 
- Row hover states should use a light neutral fill to highlight the active line without breaking the vertical rhythm.