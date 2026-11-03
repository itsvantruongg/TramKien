import os
import glob
import subprocess
import xml.etree.ElementTree as ET
from PIL import Image

def android_color_to_svg(c):
    if not c:
        return 'none'
    c = c.strip()
    if c.startswith('#'):
        if len(c) == 9:  # #AARRGGBB
            a = int(c[1:3], 16) / 255.0
            r = int(c[3:5], 16)
            g = int(c[5:7], 16)
            b = int(c[7:9], 16)
            return f'rgba({r},{g},{b},{a:.3f})'
        elif len(c) == 7:  # #RRGGBB
            return c
    return c

def vector_to_svg(xml_path, scale=2.5):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    vw = float(root.attrib.get('{http://schemas.android.com/apk/res/android}viewportWidth', '100'))
    vh = float(root.attrib.get('{http://schemas.android.com/apk/res/android}viewportHeight', '100'))
    
    width = int(round(vw * scale))
    height = int(round(vh * scale))
    
    paths = []
    for elem in root.findall('.//path'):
        d = elem.attrib.get('{http://schemas.android.com/apk/res/android}pathData', '')
        fill = android_color_to_svg(elem.attrib.get('{http://schemas.android.com/apk/res/android}fillColor', ''))
        stroke = android_color_to_svg(elem.attrib.get('{http://schemas.android.com/apk/res/android}strokeColor', ''))
        stroke_w = elem.attrib.get('{http://schemas.android.com/apk/res/android}strokeWidth', '')
        
        attrs = [f'd="{d}"']
        if fill != 'none':
            attrs.append(f'fill="{fill}"')
        else:
            attrs.append('fill="none"')
        if stroke != 'none':
            attrs.append(f'stroke="{stroke}"')
            if stroke_w:
                try:
                    sw = float(stroke_w) * scale
                    attrs.append(f'stroke-width="{sw}"')
                except ValueError:
                    attrs.append(f'stroke-width="{stroke_w}"')
        paths.append(f'  <path {" ".join(attrs)} />')
        
    svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {vw} {vh}">\n''' + "\n".join(paths) + "\n</svg>"
    return svg_content, width, height

def export_all():
    xml_dir = 'android/app/src/main/res/drawable'
    out_dir = 'android/app/src/main/res/drawable-nodpi'
    os.makedirs(out_dir, exist_ok=True)
    temp_dir = 'build/temp_preview_svg'
    os.makedirs(temp_dir, exist_ok=True)
    
    chrome_path = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
    
    xml_files = glob.glob(os.path.join(xml_dir, 'widget_preview_*.xml'))
    print(f"Found {len(xml_files)} vector preview files.")
    
    for xml_path in xml_files:
        base_name = os.path.splitext(os.path.basename(xml_path))[0]
        svg_content, w, h = vector_to_svg(xml_path, scale=2.5)
        
        svg_path = os.path.join(temp_dir, f"{base_name}.svg")
        with open(svg_path, 'w', encoding='utf-8') as f:
            f.write(svg_content)
            
        html_path = os.path.join(temp_dir, f"{base_name}.html")
        html_content = f'''<!DOCTYPE html>
<html>
<head>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{ width: {w}px; height: {h}px; background: transparent; overflow: hidden; }}
  img {{ width: {w}px; height: {h}px; display: block; }}
</style>
</head>
<body>
  <img src="{base_name}.svg" />
</body>
</html>'''
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
            
        temp_png = os.path.join(temp_dir, f"{base_name}.png")
        cmd = [
            chrome_path,
            '--headless',
            f'--screenshot={os.path.abspath(temp_png)}',
            f'--window-size={w},{h}',
            '--default-background-color=00000000',
            os.path.abspath(html_path)
        ]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Convert PNG to WebP with Pillow
        webp_path = os.path.join(out_dir, f"{base_name}.webp")
        with Image.open(temp_png) as img:
            img.save(webp_path, 'WEBP', quality=95, method=6)
            
        print(f"[OK] Generated {base_name}.webp ({w}x{h}) -> {os.path.getsize(webp_path)} bytes")

if __name__ == '__main__':
    export_all()
