# Appendix J: UI/UX Figma Screens & Design Progression

---

## Figure J.1: Initial Hand-Drawn Concept Sketches

### APA 7th Citation & Metadata
- **Figure Number**: Figure J.1
- **Figure Title**: *Initial Hand-Drawn Concept Sketches*
- **Manuscript Page**: 192
- **PDF Page**: 200
- **Image Asset**: [fig_j_1_hand_drawn_sketches.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_j_1_hand_drawn_sketches.png)

```
Figure J.1
Initial Hand-Drawn Concept Sketches

Note. Figure J.1 shows the initial ideation and hand-drawn conceptual sketches illustrating the user onboarding flows, emergency trigger layout, tactile button positions, and spatial feedback mechanisms.
```

---

### Hand-Drawn Conceptual Interaction Schemas

```mermaid
flowchart TD
    subgraph SKETCHES ["INITIAL CONCEPTUAL PAPER SKETCHES"]
        direction TB

        SK1["1. Welcome & Onboarding\n• 'Welcome to Buddy'\n• Role selection: 'For Myself' vs. 'Someone Else'"]
        
        SK2["2. Hardware Pairing & Calibration\n• Visual fit check & camera angle test\n• Connection status banner: 'Connected' vs. 'Connection Lost'"]

        SK3["3. Main Accessible Dashboard\n• 6 oversized tactile grid buttons\n• Voice speed and volume slider controls"]

        SK4["4. Real-Time Hazard Alert HUD\n• 'STOP! Vehicle Detected' crimson card\n• Double haptic impulse trigger"]

        SK5["5. Emergency SOS Flow\n• 5-second countdown circular timer\n• Cancel gesture via large tap or phone shake"]

        SK6["6. Clock-Face Navigation<br>• Turn Right in 50 meters (2 o'clock) spoken guidance"]
    end

    SK1 --> SK2
    SK2 --> SK3
    SK3 --> SK4
    SK3 --> SK5
    SK3 --> SK6
```

---

## Figure J.2: Low-Fidelity Wireframes and User Navigation Flows

### APA 7th Citation & Metadata
- **Figure Number**: Figure J.2
- **Figure Title**: *Low-Fidelity Wireframes and User Navigation Flows*
- **Manuscript Page**: 193
- **PDF Page**: 201
- **Image Asset**: [fig_j_2_j_3_wireframes_figma.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_j_2_j_3_wireframes_figma.png)

```
Figure J.2
Low-Fidelity Wireframes and User Navigation Flows

Note. Figure J.2 details the low-fidelity wireframe flows mapping out screen transitions, hierarchical state management, and gesture feedback loops in Figma.
```

---

## Figure J.3: High-Fidelity Figma Screens with Accessible Colors

### APA 7th Citation & Metadata
- **Figure Number**: Figure J.3
- **Figure Title**: *High-Fidelity Figma Screens with Accessible Colors*
- **Manuscript Page**: 193
- **PDF Page**: 201
- **Image Asset**: [fig_j_2_j_3_wireframes_figma.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_j_2_j_3_wireframes_figma.png)

```
Figure J.3
High-Fidelity Figma Screens with Accessible Colors

Note. Figure J.3 presents the polished high-fidelity vector screens in Figma incorporating WCAG 2.2 Level AAA compliant color tokens, dynamic text scaling, and high-contrast card outlines.
```

---

### Design Progression Lifecycle

```mermaid
flowchart LR
    STAGE1["Stage 1: Low-Fidelity Wireframes\n• Structural layout mapping\n• Minimum 56dp tap areas\n• Linear top-to-bottom tab order"] --> STAGE2["Stage 2: High-Fidelity Figma\n• AAA Contrast tokens applied\n• Font scaling up to 200%\n• Dynamic card border outlines"]
    STAGE2 --> STAGE3["Stage 3: Flutter Implementation\n• Responsive widgets & ListenableBuilders\n• TalkBack / VoiceOver semantics\n• Dynamic dark/light theme switching"]
```
