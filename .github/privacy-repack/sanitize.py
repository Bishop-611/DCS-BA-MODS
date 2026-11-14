import sys,zipfile,json,hashlib,re,io,os
from pathlib import Path
userpath=re.compile(r'[A-Za-z]:[\\/]+Users[\\/]+([^\\/\s\]\"\']+)',re.I)
def safe(data,name):
    for encoding in ('utf-8','utf-16le'):
        text=data.decode(encoding,errors='ignore')
        for m in userpath.finditer(text):
            if m[1].upper() not in ('YOUR_WINDOWS_USER','YOUR_NAME','PUBLIC','DEFAULT','RUNNERADMIN'):
                raise RuntimeError('Personal path in '+name)
        if re.search(r'[A-Za-z]:[\\/]+Projects[\\/]',text,re.I):raise RuntimeError('Local project path in '+name)
def checkzip(path):
    with zipfile.ZipFile(path) as z:
        for n in z.namelist():
            if not n.endswith('/'):safe(z.read(n),n)
def niko(src,dst):
    with zipfile.ZipFile(src) as a:
        manifest=json.loads(a.read('manifest.json'))
        changed={}
        for item in manifest:
            if item.get('patch'):
                key='before/'+item['path'].replace('\\','/')
                content=b'-- Neutral offline test fixture for a merge-only shared script.\n'
                changed[key]=content
                item['before']=hashlib.sha256(content).hexdigest().upper()
        with zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED,compresslevel=1) as b:
            for e in a.infolist():
                if e.filename=='manifest.json':continue
                if e.filename in changed:b.writestr(e.filename,changed[e.filename]);continue
                with a.open(e) as inp,b.open(e.filename,'w') as out:
                    while True:
                        chunk=inp.read(1024*1024)
                        if not chunk:break
                        out.write(chunk)
            b.writestr('manifest.json',json.dumps(manifest,separators=(',',':')))
    # Only unused patch-test baselines change; installed resource bytes/hashes
    # and upgrade compatibility lists remain exactly the same.
    with zipfile.ZipFile(src) as a,zipfile.ZipFile(dst) as b:
        old=json.loads(a.read('manifest.json'));new=json.loads(b.read('manifest.json'))
        for x,y in zip(old,new):
            if x.get('patch'):x['before']=y['before']
            assert x==y
        for n in a.namelist():
            if n in changed or n=='manifest.json':continue
            assert a.getinfo(n).CRC==b.getinfo(n).CRC and a.getinfo(n).file_size==b.getinfo(n).file_size,n
    checkzip(dst)
def fox(src,dst,template=False):
    with zipfile.ZipFile(src) as a,zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED) as b:
        for e in a.infolist():
            data=a.read(e)
            if e.filename.lower().endswith('.exe') and b'Fox.Payload.zip' in data:
                data=Path(os.environ['CLEAN_FOX_EXE']).read_bytes()
            if e.filename.lower().endswith(('.lua','.txt','.md','.ps1','.json','.cmd','.cs')):
                text=data.decode('utf-8-sig')
                if template and e.filename.endswith('F4RwrProbe.lua'):
                    text=re.sub(r'[A-Za-z]:\\Users\\[^\\]+\\Saved Games\\DCS\\Logs\\F4RwrProbe\.log','__FOX_PROBE_LOG__',text)
                else:
                    text=userpath.sub(lambda m:m[0][:m.start(1)-m.start()]+'YOUR_WINDOWS_USER',text)
                data=text.encode('utf-8')
            safe(data,e.filename);b.writestr(e.filename,data)
    checkzip(dst)
if __name__=='__main__':
    mode,src,dst=sys.argv[1:4]
    if mode=='file':safe(Path(src).read_bytes(),Path(src).name)
    elif mode=='niko':niko(src,dst)
    elif mode=='fox-payload':fox(src,dst,True)
    else:fox(src,dst)
    print('PASS: sanitized',mode)
