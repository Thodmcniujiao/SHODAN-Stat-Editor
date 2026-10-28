# Reads and writes the plain Lua table literals of offline/planet_data.lua.
import re

TOKEN = re.compile(r'\s*(?:(\{)|(\})|(=)|(,)|\[\s*("(?:[^"\\]|\\.)*"|-?\d+)\s*\]|("(?:[^"\\]|\\.)*")|(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)|(true|false|nil)|([A-Za-z_]\w*))')


def unquote(s):
    out, i = [], 1
    while i < len(s) - 1:
        c = s[i]
        if c == '\\':
            n = s[i + 1]
            if n.isdigit():
                j = i + 1
                while j < len(s) - 1 and j < i + 4 and s[j].isdigit(): j += 1
                out.append(chr(int(s[i + 1:j]))); i = j; continue
            out.append({'n': '\n', 't': '\t', 'r': '\r'}.get(n, n)); i += 2; continue
        out.append(c); i += 1
    return ''.join(out)


def parse(text):
    text = re.sub(r'^\s*--[^\n]*\n', '', text, flags=re.M)
    text = text.strip()
    if text.startswith('return'): text = text[6:]
    toks, pos = [], 0
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            if text[pos:].strip() == '': break
            raise ValueError('bad Lua literal at %d: %r' % (pos, text[pos:pos + 40]))
        pos = m.end()
        toks.append(m)
    i = 0

    def value():
        nonlocal i
        m = toks[i]; i += 1
        if m.group(1): return table()
        if m.group(6): return unquote(m.group(6))
        if m.group(7):
            s = m.group(7)
            return float(s) if ('.' in s or 'e' in s or 'E' in s) else int(s)
        if m.group(8): return {'true': True, 'false': False, 'nil': None}[m.group(8)]
        raise ValueError('unexpected token %r' % m.group(0))

    def table():
        nonlocal i
        arr, d = [], {}
        while True:
            m = toks[i]
            if m.group(2): i += 1; break
            if m.group(4): i += 1; continue
            if m.group(5):
                k = m.group(5); i += 1
                assert toks[i].group(3); i += 1
                key = unquote(k) if k.startswith('"') else int(k)
                d[key] = value()
            elif m.group(9) and i + 1 < len(toks) and toks[i + 1].group(3):
                key = m.group(9); i += 2; d[key] = value()
            else:
                arr.append(value())
        if d and arr:
            for n, v in enumerate(arr, 1): d[n] = v
            return d
        return d if d else arr
    return value()


def lstr(s):
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == '"': out.append('\\"')
        elif ch == '\\': out.append('\\\\')
        elif ch == '\n': out.append('\\n')
        elif o < 32: out.append('\\%d' % o)
        else: out.append(ch)
    out.append('"')
    return ''.join(out)


def dump(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if v is None: return 'nil'
    if isinstance(v, int): return str(v)
    if isinstance(v, float):
        r = repr(v)
        return r if r not in ('inf', '-inf', 'nan') else '0'
    if isinstance(v, str): return lstr(v)
    if isinstance(v, (list, tuple)): return '{' + ','.join(dump(x) for x in v) + '}'
    if isinstance(v, dict):
        parts = []
        for k in sorted(v, key=lambda k: (isinstance(k, str), str(k) if isinstance(k, str) else k)):
            parts.append(('[%s]=' % lstr(k) if isinstance(k, str) else '[%d]=' % k) + dump(v[k]))
        return '{' + ','.join(parts) + '}'
    raise TypeError(type(v))
