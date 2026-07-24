# EasyLens Navigation & Hazard Warning System

This document outlines the real-time hazard mapping, classification logic, alert feedback mechanisms, and the complete catalog of target objects utilized in the EasyLens edge computer vision and audio navigation systems.

---

## 1. Warning & Hazard Categories

EasyLens classifies environmental features detected in the camera view into three hazard priority levels:

### 🔴 Priority 1: Critical Hazards (Immediate Action Required)
- **Haptic Alert**: Double high-intensity vibration sequence (vibrate, pause 150ms, vibrate).
- **Audio Feedback**: Priority Text-to-Speech (TTS) command interrupting previous speech.
- **UI Styling**: Crimson Red background card (`Color(0xFFFFEBEE)`) with error icon.
- **Triggers**:
  - **STOP!**: Bounding box proximity threshold exceeded; direct collision path detected.
  - **Fire Hazard!**: Inference detection of fire, open flames, or heavy smoke.
  - **Sharp / Weapon Hazard!**: Knives, weapons, or blades in path.
  - **Live Wires / Electrical Danger**: Exposed high-voltage lines, generators, or loose cables.

### 🟡 Priority 2: Moderate Hazards (Precautionary Actions)
- **Haptic Alert**: Single medium-impact haptic feedback impulse.
- **Audio Feedback**: Spoken guidance advising user on steering/speed adjustments.
- **UI Styling**: Amber/Orange background cards (`Color(0xFFFFF8E1)` or `Color(0xFFFFFDE7)`).
- **Triggers**:
  - **Vehicle Detected**: Approaching jeepneys, tricycles, cars, or motorcycles.
  - **Damaged Pathway**: Sidewalk cracks, potholes, or open grates.
  - **Stairs Detected**: Approaching step-downs or step-ups.
  - **Obstacle Ahead**: Generic pathway blockages (e.g. posts, poles, construction barriers).
  - **Multiple Hazards**: Extremely complex environment with multiple active threat items.
  - **Moving Too Fast**: Device motion exceeds accelerometer tracking limits for accurate visual scan.

### 🔵 Priority 3: Informational & Assistive Events
- **Haptic Alert**: None.
- **Audio Feedback**: Conversational announcements.
- **UI Styling**: Indigo/Blue background cards (`Color(0xFFE8EAF6)`).
- **Triggers**:
  - **Traffic Sign Located**: Crosswalk markers, Stop signs, or street warnings.
  - **Person Detected**: Nearby pedestrians (encouraging spatial awareness).
  - **GO Signal Detected**: Pedestrian green lights detected at traffic signals.
  - **Low Light Detected**: Ambient illumination falls below threshold, warning that camera scanning confidence is reduced.
  - **Path Clear**: Reverting to normal walking state (Green card).

---

## 2. Threat Calculation Logic

Threat scoring is computed dynamically for every detected object based on three primary factors:

$$\text{Threat Score} = (\text{Base Risk} \times 0.4) + (\text{Proximity Score} \times 0.4) + (\text{Velocity Score} \times 0.2)$$

1. **Base Risk (40%)**: Pre-assigned hazard level weight per class label (e.g., vehicles and stairs have higher base risk than tables or cups).
2. **Proximity Score (40%)**: Normalized bounding box area relative to image width/height (larger area indicates closer proximity).
3. **Velocity Score (20%)**: Change in bounding box area over time, highlighting objects that are moving rapidly towards the user.

---

## 3. The 24 Custom Trained Navigation Objects

These 24 target classes were merged and optimized from a noisy 26-class dataset specifically mapping urban navigation hazards to improve convergence:

1. **Guide Cane**: White cane helper used by visually impaired pedestrians.
2. **Stairs Ascending**: Indoor or outdoor stairs going upwards (step-up).
3. **Stairs Descending**: Indoor or outdoor stairs going downwards (step-down).
4. **Traffic Cone**: Construction zone safety marker.
5. **Jeepney**: Local public utility vehicle (PUV) common in Philippine transit paths.
6. **Tricycle**: Three-wheeled local public utility vehicle.
7. **Car**: Standard passenger automobile.
8. **Truck**: Medium-to-large cargo transport vehicle.
9. **Bus**: Public transport transit vehicle.
10. **Motorcycle**: Fast-moving two-wheeled vehicle.
11. **Bicycle**: Non-motorized pedestrian path transit vehicle.
12. **Utility Pole**: Electrical, telephone, or lamppost structures in walking paths.
13. **Curb Edge**: Transition boundary between sidewalk and active roadway.
14. **Pedestrian / Person**: Moving people or bystanders.
15. **Door / Doorway**: Ingress/egress architectural gates and doors.
16. **Window**: Building glass fixtures and panels.
17. **Bench**: Public street seating structures.
18. **Dining Table**: Flat-surface furniture items.
19. **Chair / Sofa**: Household and office seating items.
20. **Trash Bin**: Public waste receptacles on sidewalks.
21. **Puddle / Wet Floor**: Slippery hazards or sidewalk potholes filled with water.
22. **Tree Branch**: Low-hanging overhead branches or signboards.
23. **Fire / Flame**: Active fires or smoke hazards.
24. **Exposed Wires / Cables**: Hanging utility lines or loose cables.

