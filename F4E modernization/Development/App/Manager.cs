using System;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using System.Threading.Tasks;
class Manager : Form {
 TextBox dcs=new TextBox(), saved=new TextBox(), log=new TextBox();
 Button install=new Button(), restore=new Button(), check=new Button(); bool busy;
 static string home=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"F4ModernAvionics");
 static string Extract(string dest) {
  Directory.CreateDirectory(dest);
  using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))
  using(var zip=new ZipArchive(stream,ZipArchiveMode.Read)) foreach(var entry in zip.Entries) {
   var target=Path.GetFullPath(Path.Combine(dest,entry.FullName));
   if(!target.StartsWith(Path.GetFullPath(dest)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)) throw new Exception("Invalid payload path.");
   if(entry.FullName.EndsWith("/")) {Directory.CreateDirectory(target);continue;}
   Directory.CreateDirectory(Path.GetDirectoryName(target));
   using(var input=entry.Open()) using(var output=File.Create(target)) input.CopyTo(output);
  }
  return dest;
 }
 [STAThread] static void Main(string[] args) {
  try {
   if(args.Length==2 && args[0]=="--extract-to") {Extract(args[1]);return;}
   Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new Manager());
  } catch(Exception e){MessageBox.Show(e.Message,"F-4E Installer");Environment.ExitCode=1;}
 }
 Manager() {
  Text="F-4E Radar and HUD (including CCIP)";ClientSize=new Size(740,490);Font=new Font("Segoe UI",10);StartPosition=FormStartPosition.CenterScreen;
  Controls.Add(new Label{Text="Install / restore radar + HUD (including CCIP). Native RWR retained.",Left=18,Top=15,Width=700,Height=30});
  Row("DCS installation folder",dcs,52);Row("Saved Games / DCS",saved,122);
  dcs.Text=@"D:\DCS\DCS World";saved.Text=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"Saved Games","DCS");
  var cfg=Path.Combine(home,"paths.txt");if(File.Exists(cfg)){var lines=File.ReadAllLines(cfg);if(lines.Length==2){dcs.Text=lines[0];saved.Text=lines[1];}}
  install.Text="Install";restore.Text="Restore";check.Text="Check status";
  Button[] buttons={install,restore,check};string[] actions={"Install","Restore","Check"};
  for(int i=0;i<3;i++){var b=buttons[i];b.SetBounds(18+i*235,198,220,40);Controls.Add(b);string action=actions[i];b.Click+=async (s,e)=>await Run(action);}
  log.SetBounds(18,252,704,218);log.Multiline=true;log.ScrollBars=ScrollBars.Vertical;log.ReadOnly=true;Controls.Add(log);
  log.Text="Exit DCS before installing or restoring.\r\nRuntime files and backups: %LOCALAPPDATA%\\F4ModernAvionics. DCS repair does not remove them.\r\nSupports DCS 2.9.31.29434. Conflicting cockpit modifications stop installation.";
  FormClosing+=(s,e)=>{if(busy)e.Cancel=true;};
 }
 void Row(string title,TextBox box,int y){Controls.Add(new Label{Text=title,Left=18,Top=y,Width=650,Height=24});box.SetBounds(18,y+26,610,28);Controls.Add(box);var browse=new Button{Text="Browse",Left=638,Top=y+24,Width=84,Height=30};Controls.Add(browse);browse.Click+=(s,e)=>{using(var dialog=new FolderBrowserDialog()){dialog.SelectedPath=box.Text;if(dialog.ShowDialog()==DialogResult.OK)box.Text=dialog.SelectedPath;}};}
 static string Q(string value){if(value.IndexOfAny(new[]{'"','\r','\n'})>=0)throw new Exception("Path contains unsupported characters.");return "\""+value.TrimEnd('\\')+"\"";}
 async Task Run(string action){
  busy=true;install.Enabled=restore.Enabled=check.Enabled=dcs.Enabled=saved.Enabled=false;
  try {
   Directory.CreateDirectory(home);File.WriteAllLines(Path.Combine(home,"paths.txt"),new[]{dcs.Text,saved.Text});
   string payload=Extract(Path.Combine(home,"Payloads",Guid.NewGuid().ToString("N")));
   var info=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe"),"-NoProfile -ExecutionPolicy Bypass -File "+Q(Path.Combine(payload,"Manager.ps1"))+" -Action "+action+" -DcsRoot "+Q(dcs.Text)+" -SavedGames "+Q(saved.Text));
   info.UseShellExecute=false;info.CreateNoWindow=true;info.RedirectStandardOutput=true;info.RedirectStandardError=true;info.StandardOutputEncoding=System.Text.Encoding.UTF8;info.StandardErrorEncoding=System.Text.Encoding.UTF8;
   log.Text="Working, please wait...";
   using(var p=Process.Start(info)){var stdout=p.StandardOutput.ReadToEndAsync();var stderr=p.StandardError.ReadToEndAsync();await Task.Run(()=>p.WaitForExit());log.Text=await stdout+"\r\n"+await stderr;File.AppendAllText(Path.Combine(home,"manager.log"),DateTime.Now+" "+action+"\r\n"+log.Text+"\r\n");if(p.ExitCode!=0)log.AppendText("\r\nOperation failed; see the reason above. If the destination requires elevated permissions, right-click this program and run as administrator.");}
  } catch(Exception e){log.Text=e.ToString();} finally{busy=false;install.Enabled=restore.Enabled=check.Enabled=dcs.Enabled=saved.Enabled=true;}
 }
}
