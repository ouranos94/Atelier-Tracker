#!/usr/bin/env python3
"""Independent structural verifier. Does not use TrackerCore or libopenmpt, and never writes input files."""
import argparse, hashlib, json, struct
from pathlib import Path
SCALARS={-1,-2,-3,-4,-5,-6,-7,10,11,12}
BINARY={-10,-11,-13,-14,-15,-16,-17,-18,-19,-20,-21}

def unpack(d):
    if not d.startswith(b'PACK\xff\xff'):return d
    assert len(d)>=10,'PACK header'
    size=struct.unpack_from('>I',d,6)[0];assert size<=16*1024*1024,'PACK size'
    out=bytearray();p=10
    while p<len(d) and len(out)<size:
        op=d[p];p+=1
        if op==255:break
        assert op in (0,1,2,3),'PACK opcode'
        if op==2:n=8
        else:assert p<len(d);n=d[p]*(4 if op==1 else 1);p+=1
        assert n<=size-len(out),'PACK overflow'
        if op==0:assert p+n<=len(d);out+=d[p:p+n];p+=n
        elif op==3:out+=bytes(n)
        else:assert p+4<=len(d);out+=d[p:p+4]*(n//4);p+=4
    assert len(out)==size,'PACK truncated'
    return bytes(out)

def parse(path):
    d=path.read_bytes();assert 16<=len(d)<=64*1024*1024
    assert d[:8]==b'SymM\x00\x00\x00\x01','SymM v1 expected'
    p=8;chunks=[];values={}
    while p<len(d):
        assert p+4<=len(d),'chunk id truncated'
        i=struct.unpack_from('>i',d,p)[0];p+=4
        if i==-12:chunks.append((i,b''));continue
        assert i in SCALARS|BINARY,f'unknown chunk {i}'
        assert p+4<=len(d);n=struct.unpack_from('>I',d,p)[0];p+=4
        if i in SCALARS:assert i not in values;values[i]=n;chunks.append((i,struct.pack('>I',n)));continue
        assert n<=len(d)-p;payload=d[p:p+n];p+=n
        chunks.append((i,unpack(payload) if i in (-10,-13,-14,-15) else payload))
    assert 1<=values[-1]<=256 and 1<=values[-2]<=1024 and values.get(-5,4)&65535==4
    tables={}
    for i,payload in chunks:
        if i in (-10,-13,-14,-15):assert i not in tables;tables[i]=payload
    stride=values[-1]*values[-2]*4
    assert tables[-13] and len(tables[-13])%stride==0
    for i,size in [(-10,32),(-14,256),(-15,16)]:assert len(tables.get(i,b''))%size==0
    result=dict(file=str(path),sha256=hashlib.sha256(d).hexdigest(),bytes=len(d),channels=values[-1],rows=values[-2],patterns=len(tables[-13])//stride,instruments=len(tables.get(-14,b''))//256,positions=len(tables.get(-10,b''))//32,sequences=len(tables.get(-15,b''))//16)
    return result,chunks

def compare(a,b,allow):
    assert len(a)==len(b),'chunk count changed'
    changes=[]
    for j,((i,x),(k,y)) in enumerate(zip(a,b)):
        assert i==k,'chunk order changed'
        if x==y:continue
        assert len(x)==len(y),'logical payload length changed'
        assert i in allow,f'protected chunk changed: {i}'
        offsets=[p for p,(v,w) in enumerate(zip(x,y)) if v!=w]
        fields={-14:{128,129,130,134,138,139,140,142,150,151,152,153},-10:{4,5,8,9,10,11,12,13,14,15,16,17},-15:{0,1,2,3,8,9}}
        sizes={-14:256,-10:32,-15:16}
        if i in fields:assert all(o%sizes[i] in fields[i] for o in offsets),'opaque record field changed'
        if i==-14:
            for o in offsets:
                r=o//256*256; field=o%256
                assert x[r]!=0 and x[r:r+4]!=b'ViRT' and x[r+128] in (0,4) and x[r+132]==0,'protected instrument'
                if field==140:assert (x[o]^y[o])&239==0,'sample flags changed'
                if field==142:assert (x[o]^y[o])&254==0,'DSP flags changed'
        if i==-15:
            for r in {o//16*16 for o in offsets}:
                assert x[r+6:r+8]==b'\x00\x00','protected sequence state'
        if i==-13:
            def editable(e):
                cmd,pitch,param,inst=e; pitch=pitch if pitch<128 else pitch-256
                if cmd==0:return (pitch==-1 and param==254 and inst==0) or (-1<=pitch<=84 and param<=100)
                if cmd in (1,2,3,4):return True
                if cmd==9:return param<=31
                if cmd==12:return param<=120 and inst<=120
                if cmd==13:return param<=15 and inst<=120
                return False
            for r in {o//4*4 for o in offsets}:assert editable(x[r:r+4]) and editable(y[r:r+4]),'protected event changed'
        changes.append(dict(chunk=i,ordinal=j,changed_bytes=len(offsets),offsets=offsets[:64]))
    return changes

def main():
    ap=argparse.ArgumentParser();ap.add_argument('input',type=Path);ap.add_argument('--compare',type=Path);ap.add_argument('--allow-events',action='store_true');ap.add_argument('--allow-instruments',action='store_true');ap.add_argument('--allow-arrangement',action='store_true');args=ap.parse_args()
    report,chunks=parse(args.input)
    if args.compare:
        other,target=parse(args.compare);allow=set()
        if args.allow_events:allow.add(-13)
        if args.allow_instruments:allow.add(-14)
        if args.allow_arrangement:allow|={-10,-15}
        report['comparison']=dict(target=other['file'],byte_exact=report['sha256']==other['sha256'],changes=compare(chunks,target,allow))
    print(json.dumps(report,indent=2,ensure_ascii=False))
if __name__=='__main__':main()
