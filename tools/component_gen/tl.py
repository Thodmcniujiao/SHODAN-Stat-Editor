import os
HERE=os.path.dirname(os.path.abspath(__file__))
WORK=os.environ.get('COMPONENT_GEN_WORK',os.path.join(HERE,'work'))   # decrypted typelib.bin / entities.bin
RAWDATA=os.environ.get('RAWDATA',os.path.join(HERE,'Helldivers2_RawData'))   # a clone of Darctor/Helldivers2_RawData
import struct
b=open(os.path.join(WORK,'typelib.bin'),'rb').read()
n32=lambda o: struct.unpack_from('<I',b,o)[0]
nt,ne=n32(8),n32(12)
ts=36+4*(nt+ne); ms=ts+36*nt+32*ne
T={}
for i in range(nt):
    at=ts+36*i
    t={'size':n32(at+12),'members':[]}
    cnt,first=n32(at+24),n32(at+28)
    for j in range(first,first+cnt):
        m=ms+72*j
        t['members'].append(dict(atom=b[m+12],storage=b[m+13],count=b[m+14]+b[m+15]*256,type=n32(m+16),size=n32(m+24),offset=n32(m+40)))
    T[n32(36+4*i)]=t
def dh(s):
    h=5381
    for c in s.encode(): h=(h*33+c)%4294967296
    return (h-5381)%4294967296
# leaves of a type: (offset, size, storage, bit or None)
def leaves(tid,base=0):
    out=[]
    for m in T[tid]['members']:
        n=m['count'] if m['atom']==2 else 1      # atom 2: inline array (count = elements); 3: bitfield
        el=m['size']//n if n else m['size']
        for k in range(n):
            o=base+m['offset']+k*el
            if m['storage']==20 and m['type'] in T: out+=leaves(m['type'],o)
            elif m['atom']==3: out.append((o,el,m['storage'],m['count']>>8))
            else: out.append((o,el,m['storage'],None))
    return out
