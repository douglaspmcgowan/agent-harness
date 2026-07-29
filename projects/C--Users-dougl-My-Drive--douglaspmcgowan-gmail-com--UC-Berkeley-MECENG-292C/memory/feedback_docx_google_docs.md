---
name: DOCX Google Docs compatibility
description: How to generate Word docs that render correctly in Google Docs — table widths, library quirks, and workarounds
type: feedback
---

Google Docs ignores cell-level width properties (`WidthType.PERCENTAGE` and `WidthType.DXA` on individual `TableCell` objects) from the Node.js `docx` library. Tables render with all columns squished to minimum content width.

**Fix:** Use `columnWidths` on the `Table` object itself, which generates `<w:tblGrid><w:gridCol w:w="..."/>` XML elements — the only width mechanism Google Docs respects.

```js
new Table({
  width: { size: 9360, type: WidthType.DXA },  // 6.5" = 9360 twips
  columnWidths: [2808, 1123, 5429],              // twips per column
  rows: [...]
})
```

**Why:** Google Docs reads `tblGrid/gridCol` for column sizing. It ignores `tcPr/tcW` (cell widths) and `tblPr/tblW` percentage widths.

**How to apply:** Always set `columnWidths` as an array of DXA (twip) values. Convert from percentages: `Math.round(9360 * pct / 100)`. Never rely on cell-level widths or auto-layout for Google Docs output. Also set table `width` to `{ size: 9360, type: WidthType.DXA }` (not percentage).
