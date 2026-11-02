import io, sys, os

src = sys.argv[1]
dst = sys.argv[2]
b = open(src, 'rb').read()

enc = None
if b[:2] in (b'\xff\xfe', b'\xfe\xff'):
    enc = 'utf-16'
else:
    for e in ('utf-8-sig', 'gbk', 'cp936', 'latin-1'):
        try:
            t = b.decode(e)
            enc = e
            break
        except Exception:
            continue

t = b.decode(enc, errors='replace')
t = t.replace('\r\n', '\n')
io.open(dst, 'w', encoding='utf-8').write(t)

# also record a short diagnostic
with open(dst + '.meta', 'w', encoding='utf-8') as f:
    f.write('encoding=%s bytes=%d chars=%d\n' % (enc, len(b), len(t)))
print('ok', enc, len(t))
