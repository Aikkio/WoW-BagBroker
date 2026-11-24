# Генерирует белые глифы для BagBroker (тонируются в игре через SetVertexColor).
import sys, os
from PIL import Image, ImageDraw

# Запуск: python tools/make_icons.py BagBroker/media tools
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
S = 64          # итоговый размер
K = 8           # суперсэмплинг
W = S * K

def canvas():
    return Image.new("L", (W, W), 0)

def save(mask, name):
    small = mask.resize((S, S), Image.LANCZOS)
    img = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    img.putalpha(small)
    img.save(os.path.join(OUT, name + ".tga"))

def p(x, y):
    return (x * K, y * K)

# Щит: геральдический, с толстым контуром и центральной гранью.
def shield(filled_half=True):
    m = canvas(); d = ImageDraw.Draw(m)
    outer = [p(32, 6), p(53, 13), p(53, 30), p(50, 41), p(42, 51), p(32, 58), p(22, 51), p(14, 41), p(11, 30), p(11, 13)]
    inner = [p(32, 12.5), p(47.5, 17.5), p(47.5, 30), p(45, 39), p(38.5, 47), p(32, 51.5), p(25.5, 47), p(19, 39), p(16.5, 30), p(16.5, 17.5)]
    d.polygon(outer, fill=255)
    d.polygon(inner, fill=0)
    if filled_half:
        # левая половина залита — классический «рассечённый» щит
        half = [p(32, 12.5), p(32, 51.5), p(25.5, 47), p(19, 39), p(16.5, 30), p(16.5, 17.5)]
        d.polygon(half, fill=255)
    return m

def trash():
    m = canvas(); d = ImageDraw.Draw(m)
    # крышка и ручка
    d.rounded_rectangle([p(12, 14), p(52, 19)], radius=1.5 * K, fill=255)
    d.rounded_rectangle([p(25, 8), p(39, 14)], radius=2 * K, fill=255)
    d.rounded_rectangle([p(28.5, 10.5), p(35.5, 14)], radius=1 * K, fill=0)
    # корпус
    d.polygon([p(15.5, 22), p(48.5, 22), p(45.5, 56), p(18.5, 56)], fill=255)
    d.polygon([p(20, 26), p(44, 26), p(41.8, 52), p(22.2, 52)], fill=0)
    # рёбра
    for x in (27, 32, 37):
        d.rounded_rectangle([p(x - 1.4, 29), p(x + 1.4, 49)], radius=1 * K, fill=255)
    return m

def undo():
    m = canvas(); d = ImageDraw.Draw(m)
    # дуга
    d.arc([p(14, 16), p(54, 54)], start=200, end=90, fill=255, width=6 * K)
    # хвостик дуги до низа
    d.rounded_rectangle([p(26, 48), p(34, 54)], radius=1 * K, fill=255)
    # наконечник стрелки слева сверху
    d.polygon([p(4, 26), p(22, 12), p(24, 38)], fill=255)
    return m

def chevron(direction):
    m = canvas(); d = ImageDraw.Draw(m)
    if direction == "down":
        d.line([p(16, 24), p(32, 40), p(48, 24)], fill=255, width=7 * K, joint="curve")
    elif direction == "left":
        d.line([p(40, 16), p(24, 32), p(40, 48)], fill=255, width=7 * K, joint="curve")
    else:
        d.line([p(24, 16), p(40, 32), p(24, 48)], fill=255, width=7 * K, joint="curve")
    return m

save(shield(), "shield")
save(trash(), "trash")
save(undo(), "undo")
save(chevron("down"), "chevron_down")
save(chevron("left"), "chevron_left")
save(chevron("right"), "chevron_right")

# Превью для проверки глазами.
prev = Image.new("RGBA", (S * 6 + 70, S + 20), (20, 20, 22, 255))
for i, n in enumerate(["shield", "trash", "undo", "chevron_down", "chevron_left", "chevron_right"]):
    ic = Image.open(os.path.join(OUT, n + ".tga"))
    tint = Image.new("RGBA", ic.size, (212, 168, 106, 255))
    tint.putalpha(ic.getchannel("A"))
    prev.alpha_composite(tint, (10 + i * (S + 10), 10))
prev.save(os.path.join(sys.argv[2], "icons_preview.png"))
print("ok")
