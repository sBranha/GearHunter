#!/usr/bin/env python3
"""Build-time WoW BLP2/DXT5 optimization. Run on a disposable addon folder."""
from pathlib import Path
import argparse, shutil, struct, subprocess, tempfile
HEADER=1172
def convert(path,cmd):
    with tempfile.TemporaryDirectory(prefix="gh-blp-") as td:
        dest=Path(td)/"out.dds"
        run=subprocess.run([cmd,str(path),"-alpha","on","-define","dds:mipmaps=0","-define","dds:compression=dxt5","-define","dds:cluster-fit=false",str(dest)],capture_output=True,text=True)
        if run.returncode: raise RuntimeError(str(path)+": "+run.stderr[:500])
        data=dest.read_bytes()
    if len(data)<128 or data[:4]!=b"DDS " or data[84:88]!=b"DXT5":
        raise RuntimeError("Not a DXT5 DDS: "+str(path))
    h,w=struct.unpack_from("<II",data,12)
    raw=data[128:]
    if w<1 or h<1 or w>8192 or h>8192 or len(raw)!=((w+3)//4)*((h+3)//4)*16:
        raise RuntimeError("Invalid DDS dimensions: "+str(path))
    header=b"BLP2"+struct.pack("<I4BII",1,2,8,7,0,w,h)+struct.pack("<16I",HEADER,*([0]*15))+struct.pack("<16I",len(raw),*([0]*15))+bytes(1024)
    assert len(header)==HEADER
    out=path.with_suffix(".blp")
    out.write_bytes(header+raw)
    old=path.stat().st_size
    path.unlink()
    return old,len(header)+len(raw)
def main(folder):
    folder=Path(folder).resolve()
    if folder.name!="GearHunter" or not (folder/"GearHunter.toc").is_file(): raise RuntimeError("Expected GearHunter addon folder")
    cmd=shutil.which("magick") or shutil.which("convert")
    if not cmd: raise RuntimeError("ImageMagick is required")
    art=sorted((folder/"Art").rglob("*.tga"))
    if len(art)!=136: raise RuntimeError("Expected 136 active TGA images; the 21 retired character backgrounds must be absent")
    large=[p for p in art if p.stat().st_size>=1000000]
    before=after=0
    for i,p in enumerate(large,1):
        a,b=convert(p,cmd);before+=a;after+=b
        if i%20==0 or i==len(large):
            print("Converted %d/%d: %.1f MB -> %.1f MB"%(i,len(large),before/1e6,after/1e6),flush=True)
    stems={p.stem for p in large}
    for p in folder.rglob("*"):
        if p.suffix.lower() not in (".lua",".xml",".toc"): continue
        txt=p.read_text(encoding="utf-8-sig")
        for stem in stems: txt=txt.replace(stem+".tga",stem+".blp")
        if p.name=="Character.lua": txt=txt.replace('faction..".tga"','faction..".blp"')
        p.write_text(txt,encoding="utf-8")
    if len(list((folder/"Art").rglob("*.tga")))+len(list((folder/"Art").rglob("*.blp")))!=136 or len(large)<80:
        raise RuntimeError("Asset count mismatch")
    print("Complete: %d optimized BLP files, %d original small TGA files"%(len(large),len(art)-len(large)))
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("folder");main(p.parse_args().folder)
