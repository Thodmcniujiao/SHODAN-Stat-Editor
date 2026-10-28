import sys, re, hashlib, numpy as np
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
src = open(sys.argv[1], encoding='utf-8').read()
PK = bytes.fromhex(re.search(r"PK = unhex\('([0-9a-f]+)'\)", src).group(1))
SK = bytes.fromhex(re.search(r"SK = unhex\('([0-9a-f]+)'\)", src).group(1))
def rotl(v, c): return (v << np.uint32(c)) | (v >> np.uint32(32 - c))
def doubles(x):
    for _ in range(10):
        for a, b, c, d in ((0,4,8,12),(5,9,13,1),(10,14,2,6),(15,3,7,11)):
            x[b] ^= rotl(x[a] + x[d], 7); x[c] ^= rotl(x[b] + x[a], 9)
            x[d] ^= rotl(x[c] + x[b], 13); x[a] ^= rotl(x[d] + x[c], 18)
        for a, b, c, d in ((0,1,2,3),(5,6,7,4),(10,11,8,9),(15,12,13,14)):
            x[b] ^= rotl(x[a] + x[d], 7); x[c] ^= rotl(x[b] + x[a], 9)
            x[d] ^= rotl(x[c] + x[b], 13); x[a] ^= rotl(x[d] + x[c], 18)
    return x
SIGMA = np.frombuffer(b'expand 32-byte k', dtype='<u4')
def hsalsa(key, n16):
    k = np.frombuffer(key, '<u4'); n = np.frombuffer(n16, '<u4')
    x = [np.array([v], dtype=np.uint32) for v in (SIGMA[0],k[0],k[1],k[2],k[3],SIGMA[1],n[0],n[1],n[2],n[3],SIGMA[2],k[4],k[5],k[6],k[7],SIGMA[3])]
    x = doubles(x)
    return b''.join(int(x[i][0]).to_bytes(4,'little') for i in (0,5,10,15,6,7,8,9))
def stream(key, n8, length):
    blocks = (length + 63) // 64
    k = np.frombuffer(key, '<u4'); n = np.frombuffer(n8, '<u4')
    ctr = np.arange(blocks, dtype=np.uint64)
    init = [np.full(blocks, v, dtype=np.uint32) for v in (SIGMA[0],k[0],k[1],k[2],k[3],SIGMA[1],n[0],n[1],0,0,SIGMA[2],k[4],k[5],k[6],k[7],SIGMA[3])]
    init[8] = (ctr & 0xffffffff).astype(np.uint32); init[9] = (ctr >> 32).astype(np.uint32)
    x = doubles([v.copy() for v in init])
    out = np.stack([x[i] + init[i] for i in range(16)], axis=1).astype('<u4')
    return out.tobytes()[:length]
c = open(sys.argv[2], 'rb').read()
epk, box = c[:32], c[32:]
shared = X25519PrivateKey.from_private_bytes(SK).exchange(X25519PublicKey.from_public_bytes(epk))
k = hsalsa(shared, bytes(16))
nonce = hashlib.blake2b(epk + PK, digest_size=24).digest()
sub = hsalsa(k, nonce[:16])
body = box[16:]
ks = stream(sub, nonce[16:], 32 + len(body))[32:]
m = (np.frombuffer(body, np.uint8) ^ np.frombuffer(ks, np.uint8)).tobytes()
open(sys.argv[3], 'wb').write(m)
print('plain', len(m), m[:8])
