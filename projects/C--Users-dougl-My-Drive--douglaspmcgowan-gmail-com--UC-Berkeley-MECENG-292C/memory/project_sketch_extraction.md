---
name: Sketch extraction process for concept documents
description: Lessons learned from extracting and cropping hand-drawn concept sketches from PDFs and PPTX into a consolidated Word doc
type: project
---

Consolidated 40 team concept sketches (Apolline, Madison Lu, Elisa Lupin-Jimenez, Douglas McGowan) from PDFs and PPTX into a single Word doc with cropped sketch images.

**Key challenges:**
- PDF pages have 2 concepts each (top/bottom), sketch boxes on the right side with description text on the left
- Each person's pages have different dimensions and layouts
- Apolline's pages have category headers ("office activity", "workload", etc.) that shift content down
- Elisa's pages are very high resolution with varying dimensions per page
- Madison's sketches are faint pencil — source material limitation
- Douglas's concepts are in PPTX with separate image files per slide

**What worked:**
- Border detection (finding vertical dark lines) to locate sketch box left edge precisely, rather than fixed percentage crops
- Auto-trimming whitespace after cropping with PIL/numpy
- Standardizing all images to uniform 800x700 before inserting into doc — ensures perfect alignment
- Using docx2pdf + pdftoppm to visually inspect the final document before declaring done

**Why:** User needed a clean, professional concept doc for MECENG 292C class with all team sketches lined up uniformly.

**How to apply:** For future sketch/image extraction from PDFs, use border detection rather than hardcoded pixel coordinates. Always standardize output image dimensions for uniform layout. Always visually verify final output.
