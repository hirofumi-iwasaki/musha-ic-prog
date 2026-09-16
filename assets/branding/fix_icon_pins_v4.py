from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
src=Path('/Users/hirofumiiwasaki/.codex/generated_images/01a0a786-83ba-7942-a76a-ac588e3ee055/exec-77b24aef-13c4-4a37-89e4-c6d647a00ad4.png')
im=Image.open(src).convert('RGBA')
print(im.size)
# Retain original metallic pin texture; replace only the narrow rear-pin strip.
base=im.copy()
old=[203,274,345,416,487,557,627,696,766,837,908,981,1052]
for x in old:
    box=(x-23,695,x+24,729)
    patch=im.crop((x-23,661,x+24,695))
    mask=Image.new('L',patch.size,255)
    # feather the lateral and top seams; the white package rim hides the lower seam
    d=ImageDraw.Draw(mask)
    for j in range(3):
        v=int(255*(j+1)/4)
        d.line((j,0,j,33),fill=v); d.line((46-j,0,46-j,33),fill=v)
        d.line((0,j,46,j),fill=v)
    base.paste(patch,box[:2],mask)
# Reuse the center pin's silver face, with its original bevel and texture.
pin=im.crop((613,700,642,729))
mask=Image.new('L',pin.size,0)
d=ImageDraw.Draw(mask); d.polygon([(2,1),(26,1),(28,4),(28,28),(0,28),(0,4)],fill=255)
mask=mask.filter(ImageFilter.GaussianBlur(.45))
centers=[138+(206+i*(872/11)-122)*(969/1008) for i in range(12)]
for x in centers:
    left=round(x-14)
    shadow=Image.new('RGBA',im.size)
    sd=ImageDraw.Draw(shadow); sd.rounded_rectangle((left-2,699,left+32,730),radius=3,fill=(20,16,12,120))
    shadow=shadow.filter(ImageFilter.GaussianBlur(1.2))
    # Clip shadow above package rim.
    shadow.paste((0,0,0,0),(0,729,im.width,im.height))
    base=Image.alpha_composite(base,shadow)
    base.paste(pin,(left,700),mask)
# Preserve source alpha exactly.
base.putalpha(im.getchannel('A'))
out=Path('/tmp/mushagaeshi-ic-programmer-icon-v4.png'); base.save(out)
print('Upper pin centers:',centers)
