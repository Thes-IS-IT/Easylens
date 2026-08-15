# MIT License

**Copyright (c) 2026 Graciella Mhervie D. Jimenez, Jian Kalel D. Marquez, Arron Kian M. Parejas, Jenica Sarah B. Tongol**  
**Holy Angel University (HAU) — School of Computing**  
**Project Repository: [Thes-IS-IT/Easylens](https://github.com/Thes-IS-IT/Easylens)**

---

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## 🎓 Academic Thesis Context & Authorship

**EasyLens** was designed, conceptualized, and engineered as an undergraduate capstone thesis project in partial fulfillment of the requirements for the degree of **Bachelor of Science in Computer Science (BSCS)** at **Holy Angel University (HAU)**, School of Computing, Angeles City, Pampanga, Philippines.

### Research & Engineering Team (Thes-IS-IT)

| Researcher / Author | Role / Area of Focus | Academic Program |
|---|---|---|
| **Graciella Mhervie D. Jimenez** | Research Co-Author & Development Team | Bachelor of Science in Computer Science |
| **Jian Kalel D. Marquez** | Research Co-Author & Development Team & Hardware Engineering | Bachelor of Science in Computer Science |
| **Arron Kian M. Parejas** | Lead Software Architect & AI/Machine Learning Engineer | Bachelor of Science in Computer Science |
| **Jenica Sarah B. Tongol** | Research Co-Author & Development Team | Bachelor of Science in Computer Science |

- **Institution:** Holy Angel University (HAU)
- **Academic Unit:** School of Computing
- **Academic Program:** Bachelor of Science in Computer Science (BSCS)
- **Location:** #1 Holy Angel Avenue, Sto. Rosario, Angeles City, Pampanga 2009, Philippines
- **Repository Organization:** [Thes-IS-IT/Easylens](https://github.com/Thes-IS-IT/Easylens)

---

## 📑 Citation & Academic Attribution

If you use this software, its underlying fine-tuned machine learning models, datasets, architectural designs, algorithms, or documentation in academic coursework, scholarly papers, research publications, or derived software, please provide appropriate academic attribution and cite this work as follows:

### BibTeX Format

```bibtex
@misc{easylens2026thesis,
  author       = {Jimenez, Graciella Mhervie D. and Marquez, Jian Kalel D. and Parejas, Arron Kian M. and Tongol, Jenica Sarah B.},
  title        = {EasyLens: Real-Time Edge Computer Vision and Multimodal AI Assistive System for Visually Impaired Spatial Navigation},
  year         = {2026},
  school       = {Holy Angel University, School of Computing},
  type         = {Undergraduate Thesis},
  address      = {Angeles City, Pampanga, Philippines},
  publisher    = {GitHub},
  howpublished = {\url{https://github.com/Thes-IS-IT/Easylens}}
}
```

### APA Format

> Jimenez, G. M. D., Marquez, J. K. D., Parejas, A. K. M., & Tongol, J. S. B. (2026). *EasyLens: Real-Time Edge Computer Vision and Multimodal AI Assistive System for Visually Impaired Spatial Navigation* (Undergraduate Thesis). School of Computing, Holy Angel University, Angeles City, Pampanga, Philippines. https://github.com/Thes-IS-IT/Easylens

---

## 📜 Thesis Research Terms & Intellectual Property Guidelines

1. **Open Academic & Educational Use:**
   This project is released under the permissive MIT License to foster accessibility research, open-source assistive technology innovation, and educational replication. Academic institutions and researchers are freely encouraged to fork, reproduce, and build upon this work.

2. **Derivative Works & Model Weight Attribution:**
   Any derivative works incorporating the custom 4-phase fine-tuned MobileNetV2 SSD weights (`assets/models/`), 24-class curated dataset annotations, Buddy RAG knowledge base (`assets/models/buddy_knowledge.json`), or ESP32-CAM firmware (`hardware/esp32_cam_wifi_ap/`) must retain the original copyright notice and cite the research authors above.

3. **Data Privacy & Ethical Use:**
   In adherence to user privacy and ethical computer vision guidelines, all sample datasets and facial recognition vectors provided in this repository are strictly synthetic or collected with explicit research consent. Users of this codebase must uphold strict data privacy standards and comply with the **Data Privacy Act of 2012 (Republic Act No. 10173)** of the Philippines and applicable global data protection laws.

4. **Commercial Use Disclosure:**
   While the MIT License permits commercial utilization of the source code, commercial entities utilizing this architecture or trained weights are encouraged to credit the original research team and contribute accessibility enhancements back to the open-source community.

---

## ⚠️ Assistive Technology & Navigation Safety Disclaimer

> **CRITICAL NOTICE:** EasyLens is an experimental academic prototype and assistive visual aid designed to augment spatial awareness. It is **NOT** a certified medical device, an autonomous navigation tool, or a primary replacement for traditional mobility aids such as white canes, certified guide dogs, tactile walking surface indicators, or trained human orientation and mobility (O&M) specialists.
>
> - **Environmental Awareness:** Users must always maintain situational awareness, listen to ambient environmental auditory cues, and adhere to local pedestrian traffic regulations.
> - **Algorithmic Limitations:** Computer vision inference (object detection, depth approximation, OCR) and large language model (LLM) responses may be subject to false positives, latency fluctuations, varying illumination conditions, camera lens obstructions, or generative hallucinations.
> - **Limitation of Liability:** Under no circumstances shall the research authors, advisers, or Holy Angel University be held liable for any direct, indirect, incidental, special, consequential, or punitive damages, personal injuries, or property damage arising from the operation of or reliance upon this software or connected hardware.

---

## 🤝 Third-Party Software & Dependency Acknowledgments

EasyLens is built upon and integrates world-class open-source frameworks, machine learning models, and cloud infrastructure:

| Component / Library | Vendor / Author | License | Description |
|---|---|---|---|
| **Flutter SDK** | Google LLC | BSD 3-Clause | Cross-platform mobile application framework |
| **Dart SDK** | Google LLC | BSD 3-Clause | Application programming language and runtime |
| **TensorFlow Lite & MobileNetV2** | Google LLC | Apache 2.0 | On-device lightweight neural network runtime |
| **Google Gemma 2B (Gemma-IT)** | Google LLC | Gemma Terms of Use & Apache 2.0 | On-device instruction-tuned large language model |
| **Google Generative AI (Gemini Flash)** | Google LLC | Apache 2.0 | Multimodal cloud conversational reasoning |
| **Google ML Kit (Vision SDKs)** | Google LLC | Android Software SDK / Apache 2.0 | Text OCR, Image Labeling, Face Detection |
| **Firebase Auth & Firestore** | Google LLC | Apache 2.0 | User authentication and real-time database |
| **Cloudflare D1 & R2** | Cloudflare, Inc. | Terms of Service & S3 API | Serverless SQL and S3-compatible object storage |
| **ESP32 Arduino Core** | Espressif Systems | LGPL v2.1 | Firmware runtime for ESP32-CAM smart glasses |
| **Flutter Community Packages** | Open Source Contributors | MIT / BSD / Apache 2.0 | `provider`, `flutter_tts`, `speech_to_text`, `geolocator`, `sensors_plus`, `audioplayers`, `wakelock_plus` |

---

## 📬 Contact & Research Inquiries

For academic inquiries, thesis manuscript access, dataset questions, or collaboration proposals:

- **Lead Software Architect & AI Engineer:** Arron Kian M. Parejas ([arronkianparejas@gmail.com](mailto:arronkianparejas@gmail.com))
- **Research Repository:** [https://github.com/Thes-IS-IT/Easylens](https://github.com/Thes-IS-IT/Easylens)
- **Academic Institution:** Holy Angel University — School of Computing, Angeles City, Pampanga, Philippines
