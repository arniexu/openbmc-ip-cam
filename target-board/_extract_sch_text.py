from pathlib import Path
from pypdf import PdfReader
pdf = Path(r"d:\openbmc-ocp-obmf\target-board\SCH_Schematic1_2025-12-21.pdf")
reader = PdfReader(str(pdf))
print(f"PAGES={len(reader.pages)}")
out = Path(r"d:\openbmc-ocp-obmf\target-board\SCH_Schematic1_2025-12-21.txt")
with out.open('w', encoding='utf-8', errors='ignore') as f:
    for i, p in enumerate(reader.pages, 1):
        t = p.extract_text() or ""
        f.write(f"\n===== PAGE {i} =====\n")
        f.write(t)
print(out)
