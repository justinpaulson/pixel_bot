#!/usr/bin/env python3
"""Pixel's 34-second trailer. All animation and music are reproducible locally.

Requires ffmpeg, rsvg-convert, Pillow, NumPy and SciPy. No stock soundtrack,
remote rendering service, browser automation or paid assets are used.
"""
from pathlib import Path
from functools import lru_cache
import argparse
import math
import subprocess
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.signal import butter, sosfilt

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE / "output"
OUT.mkdir(exist_ok=True)
W, H, FPS, DURATION = 1920, 1080, 30, 34
C = dict(paper="#f0f5f1", ink="#173f40", lake="#167b96", mint="#b9e6d2",
         orange="#ef965e", canvas="#fffdf7", shadow="#d2e1d9", muted="#536c6a")
FONT_DIR = Path("/System/Library/Fonts/Supplemental")
SOURCES = {
    "dino": ROOT / "docs/svg-evaluation/gpt-6-astra.svg",
    "tv": ROOT / "docs/svg-evaluation/tv.svg",
    "music": ROOT / "docs/svg-evaluation/music.svg",
    "stars": HERE / "assets/cher.svg",
    "games": ROOT / "docs/svg-evaluation/games.svg",
    "places": ROOT / "docs/svg-evaluation/places.svg",
    "objects": ROOT / "docs/svg-evaluation/objects.svg",
    "logo": ROOT / "app/assets/images/favicon.svg",
}


def ease(x):
    x = max(0, min(1, x))
    return 1 - (1 - x) ** 3


def pop(x):
    x = max(0, min(1, x))
    return 1 + 2.70158 * (x - 1) ** 3 + 1.70158 * (x - 1) ** 2


@lru_cache(maxsize=128)
def font(size, heavy=True):
    return ImageFont.truetype(str(FONT_DIR / ("Arial Bold.ttf" if heavy else "Arial.ttf")), size)


def txt(im, text, xy, size, color="ink", anchor="lt", heavy=True):
    ImageDraw.Draw(im).text(tuple(map(round, xy)), text, font=font(size, heavy),
                           fill=C.get(color, color), anchor=anchor, spacing=0)


def lines(im, texts, x, y, size=112, gap=118, color="ink", progress=1):
    for i, text in enumerate(texts):
        q = ease(progress - i * .10)
        if q > 0:
            txt(im, text, (x, y + i * gap + 65 * (1-q)), size, color)


def rr(im, box, fill, radius=32, outline=None, width=1):
    ImageDraw.Draw(im).rounded_rectangle(tuple(map(round, box)), radius,
                                         fill=C.get(fill, fill), outline=outline, width=width)


def prep():
    for name, path in SOURCES.items():
        subprocess.run(["rsvg-convert", "-w", "1100", "-h", "1100", str(path),
                        "-o", str(OUT / f"{name}.png")], check=True)


@lru_cache(maxsize=12)
def art(name):
    return Image.open(OUT / f"{name}.png").convert("RGBA")


def place(im, source, xy, size, angle=0, opacity=1):
    if size <= 1:
        return
    tile = source.resize((int(size), int(size)), Image.Resampling.LANCZOS)
    if opacity < 1:
        tile.putalpha(tile.getchannel("A").point(lambda a: int(a*opacity)))
    if angle:
        tile = tile.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    im.paste(tile, (int(xy[0]-tile.width/2), int(xy[1]-tile.height/2)), tile)


