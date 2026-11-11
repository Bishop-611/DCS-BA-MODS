param([string]$OutputRoot=(Join-Path $PSScriptRoot 'Release/v0.10-Matte'))
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'package-fox-platoon/Liveries/F-4E-45MC/F4E-FOX PLATOON'
$dest=Join-Path $OutputRoot 'Liveries/F-4E-45MC/F4E-FOX PLATOON'
[IO.Directory]::CreateDirectory($dest)|Out-Null
# RoughMet is packed numerical material data, not an albedo image.
# BC3: retain alpha/AO/metallicity/indices/mip levels, remap only roughness endpoints.
Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class FoxMatteRoughness {
 public static string Adjust(string input,string output) {
  byte[] a=File.ReadAllBytes(input), b=(byte[])a.Clone();
  if(a.Length<128 || System.Text.Encoding.ASCII.GetString(a,0,4)!="DDS " || System.Text.Encoding.ASCII.GetString(a,84,4)!="DXT5") throw new Exception("Expected legacy DXT5/BC3 DDS: "+input);
  int w=BitConverter.ToInt32(a,16),h=BitConverter.ToInt32(a,12),mips=BitConverter.ToInt32(a,28);
  long expected=128;
  for(int m=0;m<Math.Max(1,mips);m++){expected+=(long)Math.Max(1,(w+3)/4)*Math.Max(1,(h+3)/4)*16;w=Math.Max(1,w/2);h=Math.Max(1,h/2);}
  if(expected!=a.Length) throw new Exception("Unexpected DDS mip data length");
  long count=0,protectedMetal=0;double before=0,after=0;
  for(int p=128;p<a.Length;p+=16){
   ushort c0=BitConverter.ToUInt16(a,p+8),c1=BitConverter.ToUInt16(a,p+10);
   // Leave metal-dominant blocks untouched, should any occur in a later paint revision.
   if((c0&31)>6 || (c1&31)>6){protectedMetal++;continue;}
   for(int q=8;q<=10;q+=2){
    ushort c=BitConverter.ToUInt16(a,p+q);int g=(c>>5)&63;
    int next=(int)Math.Round(57+6*g/63.0,MidpointRounding.AwayFromZero);
    ushort n=(ushort)((c&~0x07e0)|(next<<5));
    if(((c^n)&~0x07e0)!=0 || next<g) throw new Exception("Non-roughness change");
    b[p+q]=(byte)(n&255);b[p+q+1]=(byte)(n>>8);
    before+=g/63.0;after+=next/63.0;
   }
   count++;
  }
  // Independently ensure every other compressed channel and all mip metadata survived.
  for(int i=0;i<a.Length;i++){
   int k=i<128?-1:(i-128)%16;
   int allowed=(k==8 || k==10)?0xe0:(k==9 || k==11)?0x07:0;
   if(((a[i]^b[i])&~allowed)!=0)throw new Exception("DDS channel preservation failed");
  }
  File.WriteAllBytes(output,b);
  return String.Format(System.Globalization.CultureInfo.InvariantCulture,"{0}: {1} paint blocks; {2} protected metal blocks; endpoint roughness {3:F3} -> {4:F3}",Path.GetFileName(input),count,protectedMetal,before/(2*count),after/(2*count));
 }
}
'@
$report=@(foreach($f in Get-ChildItem -LiteralPath $source -Filter '*_RoughMet.dds'){
 [FoxMatteRoughness]::Adjust($f.FullName,(Join-Path $dest $f.Name))
})
$report|Set-Content -LiteralPath (Join-Path $OutputRoot 'VALIDATION.txt') -Encoding utf8
$report

