# Names for the planet settings types: the current type library's members matched to the 2025 settings dump
# (shalzuth/HelldiversData, data/settings/*.json) by value across every record, then by order and kind of value.
import json, struct, collections, math


def u32(b, o): return struct.unpack_from('<I', b, o)[0]
def u64(b, o): return struct.unpack_from('<Q', b, o)[0]
def cstr(b, o):
    e = b.index(b'\0', o)
    return b[o:e].decode('utf-8', 'replace')


def blocks(b):
    """a decrypted .dl_bin's blocks: (offset, type, payload)"""
    at = b.find(b'LDLD\1\0\0\0', 0, 64)
    while at != -1 and at + 24 <= len(b):
        typ, size = struct.unpack_from('<II', b, at + 8)
        yield at, typ, b[at + 24:at + 24 + size]
        nxt = at + 24 + size
        at = b.find(b'LDLD\1\0\0\0', nxt, nxt + 64)


def records(path):
    yield from blocks(open(path, 'rb').read())

W = {0:1,1:2,2:4,3:8,4:1,5:2,6:4,7:8,8:4,9:8,10:1,11:2,12:4,13:8,14:1,15:2,16:4,17:8,18:8,19:8}
FMT = {0:'b',1:'h',2:'i',3:'q',4:'B',5:'H',6:'I',7:'Q',8:'f',9:'d',10:'b',11:'h',12:'i',13:'q',14:'B',15:'H',16:'I',17:'Q'}
ENUMST = (12, 14, 15, 16, 17)