def card(im, name, xy, size, angle=0, scale=1, label=None):
    size = max(2, int(size * scale))
    pad = max(10, int(size * .035))
    extra = int(size * .13) if label else 0
    tile = Image.new("RGBA", (size+pad*2, size+pad*2+extra), (0, 0, 0, 0))
    rr(tile, (0, 0, tile.width-1, tile.height-1), "canvas", max(12, size//30))
    resized = art(name).resize((size, size), Image.Resampling.LANCZOS)
    tile.alpha_composite(resized, (pad, pad))
    if label:
        txt(tile, label, (tile.width/2, size+pad+extra/2), max(18, int(size*.065)), anchor="mm")
    if angle:
        tile = tile.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    x, y = int(xy[0]-tile.width/2), int(xy[1]-tile.height/2)
    shadow = Image.new("RGBA", tile.size, (0,0,0,0))
    shadow.putalpha(tile.getchannel("A").point(lambda a: int(a*.10)))
    im.paste(shadow, (x+12,y+18), shadow)
    im.paste(tile, (x,y), tile)


def pill(im, text, xy, fill="mint", fg="ink", size=30):
    f = font(size)
    width = int(f.getlength(text) + 52)
    rr(im, (xy[0], xy[1], xy[0]+width, xy[1]+60), fill, 30)
    txt(im, text, (xy[0]+width/2,xy[1]+30), size, fg, "mm")


def brand(im, x=112, y=70, size=42, light=False):
    place(im, art("logo"), (x+27, y+28), 56)
    txt(im, "pixel", (x+72, y+size+1), size, "canvas" if light else "ink", "ls")
    fw = font(size).getlength("pixel")
    txt(im, ".", (x+72+fw, y+size+1), size, "orange", "ls")


def contours(im, t, dark=False):
    d = ImageDraw.Draw(im)
    color = "#225253" if dark else "#e0ebe4"
    for i in range(6):
        x, y = 1780+math.sin(t*.18)*20, 950
        r = 160 + i*65
        d.ellipse((x-r*1.8,y-r,x+r*1.8,y+r), outline=color, width=3)


def confetti(im, t, origin=(1360,510)):
    d=ImageDraw.Draw(im)
    for i in range(32):
        a=i*2.39996
        r=(140+(i%5)*32)*t
        x=origin[0]+math.cos(a)*r
        y=origin[1]+math.sin(a)*r+t*t*60
        color=C[["orange","mint","lake"][i%3]]
        d.rounded_rectangle((x-7,y-13,x+7,y+13),3,fill=color)


def face(im, x, y, r, color="mint", angle=0):
    d=ImageDraw.Draw(im)
    d.ellipse((x-r,y-r,x+r,y+r),fill=C[color])
    if r < 20:
        return
    for dx in [-r*.28,r*.28]:
        d.ellipse((x+dx-7,y-9,x+dx+7,y+5),fill=C["ink"])
    d.arc((x-r*.32,y+3,x+r*.32,y+r*.45),0,180,fill=C["ink"],width=7)


def scene(t):
    dark = 8 <= t < 12 or 20 <= t < 24 or t >= 28
    im=Image.new("RGB",(W,H),C["ink"] if dark else C["paper"])
    contours(im,t,dark)
    d=ImageDraw.Draw(im)
    if t < 8:
        brand(im)
        pill(im,"MOVIES",(112,235),"mint")
        x=1360+110*(1-ease(t/.55))
        card(im,"dino",(x,540),800,angle=-2+math.sin(t*.8)*.4,scale=.92+.08*ease(t/.55))
        if t < 3:
            lines(im,["Name", "that movie."],112,345,110,125,progress=t/.35)
            txt(im,"An AI drew this.",(116,650),36,"muted",heavy=False)
        elif t < 6:
            lines(im,["15 seconds.","Go."],112,345,105,125,progress=(t-3)/.35)
            n=15-int(t-3)
            rr(im,(116,666,288,826),"lake",36)
            txt(im,str(n),(202,747),85,"canvas","mm")
            d.arc((125,675,279,817),-90,-90+360*(1-(t-3)/15),fill=C["mint"],width=7)
            txt(im,"Got it?",(325,720),48)
        else:
            confetti(im,min(1.4,(t-6)*1.4))
            lines(im,["Jurassic", "Park!"],112,345,110,125,progress=(t-6)/.35)
            pill(im,"NAILED IT.",(116,670),"mint",size=34)
    elif t < 12:
        u=t-8
        brand(im,light=True)
        if u < 2:
            place(im,art("logo"),(1430,540),420*max(.01,pop(u/.7)),angle=-8+8*ease(u/.8))
            lines(im,["Pixel", "draws."],140,330,180,185,"canvas",u/.45)
        else:
            lines(im,["You", "guess."],140,330,180,185,"mint",(u-2)/.45)
            for i,c in enumerate(["orange","mint","lake"]):
                q=ease((u-2-i*.15)/.5)
                rr(im,(1160,300+i*175+120*(1-q),1755,430+i*175+120*(1-q)),c,36)
                txt(im,["a dinosaur?", "a movie?", "Jurassic Park!"][i],(1457,365+i*175+120*(1-q)),42,"ink" if c!="lake" else "canvas","mm")
    elif t < 20:
        cats=[("tv","TV shows.","pineapple.svg"), ("music","Songs.","rocket.svg"),
              ("stars","Pop stars.","spotlight.svg"),("games","Video games.","level-up.svg")]
        j=min(3,int((t-12)/2)); u=(t-12)%2
        name,title,_=cats[j]
        brand(im)
        txt(im,"TAKE YOUR PICK",(115,270),30,"muted")
        lines(im,title.split(" ") if j==3 else [title],112,375,105,125,progress=u/.35)
        card(im,name,(1370+150*(1-ease(u/.5)),540),760,angle=(3 if j%2 else -3)*(1-.25*ease(u/2)))
        for k in range(4):
            rr(im,(115+k*80,800,170+k*80,811),"lake" if k==j else "shadow",6)
    elif t < 24:
        brand(im,light=True)
        u=t-20
        if u < 2:
            lines(im,["Go solo."],130,390,125,140,"canvas",u/.4)
            face(im,1390,520+25*math.sin(u*3),170,"mint")
            txt(im,"?",(1390,810),135,"orange","mm")
        else:
            lines(im,["Bring friends."],130,330,115,140,"canvas",(u-2)/.4)
            txt(im,"Everyone guesses.",(136,515+50*(1-ease((u-2)/.5))),64,"mint")
            for i,c in enumerate(["mint","orange","lake"]):
                q=pop((u-2-i*.13)/.55)
                if q>0:
                    face(im,1210+i*205,570+(-55 if i==1 else 65)+30*(1-q),100*q,c)
    elif t < 28:
        brand(im)
        u=t-24
        txt(im,"New round.",(115,248+45*(1-ease(u/.4))),95)
        txt(im,"New drawing.",(115,360+45*(1-ease((u-.12)/.4))),95,"lake")
        cards=[("objects",(-30,800),370,-9), ("places",(430,840),390,5),
               ("music",(895,785),400,-7),("tv",(1350,780),430,6),("dino",(1800,800),420,-5)]
        for i,(name,xy,size,angle) in enumerate(cards):
            q=ease((u-i*.12)/.65)
            card(im,name,(xy[0],xy[1]+450*(1-q)+8*math.sin(u*1.8+i)),size,angle)
        pill(im,"FRESH AI ART. EVERY TIME.",(1135,290),"mint",size=28)
    else:
        u=t-28
        place(im,art("logo"),(960,265),160*max(.01,pop(u/.65)))
        word_size=175
        txt(im,"pixel",(930,490+35*(1-ease(u/.55))),word_size,"canvas","mm")
        txt(im,".",(1145,490+35*(1-ease(u/.55))),word_size,"orange","mm")
        txt(im,"Pixel draws. You guess.",(960,645),62,"mint","mm")
        q=ease((u-.5)/.5)
        if q:
            rr(im,(445,764+35*(1-q),1475,880+35*(1-q)),"orange",58)
            txt(im,"pixel.justinpaulson.com",(960,822+35*(1-q)),49,"ink","mm")
        # A small arc echoes the playfulness without another decorative logo.
        d.arc((126,250,420,620),65,255,fill=C["lake"],width=12)
        d.arc((1510,405,1810,775),245,435,fill=C["mint"],width=12)
    # Short, continuous directional wipes hide cuts without flashing.
    cuts=[8,10,12,14,16,18,20,22,24,28]
    for cut in cuts:
        dt=t-cut
        if 0 <= dt < .24:
            x=int(W*ease(dt/.24))
            d.rectangle((x,0,W, H),fill=C["lake"] if cut!=20 else C["orange"])
    return im


def soundtrack():
    rate=48000
    mix=np.zeros((rate*DURATION,2),dtype=np.float64)
    rng=np.random.default_rng(20261015)
    def add(sound,start,gain=1,pan=0):
        a=round(start*rate); b=min(len(mix),a+len(sound))
        if a<0 or b<=a:return
        sound=sound[:b-a]*gain
        mix[a:b,0]+=sound*math.sqrt((1-pan)/2)
        mix[a:b,1]+=sound*math.sqrt((1+pan)/2)
    def note(midi,duration=.5,kind="pluck"):
        tt=np.arange(round(rate*duration))/rate
        hz=440*2**((midi-69)/12)
        if kind=="bass":
            wave=np.sin(2*np.pi*hz*tt)+.22*np.sin(4*np.pi*hz*tt)
            env=(1-np.exp(-tt*100))*np.exp(-tt*5)
        else:
            wave=np.sin(2*np.pi*hz*tt)+.3*np.sin(4*np.pi*hz*tt)*np.exp(-tt*8)+.12*np.sin(6*np.pi*hz*tt)*np.exp(-tt*15)
            env=(1-np.exp(-tt*500))*np.exp(-tt*7)
        return wave*env
    def kick():
        tt=np.arange(int(.28*rate))/rate
        hz=45+110*np.exp(-tt*35)
        return np.sin(2*np.pi*np.cumsum(hz)/rate)*np.exp(-tt*16)
    def noise(dur,decay,hp):
        tt=np.arange(int(dur*rate))/rate
        n=sosfilt(butter(2,hp,fs=rate,btype="highpass",output="sos"),rng.normal(size=len(tt)))
        return n*np.exp(-tt*decay)*(1-np.exp(-tt*1000))
    chords=[(48,[72,76,79,83]),(45,[72,76,81,84]),(41,[72,77,81,84]),(43,[71,74,79,83])]
    # 120 BPM; original upbeat mallet melody, warm bass and soft drum groove.
    for bar in range(16):
        start=bar*2
        root,notes=chords[bar%4]
        quiet=.62 if 1<=bar<=2 else 1
        for beat in range(4):
            add(kick(),start+beat*.5,.36*quiet)
            if beat%2: add(noise(.18,25,1500),start+beat*.5,.15*quiet)
            add(note(root+(12 if beat==3 else 0),.45,"bass"),start+beat*.5,.25*quiet)
        for step in range(8):
            add(noise(.07,75,6500),start+step*.25,.065*quiet,(-.35 if step%2 else .35))
        pattern=[0,2,1,3,2,1,3,2] if bar%2==0 else [2,1,0,2,3,2,1,0]
        for step,n in enumerate(pattern):
            if step in [3,6] and bar%2:continue
            signal=note(notes[n]+(12 if bar>=12 and step==7 else 0),.6)
            at=start+step*.25+(.025 if step%2 else 0)
            pan=(-.22 if step%2 else .22)
            add(signal,at,.15*quiet,pan)
            add(signal,at+.18,.027*quiet,-pan)
    # Answer chime, typed-guess taps and transition sweeps.
    for i,n in enumerate([76,79,84]): add(note(n,.9),6+i*.09,.28,(-.2+i*.2))
    for at in [3,4,5]: add(note(86,.10),at,.16)
    for at in [8,12,14,16,18,20,24,28]:
        sweep=noise(.24,10,2300)
        add(sweep,at,.10,-.25)
    for n in [48,60,64,67,72]: add(note(n,1.8,"bass" if n==48 else "pluck"),32,.18)
    fade=np.ones(len(mix)); fade[:2400]=np.linspace(0,1,2400); fade[-48000:]=np.linspace(1,0,48000)
    mix*=fade[:,None]
    mix=np.tanh(mix*1.25)*.82
    with wave.open(str(OUT/"soundtrack.wav"),"wb") as out:
        out.setnchannels(2);out.setsampwidth(2);out.setframerate(rate)
        out.writeframes((mix*32767).astype("<i2").tobytes())


def contact_sheet():
    times=[1.5,4.3,6.8,8.8,10.8,12.8,14.8,16.8,18.8,21,23,25.5,29,32]
    sheet=Image.new("RGB",(1280,7*390),"#e2e8e3")
    for i,t in enumerate(times):
        frame=scene(t).resize((640,360),Image.Resampling.LANCZOS)
        x=(i%2)*640;y=(i//2)*390
        sheet.paste(frame,(x,y));ImageDraw.Draw(sheet).text((x+12,y+365),f"{t:.1f}s",font=font(18),fill=C["ink"])
    sheet.save(OUT/"storyboard.jpg",quality=92)
    scene(4.3).save(OUT/"poster.png")
    # Dedicated 16:9 thumbnail, readable at small sizes.
    im=Image.new("RGB",(W,H),C["paper"]);contours(im,0);brand(im)
    lines(im,["NAME", "THAT", "MOVIE."],112,270,130,145)
    pill(im,"15 SECONDS",(116,790),"orange",size=37)
    card(im,"dino",(1370,540),800,-3)
    im.resize((1280,720),Image.Resampling.LANCZOS).save(OUT/"pixel-trailer-thumbnail.jpg",quality=94)


def render():
    soundtrack()
    command=["ffmpeg","-y","-hide_banner","-loglevel","warning","-f","rawvideo","-vcodec","rawvideo",
             "-pixel_format","rgb24","-video_size",f"{W}x{H}","-framerate",str(FPS),"-i","-",
             "-i",str(OUT/"soundtrack.wav"),"-c:v","libx264","-preset","fast","-crf","18",
             "-pix_fmt","yuv420p","-c:a","aac","-b:a","192k","-ar","48000",
             "-af","loudnorm=I=-16:TP=-3:LRA=9,alimiter=limit=0.75:level=false","-movflags","+faststart",
             "-metadata","title=Pixel — Pixel draws. You guess.",
             "-metadata","comment=Original motion design and original synthesized music. Drawings generated by Pixel.",
             str(OUT/"pixel-trailer-1080p.mp4")]
    proc=subprocess.Popen(command,stdin=subprocess.PIPE)
    for i in range(FPS*DURATION):
        proc.stdin.write(scene(i/FPS).tobytes())
        if i%(FPS*2)==0: print(f"Rendered {i/FPS:.0f}/{DURATION}s",flush=True)
    proc.stdin.close()
    if proc.wait():raise RuntimeError("ffmpeg failed")


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--preview",action="store_true")
    args=parser.parse_args();prep();contact_sheet()
    if not args.preview:render()
