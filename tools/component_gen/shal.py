# Names and descriptions from shalzuth/HelldiversData (the component schemas the game shipped until late 2024), matched
# to the current type library: a struct's type hash is the hash of its name, and its members are paired in order by kind.
SHAL=os.environ.get('SHALZUTH',os.path.join(HERE,'HelldiversData'))   # a clone of shalzuth/HelldiversData
SH={}; ENAMES=set()
for p in glob.glob(os.path.join(SHAL,'data','components','*.json')):
    try: d=json.load(open(p,encoding='utf-8'),object_pairs_hook=lambda kv:kv)
    except Exception: continue
    for name,members in d:
        if isinstance(members,list): SH[name]=[(f,dict(v)) for f,v in members]
for p in glob.glob(os.path.join(SHAL,'data','enums','*.json')): ENAMES.add(os.path.basename(p)[:-5])
SHH={dh(n):n for n in SH}; EH={dh(n):n for n in ENAMES}
PRIM={'float':'f','uint':'u','ulong':'q','int':'i','byte':'b','ushort':'h','string':'s'}
def cat_sh(t):
    if t in PRIM: return PRIM[t]
    if t in ENAMES: return ('e',dh(t))
    if t in SH or t.startswith('CApi'): return ('s',dh(t))
    return ('?',t)
def cat_tl(m):
    st=m['storage']
    if m['atom']==3: return 'b'
    if st==20: return ('s',m['type'])
    if st in (12,14,16,17): return ('e',m['type'])
    return {8:'f',6:'u',7:'q',2:'i',4:'b'}.get(st,'?')
def same(a,b):
    if a==b: return True
    if isinstance(a,tuple) and isinstance(b,tuple) and a[0]==b[0]=='e': return True   # (an enum renamed)
    return False
def pair(tid):
    ms=sorted(T[tid]['members'],key=lambda m:(m['offset'],m['count']))
    sname=SHH.get(tid)
    if not sname: return ms,{},False
    fs=SH[sname]
    A=[('a',cat_tl(m)) if m['atom']==2 else cat_tl(m) for m in ms]
    Bc=[]
    for f,v in fs:
        t=v.get('type')
        Bc.append(('a',cat_sh(v.get('subtype','?'))) if t=='array' else cat_sh(t))
    n,mm=len(A),len(Bc)
    eq=lambda a,b: same(a,b) or (isinstance(a,tuple) and isinstance(b,tuple) and a[0]==b[0]=='a' and same(a[1],b[1]))
    S=[[0]*(mm+1) for _ in range(n+1)]
    for i in range(n-1,-1,-1):
        for j in range(mm-1,-1,-1):
            S[i][j]=max(S[i+1][j],S[i][j+1],S[i+1][j+1]+1 if eq(A[i],Bc[j]) else 0)
    i=j=0; P={}
    while i<n and j<mm:
        if eq(A[i],Bc[j]) and S[i][j]==S[i+1][j+1]+1: P[i]=fs[j]; i+=1; j+=1
        elif S[i+1][j]>=S[i][j+1]: i+=1
        else: j+=1
    exact=(n==mm and len(P)==n)
    # (a struct that changed a lot since: too few members pair up to trust the order)
    # keep only the pairs whose type is a named struct / enum of the same hash (strong evidence on their own)
    if not exact and len(P)<0.6*mm:
        P={i:f for i,f in P.items() if isinstance(A[i],tuple) and A[i][0] in('s','e') and A[i]==cat_sh(f[1].get('type'))}
    return ms,P,exact
def desc_of(v):
    d=(v.get('description') or '').strip()
    d=re.sub(r'^\[(\w+)\]',lambda m:{'wwise':'(Wwise sound) ','string':'(hashed name) ','particles':'(particle effect) ','bool':'(switch) ','unit':'(unit resource) '}.get(m.group(1),'('+m.group(1)+') '),d)
    return d.strip() or None
def shal_leaves(tid,base=0,path='',out=None,exact=True):
    if out is None: out={}
    ms,P,ex=pair(tid)
    for i,m in enumerate(ms):
        f=P.get(i); name=f[0] if f else None; d=desc_of(f[1]) if f else None
        e=exact and ex
        if m['atom']==3:
            if name: out[(base+m['offset'],m['count']>>8)]=(path+name,d,e)
            continue
        n=m['count'] if m['atom']==2 else 1; el=m['size']//n
        for k in range(n):
            o=base+m['offset']+k*el; seg=(name or '?')+('[%d]'%k if m['atom']==2 else '')
            if m['storage']==20 and m['type'] in T:
                shal_leaves(m['type'],o,path+seg+'.',out,e and name is not None)
            elif name: out[(o,None)]=(path+seg,d,e)
    return out
