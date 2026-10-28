import os
HERE=os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE,'align.py')).read())
COMPS='''WeaponDataComponentData WeaponReloadComponentData WeaponMagazineComponentData WeaponChargeComponentData WeaponRoundsComponentData WeaponHeatComponentData WeaponWindUpComponentData WeaponAssistedReloadComponentData ProjectileWeaponComponentData SprayWeaponComponentData ArcWeaponComponentData BeamWeaponComponentData MeleeWeaponComponentData AbilityWeaponComponentData GuidedWeaponComponentData PhysicsWeaponComponentData MountedWeaponComponentData WeaponCustomizationComponentData WeaponAttachmentComponentData WeaponFlashlightComponentData WeaponLaserComponentData WeaponScreenComponentData WeaponLinkedAmmoComponentData WeaponLinkerComponentData WeaponWielderComponentData'''.split()
UNK=re.compile(r'^(unk_[a-z0-9]+_(r)?0x[0-9A-Fa-f]{4}|0x[0-9A-F]{8})$')
def named(comp):
    out,warn,d,row=fields(comp)
    if d is None: return out,{},0,0
    out2,DL,pairs,ents=align(comp)
    # final path: per segment, use the dump's segment unless it is an unk/hash name (then the typelib-derived one)
    res={}
    for i,f in enumerate(out2):
        p=pairs.get(i)
        if p is None: continue
        dseg=re.findall(r'[^.]+',p); tseg=re.findall(r'[^.]+',f['path'])
        if len(dseg)!=len(tseg): res[i]=p; continue
        segs=[]
        for a,b in zip(dseg,tseg):
            base=re.sub(r'\[\d+\]$','',a); idx=re.search(r'\[\d+\]$',a)
            segs.append((b if UNK.match(base) else a))
        res[i]='.'.join(segs)
    return out2,res,len(pairs),len(DL)
if __name__=='__main__':
    toks=collections.Counter() if False else None
    import collections
    toks=collections.Counter(); allnames=collections.Counter()
    for c in COMPS:
        out,res,m,ndl=named(c)
        un=[f['path'] for i,f in enumerate(out) if i not in res]
        print('%-40s leaves %4d named %4d dumpleaves %4d unnamed %d %s'%(c,len(out),len(res),ndl,len(un),un[:4]))
        for i,p in res.items():
            for seg in p.split('.'):
                seg=re.sub(r'\[\d+\]','',seg)
                if UNK.match(seg): continue
                allnames[seg]+=1
                for t in seg.split('_'): toks[t]+=1
    json.dump(sorted(allnames),open(os.path.join(WORK,'names.json'),'w'))
    json.dump(sorted(toks),open(os.path.join(WORK,'tokens.json'),'w'))
    print('unique segments',len(allnames),'tokens',len(toks))
