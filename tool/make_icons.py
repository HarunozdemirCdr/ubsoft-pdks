"""UBSoft PDKS uygulama ikonlarını üretir.

Mark: lacivert zemin üzerinde üç beyaz QR köşe kutusu + sağ altta dolu blok.
16 px'te bile "QR" olarak okunur; devriye ürününün ikonuyla karışmaz.
"""
from PIL import Image, ImageDraw

VIOLET = (30, 58, 138, 255)   # #1E3A8A (lacivert)
WHITE = (255, 255, 255, 255)
SS = 8  # süper örnekleme


def rounded(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def finder(draw, x, y, size, ring, radius_outer, radius_inner):
    """QR köşe kutusu: beyaz kare, ortası zemin rengi, içinde beyaz blok."""
    rounded(draw, (x, y, x + size, y + size), radius_outer, WHITE)
    inset = ring
    rounded(
        draw,
        (x + inset, y + inset, x + size - inset, y + size - inset),
        radius_inner,
        VIOLET,
    )
    core = ring * 2
    rounded(
        draw,
        (x + core, y + core, x + size - core, y + size - core),
        max(2, radius_inner // 2),
        WHITE,
    )


def draw_mark(img_size, pad_ratio, corner_ratio):
    """pad_ratio: markın kenardan boşluğu (maskable için daha büyük)."""
    n = img_size * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Zemin
    rounded(d, (0, 0, n, n), int(n * corner_ratio), VIOLET)

    pad = int(n * pad_ratio)
    inner = n - pad * 2
    cell = inner / 7.0            # 7×7 QR ızgarası
    box = int(cell * 3)           # köşe kutusu 3×3 hücre
    ring = max(SS, int(cell * 0.62))
    r_out = int(cell * 0.55)
    r_in = int(cell * 0.30)

    finder(d, pad, pad, box, ring, r_out, r_in)
    finder(d, n - pad - box, pad, box, ring, r_out, r_in)
    finder(d, pad, n - pad - box, box, ring, r_out, r_in)

    # Sağ altta dolu blok: "veri" bölgesi. Köşe kutularıyla dengeyi kurar.
    bx = n - pad - int(cell * 2.2)
    by = n - pad - int(cell * 2.2)
    rounded(d, (bx, by, bx + int(cell * 2.2), by + int(cell * 2.2)),
            int(cell * 0.35), WHITE)

    return img.resize((img_size, img_size), Image.LANCZOS)


targets = [
    ('web/favicon.png', 64, 0.16, 0.20),
    ('web/icons/Icon-192.png', 192, 0.16, 0.20),
    ('web/icons/Icon-512.png', 512, 0.16, 0.20),
    # Maskable: içerik ortadaki güvenli alanda kalmalı, zemin taşar.
    ('web/icons/Icon-maskable-192.png', 192, 0.26, 0.0),
    ('web/icons/Icon-maskable-512.png', 512, 0.26, 0.0),
]

for path, size, pad, corner in targets:
    draw_mark(size, pad, corner).save(path)
    print('yazildi:', path, size)
