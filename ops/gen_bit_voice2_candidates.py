#!/usr/bin/env python3
"""BIT voice v2 — PER-CHARACTER blips (Undertale/Animal-Crossing style), LOW +
ELECTRIC + serious (user redirect: no high beeps). Square-based so a low
fundamental still carries on phone speakers (harmonics reach past 700Hz). 3
styles, each 5 pitch variants for speech-like rotation on the pooled channel.
Outputs to ./bit_voice2_candidates/.
    python gen_bit_voice2_candidates.py
"""
import math, os, random, struct, wave
SR = 44100
_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bit_voice2_candidates")
os.makedirs(_OUT, exist_ok=True)

def env_ad(n, a_s, dur_s, curve=4.0):
    out=[]; a=max(1,int(a_s*SR))
    for i in range(n):
        t=i/SR
        if i<a: out.append(i/a)
        elif t>=dur_s: out.append(0.0)
        else: out.append(math.exp(-curve*(t-a_s)/max(1e-9,dur_s-a_s)))
    return out
def bl_square(freqs, gain=1.0):
    n=len(freqs); ph=[]; p=0.0
    for f in freqs: p+=f/SR; ph.append(p)
    kmax=max(1,int((SR*0.45)/max(freqs))); out=[0.0]*n; k=1
    while k<=kmax:
        g=gain/k
        for i in range(n): out[i]+=math.sin(2*math.pi*k*ph[i])*g
        k+=2
    return [(4/math.pi)*s for s in out]
def glide(f0,f1,dur):
    n=int(dur*SR); return [f0+(f1-f0)*(i/max(1,n-1)) for i in range(n)]
def noise_bp(n,center,q,seed,gain=1.0):
    rng=random.Random(seed); low=band=0.0; out=[]
    for i in range(n):
        f=2*math.sin(math.pi*min(center,SR*0.45)/SR); x=rng.uniform(-1,1)
        low+=f*band; high=x-low-q*band; band+=f*high
        band=-4.0 if band<-4.0 else (4.0 if band>4.0 else band); out.append(band*gain)
    return out
def apply_env(sig,env): return [s*e for s,e in zip(sig,env)]
def mix(*L):
    n=max(len(l) for l in L); out=[0.0]*n
    for l in L:
        for i,s in enumerate(l): out[i]+=s
    return out
def _fade(sig,f_s):
    f=max(1,int(f_s*SR)); nn=len(sig)
    for i in range(max(0,nn-f),nn): sig[i]*=(nn-i)/f
    return sig
def write_wav(name,sig,peak):
    m=max(1e-9,max(abs(s) for s in sig)); sig=[s*(peak/m) for s in sig]
    with wave.open(os.path.join(_OUT,name+".wav"),"w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h",int(max(-1.0,min(1.0,s))*32767)) for s in sig))

# Low, serious fundamentals with a small intonation wander (F3-A3-ish).
FUNDS = [175.0, 195.0, 210.0, 185.0, 222.0]

def bip_square(f):
    """A — clean LOW SQUARE bip: a quick down-glide (a consonant edge), pure
    electric buzz. The harmonic-rich baseline (audible low)."""
    n=int(0.045*SR)
    return _fade(apply_env(bl_square(glide(f*1.15, f, 0.045), 0.9), env_ad(n,0.002,0.045,6)), 0.006)

def bip_formant(f):
    """B — FORMANT VOX: the low square + an upper resonance (~2.4x) gives a
    'vowel'/vocal electric quality — reads as BIT saying a low 'vo/bo'."""
    n=int(0.052*SR); fr=glide(f*1.12, f, 0.052)
    v1=bl_square(fr, 0.75); v2=bl_square([x*2.4 for x in fr], 0.32)
    return _fade(apply_env(mix(v1,v2), env_ad(n,0.003,0.052,5)), 0.008)

def bip_robot(f):
    """C — RING-MOD ROBOT: the low square ring-modulated (metallic) + a noise
    edge at the attack — the roughest, most 'machine voice' electric."""
    n=int(0.045*SR); fr=glide(f*1.2, f, 0.045); sq=bl_square(fr, 0.85)
    rm=[sq[i]*(0.6+0.4*math.sin(2*math.pi*f*3.1*i/SR)) for i in range(n)]
    edge=apply_env(noise_bp(n, f*4.0, 0.6, 7), env_ad(n,0.001,0.018,6))
    return _fade(apply_env(mix(rm, [s*0.22 for s in edge]), env_ad(n,0.002,0.045,6)), 0.006)

if __name__ == "__main__":
    print("generating BIT voice v2 (per-char) ->", _OUT)
    for style,fn in [("a_square",bip_square),("b_formant",bip_formant),("c_robot",bip_robot)]:
        for i,f in enumerate(FUNDS, 1):
            write_wav(f"bitv_{style}_{i}", fn(f), 0.12)
        print(f"  {style}: 5 variants  (funds {FUNDS})")
    print("done.")
