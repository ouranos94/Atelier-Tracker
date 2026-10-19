#!/usr/bin/env python3
"""Deterministic original test signals; no third-party music or samples."""
import argparse, io, json, math, struct, wave
from pathlib import Path

def u32(n): return struct.pack('>I',n & 0xffffffff)
def block(i,d): return u32(i)+u32(len(d))+d
def pack(d):
    return b'PACK\xff\xff'+u32(len(d))+b''.join(bytes([0,len(d[i:i+255])])+d[i:i+255] for i in range(0,len(d),255))+b'\xff'
def position(pattern=0,start=0,length=16,repeats=1,transpose=0):
    return b'\x11\x22\x33\x44'+struct.pack('>6HhH',repeats,7,pattern,start,length,6,transpose,0)+b'\x99'*12

def sequence(start=0,length=2,info=0,transpose=0):
    return struct.pack('>3H2h',start,length,1,info,transpose)+b'\x88'*6

def instrument(name,index,kind):
    d=bytearray(256);n=name.encode();d[:len(n)]=n;d[128]=4;d[130]=100;d[134]=80;d[140]=16
    if kind=='sustain' and index==0:d[128]=8
    if kind=='stereo' and index in (0,1):d[132]=index+1
    if kind=='virtual' and index==3:
        d[:128]=bytes(128)
        d[:20]=b'ViRT'+struct.pack('>BB7H',0,0,0,0,0,0,2,20,4)
        d[20:28]=bytes([0,24,80,0,0,31,80,1])
    return bytes(d)

def create(kind,channels=4,packed=False):
    table=b''.join(instrument('Original oscillator '+str(i),i,kind) for i in range(4))
    data=bytearray(bytes([0,255,0,0])*(channels*16*2))
    def event(p,r,c,v):data[((p*16+r)*channels+c)*4:((p*16+r)*channels+c+1)*4]=bytes(v)
    for p in range(2):
        for c in range(channels):event(p,0,c,[0,24+p*7+(c%3)*4,80,c%4])
        event(p,4,0,[1,255,30,0]);event(p,8,0,[13,255,5,64]);event(p,12,0,[13,255,0,0])
    if kind=='dsp':event(0,1,channels-1,[24,2,12,40])
    positions=position()+position(1)
    sequences=sequence()+sequence(info=-1)
    if kind=='sequences':sequences=sequence(length=1)+sequence(info=1)+sequence(start=1,length=1,transpose=2)+sequence(info=-1)+sequence()
    if kind=='repeat':positions=position(repeats=2)+position(1)
    if kind=='cross-pattern':positions=position(start=14,length=4)+position(1)
    enc=pack if packed else lambda d:d
    source=b'SymM'+u32(1)
    for i,n in [(-1,channels),(-2,16),(-3,64),(-4,4),(-5,4),(-6,125)]:source+=u32(i)+u32(n)
    source+=block(-14,enc(table))+block(-10,enc(positions))+block(-15,enc(sequences))+block(-13,enc(bytes(data)))
    waves=[bytes(round(math.sin(j*2*math.pi/(32+i*8))*90)&255 for j in range(512)) for i in range(4)]
    if kind=='stereo':
        out=io.BytesIO()
        with wave.open(out,'wb') as w:
            w.setnchannels(2);w.setsampwidth(1);w.setframerate(8363)
            w.writeframes(bytes(v for a,b in zip(waves[0],waves[1]) for v in [(a+128)&255,(b+128)&255]))
        source+=block(-11,out.getvalue())
        for data in waves[2:]:source+=block(-11,data)
    else:
        for i,data in enumerate(waves):source+=u32(-12) if kind=='virtual' and i==3 else block(-11,data)
    return source+block(-20,b'ORIGINAL SYNTHETIC CORPUS - ATELIER')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,default=Path(__file__).resolve().parent.parent/'Tests/Fixtures/SymMOD');args=ap.parse_args()
    args.output.mkdir(parents=True,exist_ok=True);manifest=[]
    cases=[('mono',4,False),('packed',4,True),('sixteen',16,False),('stereo',4,False),('virtual',4,False),('sustain',4,False),('dsp',4,False),('sequences',4,True),('repeat',4,True),('cross-pattern',4,False)]
    for kind,channels,packed in cases:
        name=kind+'.SymMOD';content=create(kind,channels,packed);(args.output/name).write_bytes(content)
        manifest.append(dict(file=name,channels=channels,patterns=2,rows=16,instruments=4,packed=packed,feature=kind))
    (args.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'{len(cases)} modules synthétiques originaux : {args.output}')
if __name__=='__main__':main()
