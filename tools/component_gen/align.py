import os
HERE=os.path.dirname(os.path.abspath(__file__))
# align a component's type-library leaves with the dump's leaves by their values across every entity
exec(open(os.path.join(HERE,'walk.py')).read())
def dump_leaves(v,p=''):
    out=[]
    if isinstance(v,dict):
        for k,x in v.items():
            if k in META: continue
            if k.endswith('_detail'):
                for kk,xx in x.items(): out.append((p+'.'+k[:-7]+'.'+kk if p else k[:-7]+'.'+kk,('bit',)))
                continue
            out+=dump_leaves(x,(p+'.'+k) if p else k)
    elif isinstance(v,list):
        for i,x in enumerate(v): out+=dump_leaves(x,'%s[%d]'%(p,i))
    else: out.append((p,None))
    return out
def getp(v,path):
    for part in re.findall(r'[^.\[\]]+|\[\d+\]',path):
        if part.startswith('['): v=v[int(part[1:-1])]
        else: v=v[part]
    return v
def norm(x):
    if isinstance(x,str): return int(x.split()[0]) if '<=>' in x else int(x)
    if isinstance(x,float): return struct.unpack('<f',struct.pack('<f',x))[0]
    return x
def readv(at,st):
    if st=='f32': return struct.unpack_from('<f',E,at)[0]
    if st in('u32','enum'): return u32(at)
    if st=='i32': return struct.unpack_from('<i',E,at)[0]
    if st in('u8','enum8'): return E[at]
    if st=='u64': return struct.unpack_from('<Q',E,at)[0]
    if st.startswith('bit'): return (E[at]>>int(st[3:]))&1
def align(comp):
    out,warn,d,row=fields(comp)
    tid=dh(comp); rec,_=keyed(T,tid)
    ents=[(k[2:],v) for e in d['entities'] for k,v in e.items() if k[2:] in rec]
    dl=[p for p,_ in dump_leaves(ents[0][1])]
    def dvec(p):
        r=[]
        for h,v in ents:
            try: x=getp(v,p.replace('.effect_flags.','.effect_flags_detail.') if False else p)
            except Exception: x=None
            r.append(norm(x) if x is not None else None)
        return tuple(r)
    # bitfield dump leaves are under X_detail; rebuild
    def dvec2(p):
        if '.' in p:
            head,last=p.rsplit('.',1)
            try:
                return tuple(norm(getp(v,head+'_detail')[last]) if isinstance(getp(v,head+'_detail'),dict) else None for h,v in ents)
            except Exception: pass
        return dvec(p)
    DL=[]
    for p,kind in dump_leaves(ents[0][1]):
        DL.append((p, dvec2(p) if kind else dvec(p)))
    TLv=[tuple(readv(rec[h]+f['off'],f['st']) for h,_ in ents) for f in out]
    def eq(a,b):
        if len(a)!=len(b): return False
        for x,y in zip(a,b):
            if x is None or y is None: return False
            if isinstance(x,float) or isinstance(y,float):
                if not (abs(x-y)<=1e-6*max(1,abs(y))): return False
            elif x!=y: return False
        return True
    n,m=len(out),len(DL)
    # LCS-style alignment on equality
    S=[[0]*(m+1) for _ in range(n+1)]
    for i in range(n-1,-1,-1):
        for j in range(m-1,-1,-1):
            S[i][j]=max(S[i+1][j],S[i][j+1],S[i+1][j+1]+1 if eq(TLv[i],DL[j][1]) else 0)
    i=j=0; pairs={}
    while i<n and j<m:
        if eq(TLv[i],DL[j][1]) and S[i][j]==S[i+1][j+1]+1: pairs[i]=DL[j][0]; i+=1; j+=1
        elif S[i+1][j]>=S[i][j+1]: i+=1
        else: j+=1
    # gaps: between two matched leaves, as many unmatched type-library leaves as dump leaves (raw bitfield bytes
    # aside) are paired in order (a value that changed since the dump: a later game update or an edited file)
    dl_idx={p:j for j,(p,_) in enumerate(DL)}
    rawbits={p for p,_ in DL if p.endswith('effect_flags') or any(q.startswith(p+'.') for q,_ in DL if q!=p and '_detail' in q)}
    mi=sorted(pairs); bounds=[(-1,-1)]+[(i,dl_idx[pairs[i]]) for i in mi]+[(n,m)]
    gaps=0
    for (i0,j0),(i1,j1) in zip(bounds,bounds[1:]):
        ti=list(range(i0+1,i1)); dj=[j for j in range(j0+1,j1) if not DL[j][0].endswith('.effect_flags') and DL[j][0]!='effect_flags']
        if ti and len(ti)==len(dj):
            for a_,b_ in zip(ti,dj): pairs[a_]=DL[b_][0]; gaps+=1
    align.gaps=gaps
    return out,DL,pairs,ents
