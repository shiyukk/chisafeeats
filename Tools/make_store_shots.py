#!/usr/bin/env python3
"""Compose App Store marketing screenshots (1320x2868) — flat, minimal style
(like ChatGPT / Claude / Gemini store pages): plain light background, a big
system-font headline, and the full screenshot below with a small corner
radius and hairline border. Raw captures live in AppStore/raw/ (u-*.png are
hand-taken in the simulator). Re-run after UI changes:

    python3 Tools/make_store_shots.py
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

W, H = 1320, 2868
RAW, OUT = "AppStore/raw", "AppStore/screenshots"

BG = (250, 250, 248)
INK = (17, 17, 17)
BORDER = (224, 224, 220)

EN_FONT = "/System/Library/Fonts/SFNS.ttf"                 # variable SF Pro
# Real PingFang SC lives in the font-asset store (not /System/Library/Fonts);
# index 11 = SC Semibold, 3 = SC Regular. Fallback: Hiragino Sans GB.
ZH_FONT = ("/System/Library/AssetsV2/com_apple_MobileAsset_Font7/"
           "3419f2a427639ad8c8e139149a287865a90fa17e.asset/AssetData/PingFang.ttc")
ZH_FALLBACK = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def font(locale, size, bold=True):
    if locale == "zh-Hans":
        try:
            return ImageFont.truetype(ZH_FONT, size, index=11 if bold else 3)
        except OSError:
            return ImageFont.truetype(ZH_FALLBACK, size, index=1 if bold else 0)
    f = ImageFont.truetype(EN_FONT, size)
    try:
        # Medium, not Bold — the quieter headline weight ChatGPT/Claude use.
        f.set_variation_by_name("Medium" if bold else "Regular")
    except OSError:
        pass
    return f


def canvas():
    return Image.new("RGBA", (W, H), BG + (255,))


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def card_paste(cv, img, xy, radius):
    """Subtle shadow + hairline border + small corner radius."""
    sh = Image.new("RGBA", cv.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [xy[0], xy[1] + 10, xy[0] + img.size[0], xy[1] + img.size[1] + 10],
        radius, fill=(0, 0, 0, 40))
    cv.alpha_composite(sh.filter(ImageFilter.GaussianBlur(24)))
    cv.alpha_composite(rounded(img, radius), xy)
    ImageDraw.Draw(cv).rounded_rectangle(
        [xy[0], xy[1], xy[0] + img.size[0], xy[1] + img.size[1]],
        radius, outline=BORDER, width=2)


def title(cv, locale, text, y=170, size=100):
    d = ImageDraw.Draw(cv)
    f = font(locale, size)
    # Auto-shrink long lines so they keep comfortable side margins.
    while d.textlength(text, font=f) > W - 140 and size > 60:
        size -= 4
        f = font(locale, size)
    d.text(((W - d.textlength(text, font=f)) / 2, y), text, font=f, fill=INK)


def shot_img(name, width):
    img = Image.open(f"{RAW}/{name}.png")
    return img.resize((width, int(img.size[1] * width / img.size[0])), Image.LANCZOS)


def layout_shot(locale, raw_name, text, icon=False):
    """Measured from ChatGPT's actual store card: headline ~9% from the top,
    phone ~74% wide in a white rounded bezel, bottom margin ~5%."""
    cv = canvas()
    title(cv, locale, text, y=250, size=104)
    img = shot_img(raw_name, 980)
    bez = 24
    frame = Image.new("RGBA", (img.size[0] + bez * 2, img.size[1] + bez * 2), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        [0, 0, frame.size[0] - 1, frame.size[1] - 1], 132, fill=(255, 255, 255, 255))
    frame.alpha_composite(rounded(img, 108), (bez, bez))
    # soft drop shadow
    sh = Image.new("RGBA", cv.size, (0, 0, 0, 0))
    x0 = (W - frame.size[0]) // 2
    y0 = 560
    ImageDraw.Draw(sh).rounded_rectangle(
        [x0, y0 + 16, x0 + frame.size[0], y0 + frame.size[1] + 16], 132, fill=(0, 0, 0, 45))
    cv.alpha_composite(sh.filter(ImageFilter.GaussianBlur(36)))
    cv.alpha_composite(rounded(frame, 132), (x0, y0))
    return cv


def layout_langgrid(locale, raw_names, text):
    """All-languages collage: the verdict card cropped from each language's
    screenshot, tiled 2 x 5 to fill the canvas — every cell readable."""
    cv = canvas()
    title(cv, locale, text)
    box = (36, 1300, 1284, 2240)            # sheet header + verdict card
    cols, gap = 2, 16
    cw = (W - 32 * 2 - gap) // cols          # 32px side margins
    ch = int((box[3] - box[1]) * cw / (box[2] - box[0]))
    y0 = 340
    for i, name in enumerate(raw_names):
        crop = Image.open(f"{RAW}/{name}.png").crop(box)
        crop = crop.resize((cw, ch), Image.LANCZOS)
        x = 32 + (i % cols) * (cw + gap)
        y = y0 + (i // cols) * (ch + gap)
        card_paste(cv, crop, (x, y), 28)
    return cv


CAPTIONS = {
    "zh-Hans": {
        1: "轻松查阅芝加哥食品安全",
        2: "覆盖芝加哥全城",
        3: "精准搜索餐厅卫生评分",
        4: "全面解析官方检查报告",
        5: "各项卫生指标全面掌控",
        6: "历年检查记录完整追溯",
        7: "多维筛选精准锁定好店",
        8: "评语自动翻成中文",
        9: "夜间模式",
    },
    "en-US": {
        1: "Check before you order",
        2: "40,000 places citywide",
        3: "Search with scores",
        4: "Scores at a glance",
        5: "Reports in plain language",
        6: "Past issues, visible",
        7: "Filter what matters",
        8: "Auto-translated comments",
        9: "Dark mode",
        10: "10 languages",
    },
}

# slot -> raw file per locale (full screenshots, hand-captured)
SOURCES = {
    "zh-Hans": {1: "u-pills-zh", 2: "u-city-zh", 3: "u-search-zh", 4: "u-select-zh",
                5: "u-health-zh", 6: "u-history-zh", 7: "u-filter-zh",
                8: "u-report-zh", 9: "u-dark-zh"},
    "en-US":   {1: "u-pills", 2: "u-city-en", 3: "u-search-en", 4: "u-select-en",
                5: "u-health-en", 6: "u-past-en", 7: "u-filter-en",
                9: "u-dark-en"},   # no translation shot (8) for English
}


def build(locale):
    c, src = CAPTIONS[locale], SOURCES[locale]
    out = f"{OUT}/{locale}"
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png"):
            os.remove(f"{out}/{f}")
    seq = 0
    for n in sorted(src):
        seq += 1
        layout_shot(locale, src[n], c[n]).convert("RGB").save(f"{out}/{seq:02d}.png")
    print(f"{locale}: {seq} shots -> {out}/")


for locale in ["zh-Hans", "en-US"]:
    build(locale)
