import json,os,re,struct,sys
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'tl.py')).read()); exec(open(os.path.join(HERE,'entities.py')).read())
DUMP=os.path.join(RAWDATA,'Data','entities')+os.sep
META={'hash','name','name_zh','index'}
SIZE={2:4,6:4,8:4,12:4,16:4,7:8,17:8,14:1,4:1}
def merged(tid):
    out=[]
    for m in sorted(T[tid]['members'],key=lambda m:(m['offset'],m['count'])):
        if m['atom']==3 and out and out[-1]['offset']==m['offset'] and out[-1].get('bits') is not None:
            out[-1]['bits'].append(m['count']>>8); continue
        d=dict(m); d['bits']=[m['count']>>8] if m['atom']==3 else None
        out.append(d)
    return out
def keys_of(v):
    return [k for k in v if k not in META and not k.endswith('_detail')] if isinstance(v,dict) else None
def walk(tid,v,base,path,out,top,warn):
    ms=merged(tid); ks=keys_of(v)
    if ks is not None and len(ks)!=len(ms): warn.append('%s: %d members, dump %d keys'%(path or 'record',len(ms),len(ks))); ks=None
    for i,m in enumerate(ms):
        name=ks[i] if ks else None
        sub=v.get(name) if (ks and isinstance(v,dict)) else None
        off=base+m['offset']
        tname={2:'int32',4:'uint8',6:'uint32',7:'uint64',8:'float',12:'enum',14:'enum',16:'enum',17:'enum',20:'struct'}.get(m['storage'],'s%d'%m['storage'])
        if not name: name='unk_%s_%s0x%04X'%(tname,'r' if path else '',m['offset'])
        p=(path+'.' if path else '')+name
        g=top if top else name
        if m['bits'] is not None:
            det=v.get(name+'_detail') if isinstance(v,dict) else None
            bn=list(det.keys()) if isinstance(det,dict) and len(det)==len(m['bits']) else ['bit_%d'%b for b in m['bits']]
            for b,n in zip(m['bits'],bn): out.append(dict(path=p+'.'+n,leaf=n,off=off,st='bit%d'%b,group=g,enum=None))
            continue
        n=m['count'] if m['atom']==2 else 1
        el=m['size']//n
        for k in range(n):
            pp=p+('[%d]'%k if m['atom']==2 else '')
            vv=(sub[k] if isinstance(sub,list) and k<len(sub) else None) if m['atom']==2 else sub
            o=off+k*el
            if m['storage']==20 and m['type'] in T:
                walk(m['type'],vv,o,pp,out,g,warn)
            else:
                st={2:'i32',4:'u8',6:'u32',7:'u64',8:'f32',12:'enum',14:'enum8',16:'enum',17:'u64'}[m['storage']]
                out.append(dict(path=pp,leaf=name,off=o,st=st,group=g,enum=m['type'] if m['storage'] in (12,14,16,17) else None,top=(path=='')))
    return out
def fields(comp):
    tid=dh(comp); row=T[tid]['members'][1]['type']
    d=json.load(open(DUMP+comp+'.json')) if os.path.exists(DUMP+comp+'.json') else None
    v=next(iter(d['entities'][0].values())) if d else None
    warn=[]; out=walk(row,v,0,'',[],None,warn)
    return out,warn,d,row
