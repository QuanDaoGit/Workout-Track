#!/usr/bin/env python3
"""Candidates for BIT's VOICE family (onboarding cold-open + problem screens):
a boot-up cue (3 flavors) + a per-line "speak" voice burst (statement variants +
a question contour). Product-owner sign-off (2026-07-23) to widen BIT's voice
beyond the one-off bit_chirp — so the whole family is kin to bit_chirp's tri_wave
timbre. Outputs to ./bit_voice_candidates/ (audition only).
    python gen_bit_voice_candidates.py
"""
import math, os, random, struct, wave

SR = 44100
_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bit_voice_candidates")
os.makedirs(_OUT, exist_ok=True)
C6, E6, F6, G6, A6, C7 = 1046.50, 1318.51, 1396.91, 1567.98, 1760.0, 2093.00

# ── toolkit ──────────────────────────────────────────────────────────────────
def env_ad(n, attack_s, dur_s, curve=4.0):
    out=[]; a=max(1,int(attack_s*SR))
    for i in range(n):
        t=i/SR
        if i<a: out.append(i/a)
        elif t>=dur_s: out.append(0.0)
        else: out.append(math.exp(-curve*(t-attack_s)/max(1e-9,dur_s-attack_s)))
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

def tri_wave(freqs, gain=1.0):
    n=len(freqs); ph=[]; p=0.0
    for f in freqs: p+=f/SR; ph.append(p)
    kmax=max(1,int((SR*0.45)/max(freqs))); out=[0.0]*n; k,sign=1,1.0
    while k<=kmax:
        g=sign*gain/(k*k)
        for i in range(n): out[i]+=math.sin(2*math.pi*k*ph[i])*g
        k+=2; sign=-sign
    return [(8/(math.pi**2))*s for s in out]

def steps(seq):
    fr=[]
    for f,d in seq: fr.extend([f]*int(d*SR))
    return fr

def glide(f0,f1,dur):
    n=int(dur*SR); return [f0+(f1-f0)*(i/max(1,n-1)) for i in range(n)]

def sweep_noise(n,f0,f1,q,seed,gain=1.0):
    rng=random.Random(seed); low=band=0.0; out=[]
    for i in range(n):
        c=f0+(f1-f0)*(i/max(1,n-1)); f=2*math.sin(math.pi*min(c,SR*0.45)/SR)
        x=rng.uniform(-1,1); low+=f*band; high=x-low-q*band; band+=f*high
        band=-4.0 if band<-4.0 else (4.0 if band>4.0 else band)
        out.append(band*gain)
    return out

def noise_bp(n,center,q=1.0,seed=7,gain=1.0): return sweep_noise(n,center,center,q,seed,gain)
def silence(seconds): return [0.0]*int(seconds*SR)
def apply_env(sig,env): return [s*e for s,e in zip(sig,env)]
def mix(*layers):
    n=max(len(l) for l in layers); out=[0.0]*n
    for l in layers:
        for i,s in enumerate(l): out[i]+=s
    return out
def _fade(sig,f_s):
    f=max(1,int(f_s*SR)); nn=len(sig)
    for i in range(max(0,nn-f),nn): sig[i]*=(nn-i)/f
    return sig

def syllable(f0,f1,dur,vib=0.0,vibr=8.0):
    """One spoken 'syllable' in BIT's tri_wave timbre (the bit_chirp idiom)."""
    n=int(dur*SR); fr=[]
    for i in range(n):
        t=i/SR; base=f0+(f1-f0)*(i/max(1,n-1))
        fr.append(base*(1.0+vib*math.sin(2*math.pi*vibr*t)))
    return apply_env(tri_wave(fr), env_ad(n,0.008,dur,3.2))

def write_wav(name,sig,peak):
    m=max(1e-9,max(abs(s) for s in sig)); sig=[s*(peak/m) for s in sig]
    with wave.open(os.path.join(_OUT,name+".wav"),"w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h",int(max(-1.0,min(1.0,s))*32767)) for s in sig))
    print(f"  {name}.wav  {len(sig)/SR:.3f}s  peak {peak}")

# ── BOOT flavors (BIT wakes: flicker -> rise -> settle) ──────────────────────
def boot_chip():
    """Chiptune power-up: gated blips flicker awake -> a rising square glide ->
    a bright C-major settle chord + sparkle."""
    flick=[]
    for f,d,gap in [(220,0.03,0.04),(300,0.03,0.035),(420,0.025,0.03),(600,0.025,0.02)]:
        flick += apply_env(bl_square([f]*int(d*SR),0.6), env_ad(int(d*SR),0.002,d,5)) + silence(gap)
    nr=int(0.55*SR)
    rise=[s*(0.2+0.6*(i/nr)) for i,s in enumerate(apply_env(bl_square(glide(500,C6,0.55),0.7), env_ad(nr,0.02,0.55,1.5)))]
    nch=int(0.18*SR)
    chord=mix(apply_env(bl_square([C6]*nch,0.6),env_ad(nch,0.004,0.18,3)),
              apply_env(bl_square([E6]*nch,0.4),env_ad(nch,0.004,0.18,3)))
    spark=apply_env(tri_wave(steps([(G6,0.04),(C7,0.05)])), env_ad(int(0.09*SR),0.003,0.09,4))
    return _fade(flick + rise + mix(chord, silence(0.02)+[s*0.4 for s in spark]), 0.03)

