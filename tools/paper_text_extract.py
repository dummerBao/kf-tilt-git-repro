import sys
from pypdf import PdfReader

src = r"D:\2.工作资料\论文研究\倾角研究\2609.00730v2.pdf"
dst = r"D:\2.工作资料\论文研究\倾角研究\_paper_text.txt"

r = PdfReader(src)
n = len(r.pages)
out = []
for i, p in enumerate(r.pages):
    t = p.extract_text() or ""
    out.append("\n\n========== PAGE %d / %d ==========\n" % (i + 1, n) + t)

with open(dst, "w", encoding="utf-8") as f:
    f.write("".join(out))

print("pages:", n)
print("chars:", sum(len(x) for x in out))
