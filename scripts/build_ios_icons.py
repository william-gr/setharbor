"""Rasterize the existing rectangular Android vector paths as opaque iOS icons.

No new artwork or external image dependency. Generated assets are versioned.
"""
import json
import re
import struct
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def chunk(kind, content):
    return struct.pack('>I',len(content)) + kind + content + struct.pack('>I',zlib.crc32(kind+content)&0xffffffff)

def build():
    ns = '{http://schemas.android.com/apk/res/android}'
    vector = ET.parse(ROOT / 'app/src/main/res/drawable/icon.xml').getroot()
    width = float(vector.get(ns+'viewportWidth'))
    rectangles = []
    for path in vector:
        color = bytes.fromhex(path.get(ns+'fillColor').lstrip('#'))
        for match in re.finditer(r'M([\d.]+),([\d.]+)h([\d.]+)v([\d.]+)h-[\d.]+z',path.get(ns+'pathData')):
            x,y,w,h=map(float,match.groups());rectangles.append((x,y,x+w,y+h,color))
    if len(rectangles)!=6:
        raise ValueError('Icon vector changed: update the rasterizer')
    output=ROOT/'flutter_app/ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for image in json.loads((output/'Contents.json').read_text())['images']:
        size=round(float(image['size'].split('x')[0])*float(image['scale'].removesuffix('x')))
        scanlines=bytearray()
        for row in range(size):
            scanlines.append(0)
            for col in range(size):
                x,y=(col+.5)/size*width,(row+.5)/size*width
                pixel=bytes.fromhex('101820')
                for left,top,right,bottom,color in rectangles:
                    if left<=x<right and top<=y<bottom:pixel=color
                scanlines.extend(pixel)
        png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(scanlines))+chunk(b'IEND',b'')
        (output/image['filename']).write_bytes(png)
if __name__=='__main__':build()