class Aligner:
    def __init__(self, S, roots, settings_dir, bin_dir, key_order=('debug_name', 'id', 'name', 'inherits'), enum_names=None, prior=None):
        self.S, self.roots, self.dir, self.bin = S, roots, settings_dir, bin_dir
        self.enum_names = enum_names or {}      # enum type -> its name (the 2025 strings start with it)
        self.prior = prior or {}                # (type, member index) -> the name an earlier member-order pairing gave
        self.key_order = key_order
        self.inst = collections.defaultdict(list)     # type -> [(payload, pos, json dict)]
        self.result = {}                              # type -> {member index: (json key, how, score)}
        self.enum_maps = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
        self.unpaired = {}
        self._lc = {}

    # ------------------------------------------------------------------ reading the current records
    def ptr(self, p, o):
        q = u64(p, o)
        return q if 0 < q < len(p) else None

    def value(self, p, pos, m):
        """a member's value: scalar, string, list, or ('S', type, payload, pos) for a struct"""
        off = pos + m['offset']
        st, atom = m['storage'], m['atom']
        if atom == 3:
            sh, w = m['count'] >> 8, m['count'] & 255
            v = int.from_bytes(p[off:off + m['size']], 'little')
            return (v >> sh) & ((1 << w) - 1)
        if st == 18:
            q = self.ptr(p, off)
            return cstr(p, q) if q else ''
        if st == 19:
            q = self.ptr(p, off)
            return ('S', m['type'], p, q) if q else None
        if atom == 1:
            n = u32(p, off + 8)
            q = self.ptr(p, off) if n else None
            step = self.S[m['type']]['size'] if st == 20 else W[st]
            return [self.elem(p, q + j * step, m) for j in range(n)] if q is not None else []
        if atom == 2:
            n = m['count']; step = m['size'] // n
            return [self.elem(p, off + j * step, m) for j in range(n)]
        return self.elem(p, off, m)

    def elem(self, p, at, m):
        if m['storage'] == 20:
            return ('S', m['type'], p, at)
        if m['storage'] == 18:
            q = self.ptr(p, at); return cstr(p, q) if q else ''
        return struct.unpack_from('<' + FMT[m['storage']], p, at)[0]

    def leaves(self, v, depth=0):
        """flattened scalar leaves of a value (for comparing structs)"""
        if isinstance(v, tuple) and v and v[0] == 'S':
            _, t, p, at = v; out = []
            if depth > 6: return out
            for m in self.S[t]['members']:
                out += self.leaves(self.value(p, at, m), depth + 1)
            return out
        if isinstance(v, list):
            out = []
            for x in v: out += self.leaves(x, depth + 1)
            return out
        return [v]

    # ------------------------------------------------------------------ comparing with the 2025 values
    @staticmethod
    def jleaves(v):
        if isinstance(v, dict):
            out = []
            for k, x in v.items():
                if not k.startswith('__'): out += Aligner.jleaves(x)
            return out
        if isinstance(v, list):
            out = []
            for x in v: out += Aligner.jleaves(x)
            return out
        return [v]

    @staticmethod
    def same(a, b):
        if isinstance(b, bool): b = int(b)
        if isinstance(b, str) or isinstance(a, str):
            return a == b
        if a is None or b is None: return a is b
        if isinstance(a, float) or isinstance(b, float):
            try:
                a, b = float(a), float(b)
            except Exception: return False
            if math.isnan(a) or math.isnan(b): return math.isnan(a) and math.isnan(b)
            return abs(a - b) <= 1e-5 * max(1.0, abs(b))
        return a == b

    @staticmethod
    def norm(x):
        if isinstance(x, bool): x = int(x)
        if isinstance(x, float):
            if math.isnan(x): return 'nan'
            return float('%.5g' % x)
        return x

    def leaf_sim(self, a, b):
        ka = id(a) if isinstance(a, tuple) else None
        la = self._lc.get((a[1], a[3], id(a[2]))) if isinstance(a, tuple) else None
        if la is None:
            la = collections.Counter(self.norm(x) for x in self.leaves(a) if not isinstance(x, str))
            if isinstance(a, tuple): self._lc[(a[1], a[3], id(a[2]))] = la
        lb = collections.Counter(self.norm(x) for x in self.jleaves(b) if not isinstance(x, str) and x is not None)
        na, nb = sum(la.values()), sum(lb.values())
        if not na and not nb: return 1.0
        if not na or not nb: return 0.0
        return sum((la & lb).values()) / max(na, nb)

    def kind_cur(self, m):
        if m['atom'] == 3: return 'b'
        if m['atom'] == 1: return 'A'
        st = m['storage']
        if st in (19, 20): return 'S' if m['atom'] != 2 else 'A'
        if st == 18: return 's'
        if st in ENUMST: return 'e' if m['atom'] != 2 else 'A'
        if m['atom'] == 2: return 'A'
        if st in (8, 9): return 'f'
        return 'i'

    @staticmethod
    def kind_json(v):
        if isinstance(v, bool): return 'b'
        if isinstance(v, dict): return 'S'
        if isinstance(v, list): return 'A'
        if isinstance(v, str): return 'es'
        if isinstance(v, float): return 'f'
        if isinstance(v, int): return 'ib'
        return '?'

    def compatible(self, m, jv):
        kc, kj = self.kind_cur(m), self.kind_json(jv)
        if kc in kj: return True
        if kc == 'f' and kj == 'ib': return True      # (a float written as a whole number)
        if kc == 'i' and kj == 'f': return False
        if kc == 'b' and kj == 'ib': return True
        if kc == 'e' and kj == 'ib': return False
        return False

    def score(self, t, i, key, insts):
        """how well member i of type t agrees with json key over the instances (0..1), and whether informative"""
        m = self.S[t]['members'][i]
        vals, jvals = [], []
        for p, pos, j in insts:
            if key not in j or j[key] is None: continue
            vals.append(self.value(p, pos, m)); jvals.append(j[key])
        n = len(vals)
        if n == 0: return 0.0, False
        if not all(self.compatible(m, jv) for jv in jvals): return 0.0, False
        kc = self.kind_cur(m)
        if kc == 'e' and all(isinstance(x, str) for x in jvals):
            en = self.enum_names.get(m['type'])
            if en and not all(x.startswith(en + '_') for x in jvals): return 0.0, False
            # enum as a string: the mapping value -> name must be consistent
            mp = collections.defaultdict(collections.Counter)
            for a, b in zip(vals, jvals): mp[a][b] += 1
            agree = sum(c.most_common(1)[0][1] for c in mp.values())
            names = [c.most_common(1)[0][0] for c in mp.values()]
            if len(set(names)) < len(names): agree -= (len(names) - len(set(names)))
            return agree / n, len(mp) > 1
        if kc in ('S',):
            return self.judge([self.leaf_sim(a, b) >= 0.8 for a, b in zip(vals, jvals)], jvals)
        if kc == 'A':
            oks = []
            for a, b in zip(vals, jvals):
                if not isinstance(b, list): oks.append(False); continue
                if not a and not b: oks.append(True); continue
                if a and isinstance(a[0], tuple):
                    pairs = self.pair_elems(a, b)
                    good = [sim for _, _, sim in pairs if sim >= 0.8]
                    oks.append(len(good) >= 0.5 * min(len(a), len(b))); continue
                if len(a) != len(b): oks.append(False); continue
                else:
                    if m['storage'] in ENUMST and b and isinstance(b[0], str):
                        oks.append(True)   # (enum lists: counted by length; names checked with the enum)
                    else:
                        oks.append(all(self.same(x, y) for x, y in zip(a, b)))
            return self.judge(oks, jvals)
        ok = [self.same(a, b) for a, b in zip(vals, jvals)]
        return self.judge(ok, jvals)

    @staticmethod
    def judge(ok, jvals):
        """(agreement, informative): informative only when the values that differ from the usual one agree too"""
        n = len(ok)
        keyed = [json.dumps(x, sort_keys=True) for x in jvals]
        mode = collections.Counter(keyed).most_common(1)[0][0]
        rare = [o for o, k in zip(ok, keyed) if k != mode]
        if len(rare) >= 3:
            r = sum(rare) / len(rare)
            return (sum(ok) / n if r >= 0.6 else min(sum(ok) / n, 0.5)), r >= 0.6
        return sum(ok) / n, False

    def pair_elems(self, a, b):
        """elements of two arrays of structs paired: by index when the lengths agree and they look alike, else by likeness"""
        b = [x for x in b if isinstance(x, dict)]
        if len(a) == len(b):
            sims = [self.leaf_sim(x, y) for x, y in zip(a, b)]
            if not sims or sum(sims) / len(sims) >= 0.5: return [(x, y, s) for x, y, s in zip(a, b, sims)]
        if len(a) * len(b) > 60000: return []
        cand = sorted(((self.leaf_sim(x, y), i, j) for i, x in enumerate(a) for j, y in enumerate(b)), reverse=True)
        ua, ub, out = set(), set(), []
        for sim, i, j in cand:
            if sim < 0.5: break
            if i in ua or j in ub: continue
            ua.add(i); ub.add(j); out.append((a[i], b[j], sim))
        return out

    # ------------------------------------------------------------------ one type
    def align_type(self, t, insts):
        ms = self.S[t]['members']
        keys = []
        for p, pos, j in insts:
            for k in j:
                if not k.startswith('__') and k not in keys: keys.append(k)
        n, mm = len(ms), len(keys)
        sc = [[(0.0, False)] * mm for _ in range(n)]
        for i in range(n):
            for k in range(mm):
                sc[i][k] = self.score(t, i, keys[k], insts)
        def W8(s, i=None, k=None):
            ok = s[0] >= (0.75 if s[1] else 0.9)
            if not ok: return 0.0
            w = 1.0 if s[1] else 0.35
            if i is not None and self.prior.get((t, i)) == keys[k]: w += 0.4
            return w
        D = [[0.0] * (mm + 1) for _ in range(n + 1)]
        for i in range(n - 1, -1, -1):
            for k in range(mm - 1, -1, -1):
                w = W8(sc[i][k], i, k)
                D[i][k] = max(D[i + 1][k], D[i][k + 1], D[i + 1][k + 1] + w if w else 0)
        i = k = 0; pairs = {}
        while i < n and k < mm:
            w = W8(sc[i][k], i, k)
            if w and D[i][k] == D[i + 1][k + 1] + w:
                pairs[i] = (keys[k], 'value' if sc[i][k][1] else 'value-constant', sc[i][k][0]); i += 1; k += 1
            elif D[i + 1][k] >= D[i][k + 1]: i += 1
            else: k += 1
        # gaps between anchors: kind-compatible members in order
        anchors = sorted(pairs.items())
        bounds = [(-1, -1)] + [(i, keys.index(v[0])) for i, v in anchors] + [(n, mm)]
        for (a_i, a_k), (b_i, b_k) in zip(bounds, bounds[1:]):
            gi = list(range(a_i + 1, b_i)); gk = list(range(a_k + 1, b_k))
            if not gi or not gk: continue
            # LCS on kinds
            def ok(i, k):
                sample = next((j[keys[k]] for p, pos, j in insts if keys[k] in j), None)
                return sample is not None and self.compatible(ms[i], sample)
            L = [[0] * (len(gk) + 1) for _ in range(len(gi) + 1)]
            for x in range(len(gi) - 1, -1, -1):
                for y in range(len(gk) - 1, -1, -1):
                    L[x][y] = max(L[x + 1][y], L[x][y + 1], L[x + 1][y + 1] + 1 if ok(gi[x], gk[y]) else 0)
            x = y = 0
            while x < len(gi) and y < len(gk):
                if ok(gi[x], gk[y]) and L[x][y] == L[x + 1][y + 1] + 1:
                    pairs[gi[x]] = (keys[gk[y]], 'order', sc[gi[x]][gk[y]][0]); x += 1; y += 1
                elif L[x + 1][y] >= L[x][y + 1]: x += 1
                else: y += 1
        return pairs, keys

    # ------------------------------------------------------------------ all types, from the roots down
    def run(self):
        parents = collections.defaultdict(set)
        reach = set()
        def walk(t):
            if t in reach or t not in self.S: return
            reach.add(t)
            for m in self.S[t]['members']:
                if m['storage'] in (19, 20) and m['type'] in self.S:
                    parents[m['type']].add(t); walk(m['type'])
        for r in self.roots: walk(r['hash'])
        order, done = [], set()
        def topo(t):
            if t in done: return
            done.add(t)
            for p in parents[t]: topo(p)
            order.append(t)
        for t in reach: topo(t)
        for r in self.roots: self.pair_root(r)
        for t in order:
            insts = self.inst.get(t, [])
            if not insts:
                self.result[t] = ({}, []); continue
            pairs, keys = self.align_type(t, insts)
            self.result[t] = (pairs, keys)
            ms = self.S[t]['members']
            for i, (key, how, s) in pairs.items():
                m = ms[i]
                for p, pos, j in insts:
                    if key not in j: continue
                    v = self.value(p, pos, m); jv = j[key]
                    if m['storage'] in (19, 20) and m['type'] in self.S:
                        if isinstance(v, tuple) and isinstance(jv, dict):
                            self.inst[m['type']].append((v[2], v[3], jv))
                        elif isinstance(v, list) and isinstance(jv, list):
                            for a, b, sim in self.pair_elems(v, jv):
                                if isinstance(a, tuple) and isinstance(b, dict): self.inst[m['type']].append((a[2], a[3], b))
                    elif m['storage'] in ENUMST:
                        vs = v if isinstance(v, list) else [v]
                        js = jv if isinstance(jv, list) else [jv]
                        if len(vs) == len(js):
                            for a, b in zip(vs, js):
                                if isinstance(b, str): self.enum_maps[m['type']][a][b] += 1
        return self.result

    def pair_root(self, r):
        name, h, f = r['name'], r['hash'], r['file']
        try:
            J = json.load(open(self.dir + f.replace('.dl_bin', '.json')))
        except Exception:
            self.unpaired[name] = 'no 2025 data'; return
        jrecs = [list(x.values())[0] for x in J if isinstance(x, dict) and len(x) == 1 and list(x)[0] == name]
        cur = [(p, 0) for at, t, p in records(self.bin + f) if t == h]
        if not jrecs:
            self.unpaired[name] = 'no records of this type in the 2025 data'; return
        if len(cur) == 1 and len(jrecs) == 1:
            self.inst[h].append((cur[0][0], 0, jrecs[0])); self.paired_count = 1; return
        ms = self.S[h]['members']
        for key in self.key_order:
            if not all(key in j for j in jrecs): continue
            idx = [i for i, m in enumerate(ms) if m['atom'] == 0 and m['storage'] in (18, 6, 7, 16, 17)]
            best = None
            for i in idx:
                m = ms[i]; vals = [self.value(p, pos, m) for p, pos in cur]
                jm = {}
                for j in jrecs: jm.setdefault(j[key], j)
                hit = sum(1 for v in vals if v in jm)
                if hit and (best is None or hit > best[0]): best = (hit, i, jm)
            if best and best[0] >= max(2, 0.3 * min(len(cur), len(jrecs))):
                hit, i, jm = best
                for p, pos in cur:
                    v = self.value(p, pos, ms[i])
                    if v in jm: self.inst[h].append((p, pos, jm[v]))
                return
        # no shared key: pair each record with the 2025 record sharing most of its values
        def top(vals):
            return collections.Counter(json.dumps(self.norm(x)) for x in vals if isinstance(x, (int, float)) and not isinstance(x, bool) and x not in (0, -1))
        def sig_cur(p):
            vs = [self.value(p, 0, m) for m in ms if m['atom'] == 0 and m['storage'] not in (18, 19, 20)]
            return top(vs) or collections.Counter(json.dumps(self.norm(x)) for x in self.leaves(('S', h, p, 0)) if x not in (0, '', None))
        def sig_json(j):
            vs = [v for k, v in j.items() if not isinstance(v, (dict, list))]
            return top(vs) or collections.Counter(json.dumps(self.norm(x)) for x in self.jleaves(j) if x not in (0, '', None, False))
        cs = [sig_cur(p) for p, pos in cur]; js = [sig_json(j) for j in jrecs]
        cand = []
        for a_, c in enumerate(cs):
            for b_, d in enumerate(js):
                inter = sum((c & d).values()); tot = max(sum(c.values()), sum(d.values()), 1)
                cand.append((inter / tot, a_, b_))
        cand.sort(reverse=True); ua, ub = set(), set(); got = 0
        for sim, a_, b_ in cand:
            if sim < 0.3: break
            if a_ in ua or b_ in ub: continue
            ua.add(a_); ub.add(b_); got += 1
            self.inst[h].append((cur[a_][0], 0, jrecs[b_]))
        if not got: self.unpaired[name] = 'records could not be paired'
        else: self.paired_by_similarity = getattr(self, 'paired_by_similarity', {}); self.paired_by_similarity[name] = got
