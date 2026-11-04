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
   if(!target.StartsWith(Path.GetFullPath(dest)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)) throw new Exception("无效的安装源路径。");
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
  } catch(Exception e){MessageBox.Show(e.Message,"F-4E 安装管理器");Environment.ExitCode=1;}
 }
 Manager() {
  Text="F-4E 雷达与 HUD（含 CCIP）";ClientSize=new Size(740,490);Font=new Font("Microsoft YaHei UI",10);StartPosition=FormStartPosition.CenterScreen;
  Controls.Add(new Label{Text="雷达 + HUD（含 CCIP）整体安装 / 还原，原装 RWR 保留。",Left=18,Top=15,Width=700,Height=30});
  Row("DCS 安装目录",dcs,52);Row("Saved Games / DCS",saved,122);
  dcs.Text=@"D:\DCS\DCS World";saved.Text=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"Saved Games","DCS");
  var cfg=Path.Combine(home,"paths.txt");if(File.Exists(cfg)){var lines=File.ReadAllLines(cfg);if(lines.Length==2){dcs.Text=lines[0];saved.Text=lines[1];}}
  install.Text="一键安装";restore.Text="一键还原";check.Text="检查状态";
  Button[] buttons={install,restore,check};string[] actions={"Install","Restore","Check"};
  for(int i=0;i<3;i++){var b=buttons[i];b.SetBounds(18+i*235,198,220,40);Controls.Add(b);string action=actions[i];b.Click+=async (s,e)=>await Run(action);}
  log.SetBounds(18,252,704,218);log.Multiline=true;log.ScrollBars=ScrollBars.Vertical;log.ReadOnly=true;Controls.Add(log);
  log.Text="请退出 DCS 后安装或还原。\r\n运行文件和备份存放在 %LOCALAPPDATA%\\F4ModernAvionics，游戏修复不会清除它们。\r\n适配 DCS 2.9.31.29434；已有其他座舱修改时会停止。";
  FormClosing+=(s,e)=>{if(busy)e.Cancel=true;};
 }
 void Row(string title,TextBox box,int y){Controls.Add(new Label{Text=title,Left=18,Top=y,Width=650,Height=24});box.SetBounds(18,y+26,610,28);Controls.Add(box);var browse=new Button{Text="浏览",Left=638,Top=y+24,Width=84,Height=30};Controls.Add(browse);browse.Click+=(s,e)=>{using(var dialog=new FolderBrowserDialog()){dialog.SelectedPath=box.Text;if(dialog.ShowDialog()==DialogResult.OK)box.Text=dialog.SelectedPath;}};}
 static string Q(string value){if(value.IndexOfAny(new[]{'"','\r','\n'})>=0)throw new Exception("路径包含不支持的字符。");return "\""+value.TrimEnd('\\')+"\"";}
 async Task Run(string action){
  busy=true;install.Enabled=restore.Enabled=check.Enabled=dcs.Enabled=saved.Enabled=false;
  try {
   Directory.CreateDirectory(home);File.WriteAllLines(Path.Combine(home,"paths.txt"),new[]{dcs.Text,saved.Text});
   string payload=Extract(Path.Combine(home,"Payloads",Guid.NewGuid().ToString("N")));
   var info=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe"),"-NoProfile -ExecutionPolicy Bypass -File "+Q(Path.Combine(payload,"Manager.ps1"))+" -Action "+action+" -DcsRoot "+Q(dcs.Text)+" -SavedGames "+Q(saved.Text));
   info.UseShellExecute=false;info.CreateNoWindow=true;info.RedirectStandardOutput=true;info.RedirectStandardError=true;info.StandardOutputEncoding=System.Text.Encoding.UTF8;info.StandardErrorEncoding=System.Text.Encoding.UTF8;
   log.Text="正在执行，请稍候……";
   using(var p=Process.Start(info)){var stdout=p.StandardOutput.ReadToEndAsync();var stderr=p.StandardError.ReadToEndAsync();await Task.Run(()=>p.WaitForExit());log.Text=await stdout+"\r\n"+await stderr;File.AppendAllText(Path.Combine(home,"manager.log"),DateTime.Now+" "+action+"\r\n"+log.Text+"\r\n");if(p.ExitCode!=0)log.AppendText("\r\n操作失败；请查看以上原因。需要写入受保护目录时，可右键以管理员身份运行本程序。");}
  } catch(Exception e){log.Text=e.ToString();} finally{busy=false;install.Enabled=restore.Enabled=check.Enabled=dcs.Enabled=saved.Enabled=true;}
 }
}
