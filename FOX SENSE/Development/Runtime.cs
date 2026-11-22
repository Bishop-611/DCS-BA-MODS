using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Interop;
public static class FoxGeometry {
 public static double[] E(double[] c,double[] p,double fov,double aspect){
  if(c==null||c.Length!=12||p==null||p.Length!=3||double.IsNaN(fov)||double.IsInfinity(fov)||fov<=1||fov>=179||double.IsNaN(aspect)||double.IsInfinity(aspect)||aspect<=0)return null;
  for(int i=0;i<12;i++)if(double.IsNaN(c[i])||double.IsInfinity(c[i]))return null;
  for(int i=0;i<3;i++)if(double.IsNaN(p[i])||double.IsInfinity(p[i]))return null;
  for(int a=3;a<12;a+=3){double n=0;for(int i=0;i<3;i++)n+=c[a+i]*c[a+i];if(Math.Abs(Math.Sqrt(n)-1)>0.05)return null;for(int b=a+3;b<12;b+=3){double d=0;for(int i=0;i<3;i++)d+=c[a+i]*c[b+i];if(Math.Abs(d)>0.05)return null;}}
  double forward=0,right=0,up=0;
  for(int i=0;i<3;i++){double d=p[i]-c[i];forward+=d*c[i+3];right+=d*c[i+6];up+=d*c[i+9];}
  double x=1280,y=720;
  if(forward>1){double focal=1280/Math.Tan(fov*Math.PI/360);x+=focal*right/forward;y-=focal*aspect/(2560.0/1440.0)*up/forward;}
  return new double[]{x,y,forward,right,up};
 }
 public static double[] A(double h,double fx,double fz,double roll,double hour,double zoom){
  double d=h+(hour%12)*Math.PI/6-Math.Atan2(fz,fx);
  d=Math.Atan2(Math.Sin(d),Math.Cos(d));
  return new double[]{1280+Math.Min(1060,800*zoom)*Math.Sin(d+roll),720-Math.Min(490,420*zoom)*Math.Cos(d+roll),d};
 }
 public static double[] B(double x,double y,double z,double h,double r){
  if(x*x+y*y+z*z>r*r)return null;
  return new double[]{210+160*(-x*Math.Sin(h)+z*Math.Cos(h))/r,210-160*(x*Math.Cos(h)+z*Math.Sin(h))/r};
 }
 public static bool C(double[] r,double[] p,double[] w,double[] q,double dt,double range){
  if(dt<0.02||dt>1.5)return false;
  double r2=0,v2=0,dot=0,m=0;double[] v=new double[3];
  for(int i=0;i<3;i++){v[i]=(r[i]-p[i])/dt;r2+=r[i]*r[i];v2+=v[i]*v[i];dot+=r[i]*v[i];double d=w[i]-q[i];m+=d*d;}
  if(r2<1||v2<1||r2>range*range||m<(20*dt)*(20*dt))return false;
  double t=-dot/v2;if(-dot/Math.Sqrt(r2)<30||t<=0||t>120)return false;
  double c=0;for(int i=0;i<3;i++){double d=r[i]+v[i]*t;c+=d*d;}return c<=9000000;
 }
}
