param([string]$Revision='v0.12-Dark-Weathered',[double]$Darken=0.10,[double]$DetailContrast=0.025,[double]$NormalStrength=1.0,[double]$EdgeLight=0.0)
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'package-fox-platoon/Liveries/F-4E-45MC/F4E-FOX PLATOON'
$materials=Join-Path $PSScriptRoot 'Release/v0.11-Material-Fix/Liveries/F-4E-45MC/F4E-FOX PLATOON'
$out=Join-Path $PSScriptRoot ('Release/'+$Revision+'/Liveries/F-4E-45MC/F4E-FOX PLATOON')
[IO.Directory]::CreateDirectory($out)|Out-Null
Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class FoxPaintAge {
 static double Clamp(double x){return Math.Max(0,Math.Min(1,x));}
 static double Smooth(double x){x=Clamp(x);return x*x*(3-2*x);}
 static int BC4(byte[] a,int p,int texel){
  int v0=a[p],v1=a[p+1];ulong bits=0;
  for(int i=0;i<6;i++)bits|=(ulong)a[p+2+i]<<(8*i);
  int index=(int)((bits>>(3*texel))&7);
  if(index==0)return v0;if(index==1)return v1;
  if(v0>v1)return ((8-index)*v0+(index-1)*v1)/7;
  if(index==6)return 0;if(index==7)return 255;
  return ((6-index)*v0+(index-1)*v1)/5;
 }
 static double Detail(byte[] n,int offset,int width,int x,int y,out double edge){
  edge=0;if(n==null)return 0;
  int p=offset+((y/4)*Math.Max(1,(width+3)/4)+x/4)*16;
  int t=(y%4)*4+x%4;
  int nx=BC4(n,p,t),ny=BC4(n,p+8,t);
  edge=Math.Max(-1,Math.Min(1,(nx+ny-256)/65.0));
  // Existing normal-map relief supplies the seam/rivet alignment; no invented scratches.
  return Clamp((Math.Abs(nx-128)+Math.Abs(ny-128)-3)/65.0);
 }
 public static string Build(string source,string normal,string output,double darken,double detailContrast,double edgeLight){
  byte[] a=File.ReadAllBytes(source),b=(byte[])a.Clone(),n=File.Exists(normal)?File.ReadAllBytes(normal):null;
  if(a.Length<128 || System.Text.Encoding.ASCII.GetString(a,0,4)!="DDS " || BitConverter.ToUInt32(a,84)!=0 || BitConverter.ToUInt32(a,88)!=32 || BitConverter.ToUInt32(a,92)!=0xff0000 || BitConverter.ToUInt32(a,96)!=0xff00 || BitConverter.ToUInt32(a,100)!=0xff)throw new Exception("Expected BGRA8 livery albedo");
  int width=BitConverter.ToInt32(a,16),height=BitConverter.ToInt32(a,12),mips=BitConverter.ToInt32(a,28),p=128,np=148;
  if(n!=null && (BitConverter.ToUInt32(n,128)!=83 || BitConverter.ToUInt32(n,140)!=1 || BitConverter.ToInt32(n,16)!=width || BitConverter.ToInt32(n,12)!=height || BitConverter.ToInt32(n,28)!=mips))throw new Exception("Normal-map geometry/header mismatch");
  long changed=0,protectedMarks=0;double before=0,after=0;long measured=0;
  int baseWidth=width,baseHeight=height;
  for(int level=0;level<mips;level++){
   for(int y=0;y<height;y++)for(int x=0;x<width;x++){
    int i=p+(y*width+x)*4;
    int blue=a[i],g=a[i+1],r=a[i+2];int max=Math.Max(r,Math.Max(g,blue)),min=Math.Min(r,Math.Min(g,blue));
    // Preserve near-black paint, white lettering, and saturated warning markings.
    double paint=Smooth((max-12)/18.0)*(1-Smooth((max-145)/55.0))*(1-Smooth((max-min-14)/25.0));
    if(paint==0){protectedMarks++;continue;}
    double u=(x+0.5)/width,v=(y+0.5)/height;
    double broad=(2+Math.Sin(u*19.0+v*7.0)+Math.Sin(v*31.0-u*9.0))/4.0;
    double edge;double dirt=Detail(n,np,width,x,y,out edge);
    double factor=1-paint*(darken+0.012*broad+detailContrast*dirt-edgeLight*edge);
    for(int c=0;c<3;c++)b[i+c]=(byte)Math.Max(0,Math.Min(a[i+c],(int)Math.Round(a[i+c]*factor)));
    if(b[i]!=a[i] || b[i+1]!=a[i+1] || b[i+2]!=a[i+2])changed++;
    if(level==0 && paint>0.95){before+=r+g+blue;after+=b[i]+b[i+1]+b[i+2];measured++;}
   }
   p+=width*height*4;
   np+=Math.Max(1,(width+3)/4)*Math.Max(1,(height+3)/4)*16;
   width=Math.Max(1,width/2);height=Math.Max(1,height/2);
  }
  if(p!=a.Length || (n!=null && np!=n.Length))throw new Exception("Mip payload length mismatch");
  for(int i=0;i<128;i++)if(a[i]!=b[i])throw new Exception("Header changed");
  for(int i=128;i<a.Length;i+=4){
   if(a[i+3]!=b[i+3])throw new Exception("Alpha changed");
   for(int c=0;c<3;c++)if(b[i+c]>a[i+c])throw new Exception("Unexpected brightening");
  }
  File.WriteAllBytes(output,b);
  return String.Format(System.Globalization.CultureInfo.InvariantCulture,"{0}: {1}x{2}, {3} mips; changed {4} texels; protected {5}; paint RGB mean ratio {6:F3}; header/alpha preserved; no channel brightened.",Path.GetFileName(source),baseWidth,baseHeight,mips,changed,protectedMarks,before>0?after/before:1);
 }
 public static void StrengthenNormal(string input,string output,double strength){
  byte[] b=File.ReadAllBytes(input);
  if(BitConverter.ToUInt32(b,128)!=83 || BitConverter.ToUInt32(b,140)!=1)throw new Exception("Expected repaired BC5 normal map");
  for(int p=148;p<b.Length;p+=8){
   int a=b[p],c=b[p+1];
   int x=Math.Max(0,Math.Min(255,(int)Math.Round(128+(a-128)*strength)));
   int y=Math.Max(0,Math.Min(255,(int)Math.Round(128+(c-128)*strength)));
   // Retain the BC4 interpolation mode, including explicit 0/255 palette entries.
   if((a>c)!=(x>y))continue;
   b[p]=(byte)x;b[p+1]=(byte)y;
  }
  File.WriteAllBytes(output,b);
 }
}
'@
$files=@(Get-ChildItem -LiteralPath $source -File -Filter '*.dds'|Where-Object Name -notmatch '_Normal|_RoughMet')
if($files.Count -ne 12){throw 'Expected twelve albedo maps.'}
$report=@(foreach($file in $files){
 $normal=Join-Path $materials ($file.BaseName+'_Normal.dds')
 [FoxPaintAge]::Build($file.FullName,$normal,(Join-Path $out $file.Name),$Darken,$DetailContrast,$EdgeLight)
})
if($NormalStrength -ne 1.0){foreach($file in Get-ChildItem -LiteralPath $materials -File -Filter '*_Normal.dds'){
 [FoxPaintAge]::StrengthenNormal($file.FullName,(Join-Path $out $file.Name),$NormalStrength)
}}
$report|Set-Content -LiteralPath (Join-Path $PSScriptRoot ('Release/'+$Revision+'/BUILD-NOTES.txt')) -Encoding utf8
$report