def boot_servo():
    """Servo spin-up: a buzzy tremolo motor spinning up in pitch -> a click +
    bright settle tone (kin to the servo-latch land)."""
    dur=1.0; n=int(dur*SR)
    fr=[150+270*min(1.0,(i/n)/0.8) for i in range(n)]
    buzz=bl_square(fr,0.7)
    trem=[buzz[i]*(0.55+0.45*(0.5+0.5*math.sin(2*math.pi*38*(i/SR)))) for i in range(n)]
    motor=[trem[i]*(0.15+0.85*min(1.0,(i/n)/0.75))*0.6 for i in range(n)]
    click=apply_env(noise_bp(int(0.006*SR),3000,0.5,55), env_ad(int(0.006*SR),0.0004,0.006,6))
    ping=apply_env(tri_wave([G6]*int(0.10*SR),0.6), env_ad(int(0.10*SR),0.003,0.10,4))
    return _fade(motor + mix(click, silence(0.005)+[s*0.5 for s in ping]), 0.04)

def boot_hum():
    """Electric hum-up: crackle flickers -> a rising filtered-noise whir + a low
    tone rising -> a bright pop + tri settle."""
    flick=[]
    for k in range(4):
        d=0.02; b=apply_env(noise_bp(int(d*SR),1500+k*300,0.6,70+k), env_ad(int(d*SR),0.001,d,5))
        flick += [s*0.5 for s in b] + silence(0.03+0.01*k)
    nw=int(0.6*SR)
    whir=[s*0.35 for s in apply_env(sweep_noise(nw,400,2400,0.6,88), [(0.15+0.85*(i/nw)) for i in range(nw)])]
    tone=[s*0.4 for s in apply_env(bl_square(glide(120,500,0.6),0.5), [(0.1+0.9*(i/nw)) for i in range(nw)])]
    pop=apply_env(noise_bp(int(0.02*SR),2600,0.6,99), env_ad(int(0.02*SR),0.001,0.02,5))
    stone=apply_env(tri_wave([E6]*int(0.14*SR),0.6), env_ad(int(0.14*SR),0.004,0.14,3.5))
    return _fade(flick + mix(whir,tone) + mix([s*0.5 for s in pop], silence(0.01)+[s*0.5 for s in stone]), 0.04)

def boot_settled():
    """Reduced-motion: a short single power-on blip + settle chord (no flicker/rise)."""
    rise=apply_env(bl_square(glide(400,C6,0.12),0.6), env_ad(int(0.12*SR),0.01,0.12,2))
    chord=mix(apply_env(bl_square([C6]*int(0.14*SR),0.5),env_ad(int(0.14*SR),0.004,0.14,3)),
              apply_env(bl_square([E6]*int(0.14*SR),0.35),env_ad(int(0.14*SR),0.004,0.14,3)))
    return _fade(rise + chord, 0.03)

# ── SPEAK bursts (per-line voice, tri_wave, kin to bit_chirp) ────────────────
def speak_1():  # warm greeting statement — gentle down
    return _fade(syllable(G6,G6*0.99,0.07) + silence(0.02) + syllable(E6,E6*0.98,0.08), 0.02)
def speak_2():  # neutral 3-syllable statement
    return _fade(syllable(E6,E6,0.06) + silence(0.02) + syllable(G6,G6,0.06) + silence(0.02) + syllable(E6,E6*0.97,0.07), 0.02)
def speak_3():  # curious statement variant (a touch higher)
    return _fade(syllable(G6,A6,0.06) + silence(0.02) + syllable(F6,E6,0.08), 0.02)
def speak_q():  # question contour — last syllable bends UP (kin to bit_chirp)
    return _fade(syllable(E6,E6,0.06) + silence(0.02) + syllable(G6,C7*1.04,0.12,vib=0.012), 0.02)

if __name__ == "__main__":
    print("generating BIT voice candidates ->", _OUT)
    write_wav("bit_boot_chip", boot_chip(), 0.28)
    write_wav("bit_boot_servo", boot_servo(), 0.28)
    write_wav("bit_boot_hum", boot_hum(), 0.28)
    write_wav("bit_boot_settled", boot_settled(), 0.26)
    write_wav("bit_speak_1", speak_1(), 0.16)
    write_wav("bit_speak_2", speak_2(), 0.16)
    write_wav("bit_speak_3", speak_3(), 0.16)
    write_wav("bit_speak_q", speak_q(), 0.16)
    print("done.")
