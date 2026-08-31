# Appendix I: Accessibility Design System, UI Tokens & Clinical Swatches

---

## Figure I.1: EasyLens Accessibility Design System and UI Toolkit Tokens

### APA 7th Citation & Metadata
- **Figure Number**: Figure I.1
- **Figure Title**: *EasyLens Accessibility Design System and UI Toolkit Tokens*
- **Manuscript Page**: 188
- **PDF Page**: 196
- **Image Asset**: [fig_i_1_design_system_tokens.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_i_1_design_system_tokens.png)

```
Figure I.1
EasyLens Accessibility Design System and UI Toolkit Tokens

Note. Figure I.1 illustrates the Buddy accessibility design system, incorporating tokenized typography scales, minimum tactile target geometries, and structured mascot branding specifications.
```

---

### Design System Token Hierarchy

```mermaid
graph TD
    subgraph DESIGN_SYSTEM ["EASYLENS ACCESSIBILITY DESIGN SYSTEM (WCAG 2.2 AAA)"]
        direction TB

        subgraph BRAND ["1. Brand Identity & Mascot Specification"]
            M1["Buddy App Icon\n• 1:1 Aspect Ratio Rounded Square\n• Solid Background Navy (#002663)\n• 3D Peeking Mascot Vector\n• Communicates Vision, Guidance & Safety"]
        end

        subgraph TOKENS ["2. Color & State Tokens"]
            C1["Primary Brand Navy: #002663"]
            C2["Hazard Red (Immediate Danger): #D32F2F / #FFEBEE"]
            C3["Warning Amber (Moderate Obstacle): #FFA000 / #FFF8E1"]
            C4["Safe Green (Clear Path): #2E7D32 / #E8F5E9"]
            C5["Info Indigo (Conversational AI): #3F51B5 / #E8EAF6"]
        end

        subgraph GEOMETRY ["3. Tactile Geometry & Sizing Tokens"]
            G1["Minimum Touch Target: 56 x 56 dp (Exceeds 48dp WCAG Minimum)"]
            G2["Primary Display Heading: 28–32 sp (Bold Weight 700)"]
            G3["High-Legibility Body Text: 18–22 sp (Medium Weight 500)"]
            G4["Card Elevation: 4 dp with 2 px High-Contrast Stroke"]
        end
    end
```

---

## Figure I.2: EasyLens Deployed High-Fidelity UI Screens and Theme Swatches

### APA 7th Citation & Metadata
- **Figure Number**: Figure I.2
- **Figure Title**: *EasyLens Deployed High-Fidelity UI Screens and Theme Swatches*
- **Manuscript Page**: 190
- **PDF Page**: 198
- **Image Asset**: [fig_i_2_deployed_ui_swatches.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_i_2_deployed_ui_swatches.png)

```
Figure I.2
EasyLens Deployed High-Fidelity UI Screens and Theme Swatches

Note. Figure I.2 exhibits the four deployed high-contrast visual themes designed to satisfy WCAG 2.2 Level AAA standards and accommodate specific low-vision pathologies.
```

---

### High-Contrast Swatches, Contrast Ratios & Clinical Benefit Matrix

| Theme Name | Hex Fill Tokens | Contrast Ratio | Target Clinical Demographic | Visual & Medical-Accessibility Benefit |
| :--- | :--- | :---: | :--- | :--- |
| **Black on White Theme** | Background: `#FFFFFF`<br>Foreground: `#000000` | **21.00:1 (AAA)** | Mild visual drop-offs, astigmatism, high myopia | Delivers traditional reading contrast with maximum text sharpness and edge definition. |
| **White on Black Theme** | Background: `#000000`<br>Foreground: `#FFFFFF` | **21.00:1 (AAA)** | Cataracts, corneal scarring, severe photophobia | Restricts backlight emission to prevent internal light-scattering, glare-induced halos, and eye fatigue. |
| **Yellow on Black Theme** | Background: `#000000`<br>Foreground: `#E6E600` | **16.51:1 (AAA)** | Macular degeneration, central vision field loss | Accentuates edge contours with high-luminance yellow to stimulate remaining peripheral visual fields. |
| **Green on Black Theme** | Background: `#000000`<br>Foreground: `#33CC33` | **10.37:1 (AAA)** | Diabetic retinopathy, patchy vision loss | Targets high-sensitivity retinal cone cells to maximize visual clarity in shaded or low-light conditions. |
