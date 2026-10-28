import struct
E=open(os.path.join(WORK,'entities.bin'),'rb').read()
u32=lambda o: struct.unpack_from('<I',E,o)[0]
def blocks():
    out={}; pos=0
    while pos<len(E):
        if E[pos+4:pos+8]!=b'LDLD': pos+=4
        assert E[pos+4:pos+8]==b'LDLD',pos
        typ=u32(pos); size=u32(pos+16); payload=pos+28
        out[typ]=(payload,size); pos=payload+size
    return out
B=blocks()
def keyed(T,typ):
    payload,size=B[typ]
    mp,arr=T[typ]['members']; row=T[arr['type']]['size']
    rec={}
    for i in range(mp['count']):
        at=payload+mp['offset']+i*16
        key=E[at:at+8]
        if key!=bytes(8) and u32(at+8)<arr['count'] and u32(at+12)==0:
            h='%016X'%struct.unpack_from('<Q',E,at)[0]
            rec[h]=payload+arr['offset']+u32(at+8)*row
    return rec,row