---

## 4. The 80 COCO Dataset Classes

These standard classes are loaded from `ssd_labels.txt` / `coco_labels.txt` to run SSD MobileNetV2 inference:

1. person
2. bicycle
3. car
4. motorcycle
5. airplane
6. bus
7. train
8. truck
9. boat
10. traffic light
11. fire hydrant
12. stop sign
13. parking meter
14. bench
15. bird
16. cat
17. dog
18. horse
19. sheep
20. cow
21. elephant
22. bear
23. zebra
24. giraffe
25. backpack
26. umbrella
27. handbag
28. tie
29. suitcase
30. frisbee
31. skis
32. snowboard
33. sports ball
34. kite
35. baseball bat
36. baseball glove
37. skateboard
38. surfboard
39. tennis racket
40. bottle
41. wine glass
42. cup
43. fork
44. knife
45. spoon
46. bowl
47. banana
48. apple
49. sandwich
50. orange
51. broccoli
52. carrot
53. hot dog
54. pizza
55. donut
56. cake
57. chair
58. couch
59. potted plant
60. bed
61. dining table
62. toilet
63. tv
64. laptop
65. mouse
66. remote
67. keyboard
68. cell phone
69. microwave
70. oven
71. toaster
72. sink
73. refrigerator
74. book
75. clock
76. vase
77. scissors
78. teddy bear
79. hair drier
80. toothbrush

---

## 5. Google ML Kit Image Labeler Categories (400+ Classes)

The default on-device Google ML Kit Image Labeling model categorizes images into over 400 groups. This model categorizes entities across standard domains:

### Core Taxonomic Groups
- **Common Animals & Pets**: Cat, Dog, Bird, Horse, Rabbit, Elephant, Squirrel, Fish, Insect, etc.
- **Household Furniture & Decor**: Bed, Couch, Stool, Table, Chair, Desk, Cabinet, Drawer, Pillow, Vase, Clock, Lamp, Curtain, Rug.
- **Electronic Devices & Accessories**: Laptop, Computer, Monitor, Screen, Keyboard, Mouse, Telephone, Mobile Phone, Cable, Camera, Headphone, Speaker.
- **Kitchenware & Food**: Bottle, Cup, Wine glass, Mug, Fork, Knife, Spoon, Bowl, Plate, Oven, Stove, Microwave, Refrigerator, Bread, Apple, Banana, Pizza, Cake.
- **Outdoor Environment & Nature**: Trees, Grass, Plant, Flower, Scenery, Sky, Cloud, Sun, Mountain, Beach, Water, River, Sidewalk, Street, Path.
- **Vehicles & Infrastructure**: Automobile, Bus, Bicycle, Truck, Scooter, Train, Airplane, Station, Building, Wall, Pillar, Door, Window, Bridge, Roof.
- **Office & Stationary**: Book, Paper, Pen, Pencil, Notebook, Scissors, Backpack, Suitcase, Envelope.
- **Apparel & Sports Gear**: Clothing, Shoes, Hat, Tie, Bag, Watch, Umbrella, Ball, Racket, Skateboard, Surfboard, Kite.

### On-Device Label Refinement Mapping
To prevent speech navigation clutter and unify vocabulary, EasyLens passes raw label strings through `_refineLabel()`:

| Raw Label | Refined Label | Category |
|---|---|---|
| `musical instrument` / `piano` / `electronic keyboard` | `laptop or keyboard` | Electronic/Input |
| `partition` / `divider` | `wall` | Architectural |
| `doorway` / `entrance` | `door` | Architectural |
| `stool` / `armchair` / `sofa` / `couch` | `chair` | Seating |
| `desk` / `tabletop` / `countertop` | `table` | Surfaces |
| `computer` / `screen` / `monitor` / `laptop` | `laptop or computer screen` | Display |
| `bottle` / `cup` / `mug` / `glass` / `tableware` | `cup or tableware` | Dining |
| `human` / `man` / `woman` / `child` / `pedestrian` / `bystander` / `people` | `person` | Obstacle/Target |
| `hand` / `face` / `finger` / `eye` / `hair` / `body` / `selfie` / `portrait` | `person` | Obstacle/Target |
| `hair dryer` / `hairdryer` | `hair drier` | Personal appliance |
