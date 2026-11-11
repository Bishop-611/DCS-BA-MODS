using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using System.Security.Cryptography;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using System.Drawing;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
public class Item {
 public string path,scope,before,after,legacy; public string[] accepted; public bool patch,dynamic;
 public string Key {get{return (scope??"game")+"/"+path.Replace('\\','/');}}
}
public class Baseline {public string key,path,scope,hash,backup,installed;}
public class State {public string savedRoot;public List<Baseline> files=new List<Baseline>();}
public class Change {public Item item;public string target,current,desired,staged,backup;public byte[] bytes;public Baseline original;}
public class Package:IDisposable {
 public static bool LiveryOnly {get{return Array.IndexOf(Assembly.GetExecutingAssembly().GetManifestResourceNames(),"livery-only")>=0;}}
 public List<Item> files;Stream stream;ZipArchive zip;bool fixture;
 static JavaScriptSerializer Json(){return new JavaScriptSerializer{MaxJsonLength=int.MaxValue};}
 public Package(){stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip");zip=new ZipArchive(stream,ZipArchiveMode.Read);using(var r=new StreamReader(zip.GetEntry("manifest.json").Open()))files=Json().Deserialize<List<Item>>(r.ReadToEnd());}
 public void Dispose(){zip.Dispose();stream.Dispose();}
 public static string Hash(string path){if(!File.Exists(path))return null;using(var s=File.OpenRead(path))using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(s)).Replace("-","");}
 static string BytesHash(byte[] bytes){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(bytes)).Replace("-","");}
 public static string Target(string root,string relative){string full=Path.GetFullPath(Path.Combine(root,relative));if(!full.StartsWith(Path.GetFullPath(root).TrimEnd('\\')+"\\",StringComparison.OrdinalIgnoreCase))throw new Exception("Unsafe package path: "+relative);return full;}
 public void Extract(string name,string target,string expected){var entry=zip.GetEntry(name);if(entry==null)throw new Exception("Missing package entry: "+name);Directory.CreateDirectory(Path.GetDirectoryName(target));using(var src=entry.Open())using(var dst=File.Create(target))src.CopyTo(dst);if(Hash(target)!=expected)throw new Exception("Package verification failed: "+name);}
 static string Location(Item f,string root,string saved){return Target(f.scope=="saved"?saved:root,f.path);}
 static string Entry(Item f,string prefix){return prefix+"/"+(f.scope=="saved"?"SavedGames/":"")+f.path.Replace('\\','/');}
 static void CopyVerified(string source,string target,string hash){Directory.CreateDirectory(Path.GetDirectoryName(target));File.Copy(source,target,true);if(Hash(target)!=hash)throw new Exception("File verification failed: "+target);}
 static string Clean(string text){string clean=Regex.Replace(text,@"(?:\r?\n)?-- NIKO_WSO_RUNTIME_BEGIN[\s\S]*?-- NIKO_WSO_RUNTIME_END","");if(clean.Contains("NIKO_WSO_RUNTIME_BEGIN")||clean.Contains("NIKO_WSO_RUNTIME_END"))throw new Exception("Incomplete Niko script markers. The script was preserved.");return clean;}
 public void Apply(string root,string saved,bool install,Action<string> progress){
  root=Path.GetFullPath(root);saved=Path.GetFullPath(saved);
  if(!fixture&&Process.GetProcessesByName("DCS").Length>0)throw new Exception("Close DCS before installing or restoring.");
  if(!fixture&&!File.Exists(Target(root,@"bin\DCS.exe"))&&!File.Exists(Target(root,@"bin-mt\DCS.exe")))throw new Exception("Select the DCS World installation folder.");
  if(!fixture&&!Directory.Exists(Target(root,@"Mods\aircraft\F-4E")))throw new Exception("F-4E is not installed in this DCS folder.");
  string statePath=Target(root,@"NikoWSO_Backups\bundle-state.json");byte[] oldState=File.Exists(statePath)?File.ReadAllBytes(statePath):null;
  State state=oldState==null?new State{savedRoot=saved}:Json().Deserialize<State>(Encoding.UTF8.GetString(oldState));
  if(!String.Equals(state.savedRoot,saved,StringComparison.OrdinalIgnoreCase))throw new Exception("Use the Saved Games profile from the previous installation: "+state.savedRoot);
  var baseline=new Dictionary<string,Baseline>(StringComparer.OrdinalIgnoreCase);foreach(var b in state.files)baseline.Add(b.key,b);
  var changes=new List<Change>();var next=new State{savedRoot=saved};
  if(LiveryOnly){var handled=new HashSet<string>(StringComparer.OrdinalIgnoreCase);foreach(var f in files)handled.Add(f.Key);foreach(var b in state.files)if(!handled.Contains(b.key))next.files.Add(b);}
  progress(LiveryOnly?"Checking livery upgrade...":"Checking all five components...");int checkedFiles=0;
  foreach(var f in files){
   if(LiveryOnly||++checkedFiles%100==0)progress("Checking: "+(LiveryOnly?++checkedFiles:checkedFiles)+" / "+files.Count);
   string target=Location(f,root,saved),current=Hash(target);Baseline b;baseline.TryGetValue(f.Key,out b);
   var c=new Change{item=f,target=target,current=current,original=b};
   if(f.patch){
    if(current==null)throw new Exception("Missing F-4E script: "+f.path);
    string clean=Clean(Encoding.UTF8.GetString(File.ReadAllBytes(target))),block="";
    if(install)using(var r=new StreamReader(zip.GetEntry(Entry(f,"patch")).Open()))block=r.ReadToEnd();
    c.bytes=Encoding.UTF8.GetBytes(clean+block);c.desired=BytesHash(c.bytes);
   }else if(f.dynamic){
    bool knownLivery=f.scope=="saved"&&f.path.Replace('\\','/').StartsWith("Liveries/F-4E-45MC/F4E-FOX PLATOON/",StringComparison.OrdinalIgnoreCase)&&current!=null&&(current==f.after||(f.accepted!=null&&Array.IndexOf(f.accepted,current)>=0));
    if(b!=null&&current!=b.installed&&current!=b.hash&&!knownLivery)throw new Exception("A managed file was changed after installation. No files were changed:\n"+target);
    if(!install&&b==null)continue;c.desired=install?f.after:b.hash;
    if(install){if(b==null)b=new Baseline{key=f.Key,path=f.path,scope=f.scope,hash=current};b.installed=f.after;c.original=b;next.files.Add(b);}
   }else{
    if(current!=f.before&&current!=f.after&&(f.legacy==null||current!=f.legacy)&&(f.accepted==null||Array.IndexOf(f.accepted,current)<0))throw new Exception("Unsupported or modified F-4E file. No files were changed:\n"+target+"\nThis package supports the F-4E version used to build it.");c.desired=install?f.after:f.before;
   }
   if(c.desired!=current||(install&&f.dynamic&&c.original.backup==null&&c.original.hash!=null))changes.Add(c);
  }
  string work=Target(root,@"NikoWSO_Backups\"+DateTime.Now.ToString("yyyyMMdd-HHmmss")+"-"+Guid.NewGuid().ToString("N").Substring(0,8));Directory.CreateDirectory(work);int n=0;
  foreach(var c in changes){
   c.backup=Target(work,"original/"+c.item.Key);c.staged=Target(work,"staged/"+c.item.Key);
   if(c.current!=null)CopyVerified(c.target,c.backup,c.current);
   if(install&&c.item.dynamic&&c.original.backup==null&&c.original.hash!=null)c.original.backup=c.backup;
   if(c.desired!=null){if(c.bytes!=null){Directory.CreateDirectory(Path.GetDirectoryName(c.staged));File.WriteAllBytes(c.staged,c.bytes);}else if(!install&&c.item.dynamic)CopyVerified(c.original.backup,c.staged,c.desired);else Extract(Entry(c.item,install?"after":"before"),c.staged,c.desired);if(Hash(c.staged)!=c.desired)throw new Exception("Staging verification failed: "+c.item.path);}
   if(++n%100==0||LiveryOnly)progress("Preparing and verifying backups: "+n+" / "+changes.Count);
  }
  var attempted=new List<Change>();bool stateTouched=false;
  File.WriteAllText(Path.Combine(work,"transaction.json"),Json().Serialize(changes.ConvertAll(c=>new {target=c.target,original=c.current,backup=c.backup,desired=c.desired})));
  try{
   foreach(var c in changes){if(Hash(c.target)!=c.current)throw new Exception("A file changed during the operation: "+c.target);attempted.Add(c);Directory.CreateDirectory(Path.GetDirectoryName(c.target));if(c.desired==null)File.Delete(c.target);else CopyVerified(c.staged,c.target,c.desired);if(attempted.Count%100==0||LiveryOnly)progress((install?"Installing":"Restoring")+": "+attempted.Count+" / "+changes.Count);}
   stateTouched=true;
   if(install||(LiveryOnly&&next.files.Count>0)){string pending=Path.Combine(work,"next-state.json");File.WriteAllText(pending,Json().Serialize(next));if(File.Exists(statePath))File.Replace(pending,statePath,Path.Combine(work,"previous-state.json"));else File.Move(pending,statePath);}else if(File.Exists(statePath))File.Delete(statePath);
  }catch(Exception error){var failures=new List<string>();attempted.Reverse();foreach(var c in attempted)try{if(c.current==null)File.Delete(c.target);else CopyVerified(c.backup,c.target,c.current);}catch(Exception e){failures.Add(e.Message);}if(stateTouched)try{if(oldState==null)File.Delete(statePath);else File.WriteAllBytes(statePath,oldState);}catch(Exception e){failures.Add(e.Message);}throw new Exception(error.Message+"\n"+(failures.Count==0?"All changes from this operation were rolled back.":"Rollback needs attention. Keep backups at "+work+"\n"+String.Join("\n",failures)));}
  progress((LiveryOnly?(install?"Livery upgraded.":"Livery restored."):(install?"All five components installed.":"All five components restored."))+"\r\nAvionics preserved.\r\nBackups: "+work);
 }
 public void SelfTest(string root,string previous){
  if(Directory.Exists(root)||File.Exists(root))throw new Exception("Test directory must not exist");fixture=true;Directory.CreateDirectory(root);string saved=Target(root,"SavedProfile");Directory.CreateDirectory(saved);
  var original=new Dictionary<string,string>();var scripts=new Dictionary<string,string>();
  foreach(var f in files){string target=Location(f,root,saved);if(!f.dynamic&&f.before!=null)Extract(Entry(f,"before"),target,f.before);if(f.patch){File.AppendAllText(target,"\n-- USER_AVIONICS_MOD_MUST_SURVIVE\n");scripts[f.Key]=File.ReadAllText(target);}if(f.dynamic&&original.Count%3==0){Directory.CreateDirectory(Path.GetDirectoryName(target));File.WriteAllText(target,"USER_RESOURCE_"+f.Key);}original[f.Key]=Hash(target);}
  if(previous!=null)using(var s=File.OpenRead(previous))using(var z=new ZipArchive(s,ZipArchiveMode.Read))foreach(var f in files){if(f.dynamic)continue;var e=z.GetEntry(Entry(f,f.patch?"patch":"after"));if(e==null)continue;string target=Location(f,root,saved);Directory.CreateDirectory(Path.GetDirectoryName(target));if(f.patch)using(var r=new StreamReader(e.Open()))File.AppendAllText(target,r.ReadToEnd());else using(var src=e.Open())using(var dst=File.Create(target))src.CopyTo(dst);}
  Action<string> silent=delegate(string x){File.WriteAllText(Path.Combine(root,"last-status.txt"),x);};Apply(root,saved,true,silent);Apply(root,saved,true,silent);
  foreach(var f in files)if(!f.patch&&Hash(Location(f,root,saved))!=f.after)throw new Exception("Install mismatch: "+f.Key);
  foreach(var f in files)if(f.patch){string extra="\n-- USER_EDIT_AFTER_NIKO_INSTALL\n";File.AppendAllText(Location(f,root,saved),extra);scripts[f.Key]+=extra;}
  var conflict=files.Find(f=>f.dynamic);string ct=Location(conflict,root,saved);File.AppendAllText(ct,"CONFLICT");bool refused=false;try{Apply(root,saved,false,silent);}catch{refused=true;}if(!refused)throw new Exception("Conflict was not refused");
  foreach(var f in files)if(!f.patch&&f!=conflict&&Hash(Location(f,root,saved))!=f.after)throw new Exception("Conflict changed another file");Extract(Entry(conflict,"after"),ct,conflict.after);
  Apply(root,saved,false,silent);Apply(root,saved,false,silent);
  foreach(var f in files){string target=Location(f,root,saved);if(f.patch){if(File.ReadAllText(target)!=scripts[f.Key])throw new Exception("Avionics changed");}else if(Hash(target)!=original[f.Key])throw new Exception("Restore mismatch: "+f.Key);}
  File.WriteAllText(Path.Combine(root,"test-result.txt"),"PASS: all components; v5 upgrade; repeat install/restore; conflict refusal; exact pre-existing addon restoration; new addon removal; user avionics preserved; actual game untouched.");
 }
}
public class MainForm:Form {
 TextBox game=new TextBox(),saved=new TextBox(),status=new TextBox();Button install=new Button(),restore=new Button();Panel panel=new Panel();bool busy;
 public MainForm(){
  Text=Package.LiveryOnly?"FOX PLATOON - Temporary Livery Upgrade":"F4E-Niko WSO v7";Icon=Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);ClientSize=new Size(1120,700);FormBorderStyle=FormBorderStyle.FixedSingle;MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;Font=new Font("Segoe UI",10);DoubleBuffered=true;
  using(var s=Assembly.GetExecutingAssembly().GetManifestResourceStream("background.png"))BackgroundImage=new Bitmap(s);BackgroundImageLayout=ImageLayout.Stretch;
  panel.SetBounds(724,24,372,652);panel.BackColor=Color.FromArgb(28,30,44);panel.ForeColor=Color.White;Controls.Add(panel);
  LabelAt(Package.LiveryOnly?"FOX PLATOON":"F4E-Niko WSO",24,20,324,62,25,FontStyle.Bold);LabelAt("F-4E  /  REAR WSO",28,84,320,28,12,FontStyle.Bold);LabelAt(Package.LiveryOnly?"TEMPORARY UPGRADE  /  v0.13":"COMPLETE PACKAGE  /  v7",28,125,320,25,10,FontStyle.Bold);
  LabelAt(Package.LiveryOnly?"Livery textures only\nDarker camouflage\nEnhanced rivets and panel seams\nExisting WSO and audio retained":"Rear-seat model & first-person body\nJester portrait & voice\nTape Player music\nFOX PLATOON v0.13 livery",28,160,320,100,11,FontStyle.Regular);
  LabelAt("DCS WORLD FOLDER",28,278,310,22,9,FontStyle.Bold);game.Text=@"D:\DCS\DCS World";AddPath(game,304);
  LabelAt("SAVED GAMES PROFILE",28,351,310,22,9,FontStyle.Bold);string home=Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);saved.Text=Path.Combine(home,@"Saved Games\DCS");AddPath(saved,377);
  install.Text="Install All";install.SetBounds(28,432,153,44);install.BackColor=Color.FromArgb(243,181,202);install.ForeColor=Color.FromArgb(28,30,44);restore.Text="Restore All";restore.SetBounds(191,432,153,44);restore.BackColor=Color.FromArgb(66,71,94);
  if(Package.LiveryOnly){install.Text="Upgrade Livery";restore.Text="Restore Livery";}
  foreach(var b in new[]{install,restore}){b.FlatStyle=FlatStyle.Flat;b.FlatAppearance.BorderSize=0;b.Font=new Font("Segoe UI",11,FontStyle.Bold);panel.Controls.Add(b);}
  status.SetBounds(28,495,316,124);status.Multiline=true;status.ReadOnly=true;status.BorderStyle=BorderStyle.None;status.BackColor=panel.BackColor;status.ForeColor=Color.FromArgb(216,218,229);status.ScrollBars=ScrollBars.Vertical;status.Text="Close DCS before continuing.\r\nAll five components are handled together.\r\nYour existing files are backed up.\r\nAvionics are preserved.";panel.Controls.Add(status);
  if(Package.LiveryOnly)status.Text="Close DCS before continuing.\r\nOnly FOX PLATOON livery files are updated.\r\nOther bundle components and their restore records are retained.";
  install.Click+=delegate{Run(true);};restore.Click+=delegate{Run(false);};FormClosing+=delegate(object sender,FormClosingEventArgs e){if(busy)e.Cancel=true;};
 }
 void LabelAt(string text,int x,int y,int w,int h,float size,FontStyle style){panel.Controls.Add(new Label{Text=text,UseMnemonic=false,Left=x,Top=y,Width=w,Height=h,Font=new Font("Segoe UI",size,style),ForeColor=Color.White});}
 void AddPath(TextBox box,int y){box.SetBounds(28,y,265,28);panel.Controls.Add(box);var b=new Button{Text="...",Left=301,Top=y-1,Width=43,Height=28,BackColor=Color.FromArgb(66,71,94),FlatStyle=FlatStyle.Flat};panel.Controls.Add(b);b.Click+=delegate{using(var d=new FolderBrowserDialog()){d.Description="Select the folder";d.SelectedPath=box.Text;if(d.ShowDialog()==DialogResult.OK)box.Text=d.SelectedPath;}};}
 void Run(bool installing){if(busy)return;busy=true;string g=game.Text,s=saved.Text;foreach(Control c in panel.Controls)if(c!=status)c.Enabled=false;status.Text="Opening package...";Task.Factory.StartNew(delegate{try{using(var p=new Package())p.Apply(g,s,installing,delegate(string text){BeginInvoke((Action)delegate{status.Text=text;});});}catch(Exception e){BeginInvoke((Action)delegate{status.Text="Operation not completed.\r\n"+e.Message;});}finally{BeginInvoke((Action)delegate{busy=false;foreach(Control c in panel.Controls)c.Enabled=true;});}});}
 [STAThread]static int Main(string[] args){try{if(args.Length>=2&&args[0]=="--self-test"){using(var p=new Package())p.SelfTest(args[1],args.Length>2?args[2]:null);return 0;}Application.EnableVisualStyles();var form=new MainForm();if(args.Length==2&&args[0]=="--preview"){form.Show();Application.DoEvents();using(var b=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(b,new Rectangle(Point.Empty,b.Size));b.Save(args[1]);}form.Dispose();return 0;}Application.Run(form);return 0;}catch(Exception e){if(args.Length>=2)File.WriteAllText(args[1]+"-error.txt",e.ToString());else MessageBox.Show(e.Message,"F4E-Niko WSO",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}}
}

