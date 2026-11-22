using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using System.Security.Cryptography;
using System.Web.Script.Serialization;
using System.Threading;
using System.Reflection;
using System.IO.Compression;

[assembly:AssemblyTitle("F4E FOX SENSE Setup")]
[assembly:AssemblyProduct("F4E FOX SENSE")]
[assembly:AssemblyDescription("DCS F-4E HUD installer")]
[assembly:AssemblyVersion("0.10.13.0")]
[assembly:AssemblyFileVersion("0.10.13.0")]

public sealed class FoxConfig { public string AppRoot; public string DcsRoot; public string JesterRoot; public string Version; public string GameRoot; public string PortraitStatus; public bool ReplacePortrait; }
public sealed class FoxChange { public string Target; public string Backup; public string InstalledHash; public bool Existed; }
public sealed class FoxManifest { public List<FoxChange> Changes = new List<FoxChange>(); }
internal sealed class FoxPlan { public string Target; public byte[] Bytes; public FoxChange Previous; }
internal static partial class Fox {
    const string Version="0.10.13";
    const string Loader="\r\n-- F4RWRLINK_BEGIN\r\ndofile(lfs.writedir() .. [[Scripts/F4RwrLink/ExportBridge.lua]])\r\n-- F4RWRLINK_END\r\n";
    static readonly UTF8Encoding Utf8=new UTF8Encoding(false);
    static readonly JavaScriptSerializer Json=new JavaScriptSerializer();
    static string BaseRoot { get { return AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\'); } }
    static string Full(string p) { return Path.GetFullPath(p).TrimEnd('\\'); }
    static bool OneDrive(string p) { return Regex.IsMatch(Full(p),@"(^|[\\/])OneDrive[^\\/]*([\\/]|$)",RegexOptions.IgnoreCase); }
    static string Hash(byte[] b) { using(SHA256 s=SHA256.Create())return BitConverter.ToString(s.ComputeHash(b)).Replace("-",""); }
    static byte[] Data(string key) {
        using(Stream stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("Fox.Payload.zip")) {
            if(stream==null)throw new IOException("Installer resources are missing.");
            using(ZipArchive archive=new ZipArchive(stream,ZipArchiveMode.Read)) {
                ZipArchiveEntry entry=archive.GetEntry(key);if(entry==null)throw new IOException("Missing installer resource: "+key);
                using(Stream input=entry.Open())using(MemoryStream output=new MemoryStream()){input.CopyTo(output);return output.ToArray();}
            }
        }
    }
    static void WriteJson(string path,object value) { File.WriteAllText(path,Json.Serialize(value),Utf8); }
    static T ReadJson<T>(string path) { return Json.Deserialize<T>(File.ReadAllText(path)); }
    static bool GameRunning() { return Process.GetProcessesByName("DCS").Length>0; }
    const string PortraitRelative=@"Mods\aircraft\F-4E\UI\JesterSubtitle\img\jester_portrait.png";
    static string PortraitPath(FoxConfig c) { return Path.Combine(c.GameRoot,PortraitRelative); }
    static void RestorePortrait(FoxConfig c,bool guardGame=true) {
        Validate(c);if(guardGame&&GameRunning())throw new IOException("Close DCS before restoring the portrait.");
        if(String.IsNullOrWhiteSpace(c.GameRoot))throw new IOException("Select the DCS game folder.");
        string path=Path.Combine(c.AppRoot,"install-manifest.json");FoxManifest manifest=ReadJson<FoxManifest>(path);
        FoxChange entry=manifest.Changes.Find(delegate(FoxChange x){return x.Target.Equals(PortraitPath(c),StringComparison.OrdinalIgnoreCase);});
        if(entry==null)throw new IOException("No portrait replacement is recorded for this game folder.");
        if(!File.Exists(entry.Target)||Hash(File.ReadAllBytes(entry.Target))!=entry.InstalledHash)throw new IOException("The portrait has changed since installation. It was not overwritten.");
        if(!entry.Existed||!File.Exists(entry.Backup))throw new IOException("Original portrait backup is missing.");
        File.WriteAllBytes(entry.Target,File.ReadAllBytes(entry.Backup));manifest.Changes.Remove(entry);WriteJson(path,manifest);
    }
    static void CheckPath(string path) { if(OneDrive(path))throw new IOException("Choose a folder outside OneDrive.\n"+path); }
    static void Validate(FoxConfig c,bool discoverGame=true) {
        string game=discoverGame?FindGameRoot(c.AppRoot,c.DcsRoot,c.GameRoot):ValidGameRoot(c.GameRoot);
        c.GameRoot=game;
        c.PortraitStatus=!c.ReplacePortrait?"Portrait skipped: not selected. Current game image left unchanged.":String.IsNullOrEmpty(game)?"Portrait skipped: F-4E portrait path not found. HUD installation is unaffected.":"Jester portrait installed with original backup.";
        if(!String.IsNullOrEmpty(game))CheckPath(game);
        c.AppRoot=Full(c.AppRoot);c.DcsRoot=Full(c.DcsRoot);c.JesterRoot=Full(c.JesterRoot);
        CheckPath(c.AppRoot);CheckPath(c.DcsRoot);CheckPath(c.JesterRoot);
        if(c.DcsRoot.Contains("]]"))throw new IOException("The profile path cannot contain ]].");
        string name=new DirectoryInfo(c.DcsRoot).Name;
        if(!name.Equals("DCS",StringComparison.OrdinalIgnoreCase)&&!name.StartsWith("DCS.",StringComparison.OrdinalIgnoreCase))throw new IOException("Select the DCS or DCS.* profile folder under Saved Games.");
        if(Directory.Exists(Path.Combine(c.DcsRoot,"CoreMods")))throw new IOException("Select a Saved Games profile, not the DCS game installation.");
        if(!new DirectoryInfo(c.JesterRoot).Name.Equals("mods",StringComparison.OrdinalIgnoreCase))throw new IOException("The Jester folder must end with jester\\mods.");
        if(!new DirectoryInfo(c.JesterRoot).Parent.Name.Equals("jester",StringComparison.OrdinalIgnoreCase))throw new IOException("Select DCS_F4E\\jester\\mods.");
        string modsRoot=Path.Combine(c.DcsRoot,"Mods");
        bool insideDcs=c.AppRoot.Equals(c.DcsRoot,StringComparison.OrdinalIgnoreCase)||c.AppRoot.StartsWith(c.DcsRoot+"\\",StringComparison.OrdinalIgnoreCase);
        bool insideMods=c.AppRoot.StartsWith(modsRoot+"\\",StringComparison.OrdinalIgnoreCase);
        if((insideDcs&&!insideMods)||c.AppRoot.Equals(c.JesterRoot,StringComparison.OrdinalIgnoreCase)||c.AppRoot.StartsWith(c.JesterRoot+"\\",StringComparison.OrdinalIgnoreCase))throw new IOException("Use a separate subfolder under DCS\\Mods. Do not use the profile root, Scripts, or Jester folder.");
    }
    static string FindLogPath(FoxConfig c) { return Path.Combine(c.DcsRoot,@"Logs\F4RwrProbe.log"); }
    static byte[] Probe(FoxConfig c) {
        string s=Utf8.GetString(Data("Bridge/F4RwrProbe.lua"));
        return Utf8.GetBytes(s.Replace(@"__FOX_PROBE_LOG__",FindLogPath(c)));
    }
    static byte[] ExportBytes(string export) {
        if(!File.Exists(export))return Utf8.GetBytes(Loader);
        byte[] original=File.ReadAllBytes(export);string text;Encoding encoding;
        using(StreamReader sr=new StreamReader(export,Encoding.UTF8,true)){text=sr.ReadToEnd();encoding=sr.CurrentEncoding;}
        if(text.Contains("dofile(lfs.writedir() .. [[Scripts/F4RwrLink/ExportBridge.lua]])"))return original;
        if(text.Contains("F4RWRLINK_BEGIN"))throw new IOException("Export.lua contains a different F4RwrLink loader. Review it before installing. No external files have been changed.");
        byte[] tail=encoding.GetBytes(Loader);byte[] combined=new byte[original.Length+tail.Length];
        Buffer.BlockCopy(original,0,combined,0,original.Length);Buffer.BlockCopy(tail,0,combined,original.Length,tail.Length);return combined;
    }
    static List<FoxPlan> Plans(FoxConfig c,FoxManifest manifest) {
        List<FoxPlan> plans=new List<FoxPlan>();
        plans.Add(new FoxPlan{Target=Path.Combine(c.DcsRoot,@"Scripts\Export.lua"),Bytes=ExportBytes(Path.Combine(c.DcsRoot,@"Scripts\Export.lua"))});
        plans.Add(new FoxPlan{Target=Path.Combine(c.DcsRoot,@"Scripts\F4RwrLink\ExportBridge.lua"),Bytes=Data("Bridge/ExportBridge.lua")});
        plans.Add(new FoxPlan{Target=Path.Combine(c.DcsRoot,@"Scripts\F4RwrLink\FoxBridgeActivity.lua"),Bytes=Data("Bridge/FoxBridgeActivity.lua")});
        plans.Add(new FoxPlan{Target=Path.Combine(c.DcsRoot,@"Scripts\Hooks\FoxViewFov.lua"),Bytes=Data("Bridge/FoxViewFov.lua")});
        plans.Add(new FoxPlan{Target=Path.Combine(c.JesterRoot,"F4RwrProbe.lua"),Bytes=Probe(c)});
        plans.Add(new FoxPlan{Target=Path.Combine(c.JesterRoot,@"init\StartF4RwrProbe.lua"),Bytes=Data("Bridge/StartF4RwrProbe.lua")});
        if(c.ReplacePortrait&&!String.IsNullOrWhiteSpace(c.GameRoot))plans.Add(new FoxPlan{Target=PortraitPath(c),Bytes=Data("Portrait/jester_portrait.png")});
        foreach(FoxPlan p in plans) {
            p.Previous=manifest.Changes.Find(delegate(FoxChange old){return old.Target.Equals(p.Target,StringComparison.OrdinalIgnoreCase);});
            if(!File.Exists(p.Target)||Hash(File.ReadAllBytes(p.Target))==Hash(p.Bytes))continue;
            if(p.Target.EndsWith("Export.lua",StringComparison.OrdinalIgnoreCase))continue;
            if(!String.IsNullOrWhiteSpace(c.GameRoot)&&p.Target.Equals(PortraitPath(c),StringComparison.OrdinalIgnoreCase)&&p.Previous==null)continue; // Explicit portrait replacement; original is backed up.
            string hash=Hash(File.ReadAllBytes(p.Target));
            if(p.Previous!=null&&p.Previous.InstalledHash==hash)continue;
            if(Array.IndexOf(KnownHashes,hash)<0)throw new IOException("This file differs from a known version and was not overwritten:\n"+p.Target);
        }
        return plans;
    }
    static FoxManifest Install(FoxConfig c,bool shortcuts,bool guardGame,bool discoverGame=true) {
        Validate(c,discoverGame);c.Version=Version;
        string manifestPath=Path.Combine(c.AppRoot,"install-manifest.json");
        FoxManifest manifest=File.Exists(manifestPath)?ReadJson<FoxManifest>(manifestPath):new FoxManifest();
        List<FoxPlan> plans=Plans(c,manifest);
        bool change=false;foreach(FoxPlan p in plans)if(!File.Exists(p.Target)||Hash(File.ReadAllBytes(p.Target))!=Hash(p.Bytes))change=true;
        if(guardGame&&change&&GameRunning())throw new IOException("This installation needs to update the bridge or portrait. Close DCS and try again. Normal HUD startup can connect to a running game.");
        Directory.CreateDirectory(c.AppRoot);
        string runtime=Path.Combine(c.AppRoot,"Runtime");Directory.CreateDirectory(runtime);
        foreach(KeyValuePair<string,string> item in Payload) {
            if(!item.Key.StartsWith("Overlay/",StringComparison.Ordinal))continue;
            string dest=Path.Combine(runtime,item.Key.Replace('/',Path.DirectorySeparatorChar));Directory.CreateDirectory(Path.GetDirectoryName(dest));
            byte[] bytes=Data(item.Key);
            if(!File.Exists(dest)||Hash(File.ReadAllBytes(dest))!=Hash(bytes))File.WriteAllBytes(dest,bytes);
        }
        File.WriteAllBytes(Path.Combine(c.AppRoot,"logo.png"),Data("Branding/logo.png"));
        File.WriteAllBytes(Path.Combine(c.AppRoot,"F4E FOX SENSE.ico"),Data("Branding/F4E FOX SENSE.ico"));
        string settings=Path.Combine(runtime,"HudSettings.json");
        if(!File.Exists(settings))File.WriteAllBytes(settings,Data("Defaults/HudSettings.json"));
        List<FoxPlan> written=new List<FoxPlan>();Dictionary<string,byte[]> rollback=new Dictionary<string,byte[]>();
        try {
            foreach(FoxPlan p in plans) {
                bool exists=File.Exists(p.Target);if(exists&&Hash(File.ReadAllBytes(p.Target))==Hash(p.Bytes))continue;
                rollback[p.Target]=exists?File.ReadAllBytes(p.Target):null;
                FoxChange entry=p.Previous;
                if(entry==null){
                    entry=new FoxChange{Target=p.Target,Existed=exists};
                    if(exists){string folder=Path.Combine(c.AppRoot,"Backups");Directory.CreateDirectory(folder);entry.Backup=Path.Combine(folder,DateTime.Now.ToString("yyyyMMdd-HHmmss-fff")+"-"+manifest.Changes.Count+".bak");File.Copy(p.Target,entry.Backup,false);}
                    manifest.Changes.Add(entry);
                }
                Directory.CreateDirectory(Path.GetDirectoryName(p.Target));File.WriteAllBytes(p.Target,p.Bytes);written.Add(p);entry.InstalledHash=Hash(p.Bytes);
            }
            string exe=Path.Combine(c.AppRoot,"F4E FOX SENSE.exe");
            File.WriteAllBytes(exe,Data("App/F4E FOX SENSE.exe"));
            WriteJson(Path.Combine(c.AppRoot,"fox-config.json"),c);WriteJson(manifestPath,manifest);
            if(shortcuts)CreateShortcut(c);
        } catch {
            foreach(FoxPlan p in written){byte[] old=rollback[p.Target];if(old==null){if(File.Exists(p.Target))File.Delete(p.Target);}else File.WriteAllBytes(p.Target,old);}
            throw;
        }
        return manifest;
    }
    static void CreateShortcut(FoxConfig c) {
        string root=Environment.GetFolderPath(Environment.SpecialFolder.Programs);CheckPath(root);
        string path=Path.Combine(root,"F4E FOX SENSE.lnk");
        Type type=Type.GetTypeFromProgID("WScript.Shell");object shell=Activator.CreateInstance(type);
        object link=type.InvokeMember("CreateShortcut",BindingFlags.InvokeMethod,null,shell,new object[]{path});
        Type lt=link.GetType();
        lt.InvokeMember("TargetPath",BindingFlags.SetProperty,null,link,new object[]{Path.Combine(c.AppRoot,"F4E FOX SENSE.exe")});
        lt.InvokeMember("Arguments",BindingFlags.SetProperty,null,link,new object[]{"--launch"});
        lt.InvokeMember("WorkingDirectory",BindingFlags.SetProperty,null,link,new object[]{c.AppRoot});
        lt.InvokeMember("IconLocation",BindingFlags.SetProperty,null,link,new object[]{Path.Combine(c.AppRoot,"F4E FOX SENSE.ico")+",0"});
        lt.InvokeMember("Save",BindingFlags.InvokeMethod,null,link,null);
        System.Runtime.InteropServices.Marshal.FinalReleaseComObject(link);System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shell);
    }
    static int RunHud(FoxConfig c,string mode,out string output) {
        ProcessStartInfo info=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe"));
        info.Arguments="-NoProfile -STA -ExecutionPolicy RemoteSigned -File \""+Path.Combine(c.AppRoot,@"Runtime\Overlay\Overlay.ps1")+"\" "+mode;
        info.WorkingDirectory=Path.Combine(c.AppRoot,"Runtime");info.UseShellExecute=false;info.CreateNoWindow=true;info.RedirectStandardError=true;info.RedirectStandardOutput=true;
        using(Process p=new Process()){
            p.StartInfo=info;StringBuilder text=new StringBuilder();
            p.OutputDataReceived+=delegate(object sender,DataReceivedEventArgs e){if(e.Data!=null)lock(text)text.AppendLine(e.Data);};
            p.ErrorDataReceived+=delegate(object sender,DataReceivedEventArgs e){if(e.Data!=null)lock(text)text.AppendLine(e.Data);};
            p.Start();p.BeginOutputReadLine();p.BeginErrorReadLine();p.WaitForExit();p.WaitForExit();output=text.ToString();return p.ExitCode;
        }
    }
    static int Launch(string root) {
        FoxConfig c=ReadJson<FoxConfig>(Path.Combine(root,"fox-config.json"));Validate(c);
        bool created;using(Mutex mutex=new Mutex(true,"Local\\F4E_FOX_SENSE",out created)){
            if(!created){MessageBox.Show("F4E FOX SENSE is already running.","F4E FOX SENSE");return 0;}
            string result;int code=RunHud(c,"-ProfileRoot \""+c.DcsRoot+"\"",out result);
            if(code!=0){File.WriteAllText(Path.Combine(c.AppRoot,"launch-error.txt"),result,Utf8);MessageBox.Show("The HUD could not start. Details were saved to launch-error.txt in the application folder.\n"+result,"F4E FOX SENSE");}
            return code;
        }
    }
    static TextBox Field(Form form,string label,string value,int y) {
        Label l=new Label{Text=label,Left=24,Top=y,Width=590,Height=20};form.Controls.Add(l);
        TextBox box=new TextBox{Text=value,Left=24,Top=y+23,Width=510};form.Controls.Add(box);
        Button b=new Button{Text="Browse",Left=542,Top=y+21,Width=68};form.Controls.Add(b);
        b.Click+=delegate{using(FolderBrowserDialog d=new FolderBrowserDialog()){d.SelectedPath=box.Text;if(d.ShowDialog(form)==DialogResult.OK)box.Text=d.SelectedPath;}};return box;
    }
    static Image LogoImage() {
        using(MemoryStream stream=new MemoryStream(Data("Branding/logo.png")))
        using(Image image=Image.FromStream(stream))return new Bitmap(image);
    }
    static Image SetupBackground() {
        using(MemoryStream stream=new MemoryStream(Data("Branding/setup-background.png")))
        using(Image image=Image.FromStream(stream))return new Bitmap(image);
    }
    static void ThemeControl(Control control) {
        control.ForeColor=Color.FromArgb(235,245,255);
        if(control is PictureBox)control.BackColor=Color.Transparent;
        if(control is Label)control.BackColor=Color.FromArgb(170,8,18,30);
        if(control is TextBox) {
            control.BackColor=Color.FromArgb(18,30,47);
            ((TextBox)control).BorderStyle=BorderStyle.FixedSingle;
        }
        Button button=control as Button;
        if(button!=null) {
            button.BackColor=Color.FromArgb(23,49,75);button.FlatStyle=FlatStyle.Flat;
            button.FlatAppearance.BorderColor=Color.FromArgb(75,156,194);
            button.FlatAppearance.MouseOverBackColor=Color.FromArgb(34,78,112);
        }
        foreach(Control child in control.Controls)ThemeControl(child);
    }
    static void ApplySetupTheme(Form form) {
        form.BackColor=Color.FromArgb(10,18,29);
        form.BackgroundImage=SetupBackground();form.BackgroundImageLayout=ImageLayout.Stretch;
        form.Paint+=delegate(object sender,PaintEventArgs e){using(Brush shade=new SolidBrush(Color.FromArgb(95,0,5,15)))e.Graphics.FillRectangle(shade,form.ClientRectangle);};
        foreach(Control child in form.Controls)ThemeControl(child);
    }
    static PictureBox LogoBox(int x,int y,int size) {
        return new PictureBox{Left=x,Top=y,Width=size,Height=size,SizeMode=PictureBoxSizeMode.Zoom,Image=LogoImage(),BackColor=Color.Black};
    }
    static void ShowComplete(IWin32Window owner,FoxConfig c) {
        string executable=Path.Combine(c.AppRoot,"F4E FOX SENSE.exe");
        using(Form done=new Form{Text="F4E FOX SENSE - Installation Complete",ClientSize=new Size(720,350),StartPosition=FormStartPosition.CenterParent,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,MinimizeBox=false,Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath)}) {
            done.Font=new Font("Segoe UI",9);
            done.Controls.Add(LogoBox(24,12,64));
            done.Controls.Add(new Label{Text="Installation complete",Font=new Font("Segoe UI",16,FontStyle.Bold),Left=104,Top=22,Width=590,Height=35});
            done.Controls.Add(new Label{Text="Installed folder",Left=24,Top=78,Width=670,Height=20});
            done.Controls.Add(new TextBox{Text=c.AppRoot,ReadOnly=true,Left=24,Top=103,Width=670,Height=26});
            done.Controls.Add(new Label{Text="Launch this application",Left=24,Top=148,Width=670,Height=20});
            done.Controls.Add(new TextBox{Text=executable,ReadOnly=true,Left=24,Top=173,Width=670,Height=26});
            done.Controls.Add(new Label{Text="You can also launch F4E FOX SENSE from the Start menu.\nAfter a Jester bridge update, re-enter the F-4E cockpit.\n"+c.PortraitStatus,Left=24,Top=215,Width=670,Height=62});
            Button folder=new Button{Text="Open Folder",Left=24,Top=290,Width=130,Height=36};done.Controls.Add(folder);
            Button launch=new Button{Text="Launch F4E FOX SENSE",Left=290,Top=290,Width=230,Height=36};done.Controls.Add(launch);
            Button close=new Button{Text="Done",Left=534,Top=290,Width=160,Height=36};done.Controls.Add(close);
            folder.Click+=delegate{try{Process.Start(new ProcessStartInfo{FileName=c.AppRoot,UseShellExecute=true});}catch(Exception e){MessageBox.Show(e.Message,"Unable to open folder");}};
            launch.Click+=delegate{try{Process.Start(new ProcessStartInfo{FileName=executable,Arguments="--launch",WorkingDirectory=c.AppRoot,UseShellExecute=false});done.Close();}catch(Exception e){MessageBox.Show(e.Message,"Unable to launch");}};
            close.Click+=delegate{done.Close();};done.AcceptButton=close;ApplySetupTheme(done);done.ShowDialog(owner);
        }
    }
    static void Setup(string renderPath) {
        using(Form f=new Form{Text="F4E FOX SENSE - Setup",ClientSize=new Size(635,500),StartPosition=FormStartPosition.CenterScreen,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath)}){
            f.Font=new Font("Segoe UI",9);
            f.Controls.Add(LogoBox(24,10,64));
            f.Controls.Add(new Label{Text="F4E FOX SENSE  0.10.13",Font=new Font("Segoe UI",16,FontStyle.Bold),Left=104,Top=20,Width=506,Height=36});
            string saved=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"Saved Games");
            TextBox app=Field(f,"Install location (Saved Games Mods folder)",Path.Combine(saved,@"DCS\Mods\F4E FOX SENSE"),78);
            TextBox dcs=Field(f,"DCS Saved Games profile",Path.Combine(saved,"DCS"),148);
            TextBox jester=Field(f,"F-4E Jester mods folder",Path.Combine(saved,@"DCS_F4E\jester\mods"),218);
            CheckBox portraitOption=new CheckBox{Text="Replace Jester portrait (optional)",Checked=false,Left=24,Top=290,Width=585,Height=26};f.Controls.Add(portraitOption);
            f.Controls.Add(new Label{Text="Leave unchecked to keep the current game portrait.\nSelected changes are backed up before installation.",Left=24,Top=322,Width=585,Height=44});
            Label status=new Label{Left=24,Top=374,Width=585,Height=30};f.Controls.Add(status);
            Button install=new Button{Text="Install / Update",Left=390,Top=434,Width=110,Height=36};f.Controls.Add(install);
            Button close=new Button{Text="Close",Left=510,Top=434,Width=100,Height=36};f.Controls.Add(close);close.Click+=delegate{f.Close();};
            install.Click+=delegate{
                install.Enabled=false;
                try{FoxConfig c=new FoxConfig{AppRoot=app.Text,DcsRoot=dcs.Text,JesterRoot=jester.Text,GameRoot=null,ReplacePortrait=portraitOption.Checked};Install(c,true,true);status.Text="Installed to: "+c.AppRoot;ShowComplete(f,c);}
                catch(Exception e){MessageBox.Show(e.Message,"Installation not completed",MessageBoxButtons.OK,MessageBoxIcon.Information);}finally{install.Enabled=true;}
            };
            ApplySetupTheme(f);
            if(renderPath!=null){
                using(Bitmap preview=new Bitmap(f.ClientSize.Width,f.ClientSize.Height)){
                    using(Graphics g=Graphics.FromImage(preview)){
                        g.DrawImage(f.BackgroundImage,new Rectangle(Point.Empty,f.ClientSize));
                        using(Brush shade=new SolidBrush(Color.FromArgb(95,0,5,15)))g.FillRectangle(shade,new Rectangle(Point.Empty,f.ClientSize));
                    }
                    foreach(Control child in f.Controls)child.DrawToBitmap(preview,child.Bounds);
                    preview.Save(renderPath,System.Drawing.Imaging.ImageFormat.Png);
                }return;
            }
            Application.Run(f);
        }
    }
    static int SelfTest(string root) {
        Directory.CreateDirectory(root);string report=Path.Combine(root,"self-test.txt");StringBuilder log=new StringBuilder();
        try {
            FoxConfig c=new FoxConfig{AppRoot=Path.Combine(root,"Saved Games\\DCS\\Mods\\F4E FOX SENSE"),DcsRoot=Path.Combine(root,"Saved Games\\DCS"),JesterRoot=Path.Combine(root,"Saved Games\\DCS_F4E\\jester\\mods")};
            Directory.CreateDirectory(Path.Combine(c.DcsRoot,"Scripts"));string export=Path.Combine(c.DcsRoot,@"Scripts\Export.lua");byte[] original=Utf8.GetBytes("-- user config original UTF-8\r\nlocal keep=true\r\n");File.WriteAllBytes(export,original);
            c.GameRoot=Path.Combine(root,"DCS Game");string portrait=PortraitPath(c);Directory.CreateDirectory(Path.GetDirectoryName(portrait));byte[] originalPortrait=Utf8.GetBytes("original portrait fixture");File.WriteAllBytes(portrait,originalPortrait);
            c.ReplacePortrait=true;FoxManifest m=Install(c,false,false);
            string fovHook=Path.Combine(c.DcsRoot,@"Scripts\Hooks\FoxViewFov.lua");
            if(Hash(File.ReadAllBytes(fovHook))!=Hash(Data("Bridge/FoxViewFov.lua")))throw new Exception("FOV GUI hook missing from single EXE install");
            if(Hash(File.ReadAllBytes(Path.Combine(c.DcsRoot,@"Scripts\F4RwrLink\FoxBridgeActivity.lua")))!=Hash(Data("Bridge/FoxBridgeActivity.lua")))throw new Exception("Bridge activity helper missing from single EXE install");
            File.WriteAllText(fovHook,"-- foreign hook",Utf8);bool refusedHook=false;
            try{Install(c,false,false);}catch(IOException){refusedHook=true;}
            if(!refusedHook||File.ReadAllText(fovHook)!="-- foreign hook")throw new Exception("Foreign FOV hook overwritten");
            File.WriteAllBytes(fovHook,Data("Bridge/FoxViewFov.lua"));
            log.AppendLine("PASS: FOV GUI hook embedded and installed; foreign hook overwrite refused");
            if(Hash(File.ReadAllBytes(portrait))!=Hash(Data("Portrait/jester_portrait.png")))throw new Exception("Portrait was not replaced");
            using(MemoryStream ps=new MemoryStream(Data("Portrait/jester_portrait.png")))using(Image pi=Image.FromStream(ps)){if(pi.Width!=2048||pi.Height!=2048)throw new Exception("Portrait atlas dimensions invalid");}
            byte[] installed=File.ReadAllBytes(export);for(int i=0;i<original.Length;i++)if(original[i]!=installed[i])throw new Exception("Export prefix modified");
            FoxChange backup=m.Changes.Find(delegate(FoxChange x){return x.Target==export;});if(Hash(File.ReadAllBytes(backup.Backup))!=Hash(original))throw new Exception("Backup mismatch");
            int backups=Directory.GetFiles(Path.Combine(c.AppRoot,"Backups")).Length;
            string settings=Path.Combine(c.AppRoot,@"Runtime\HudSettings.json");string settingsBefore=File.ReadAllText(settings);
            Install(c,false,false);if(Hash(File.ReadAllBytes(export))!=Hash(installed)||Directory.GetFiles(Path.Combine(c.AppRoot,"Backups")).Length!=backups||File.ReadAllText(settings)!=settingsBefore)throw new Exception("Reinstall is not idempotent");
            log.AppendLine("PASS: original Export.lua bytes and backup, idempotent reinstall, settings preserved");
            if(!File.Exists(Path.Combine(c.AppRoot,"F4E FOX SENSE.exe")))throw new Exception("Completion launch target missing");
            log.AppendLine("PASS: installed folder and completion launch target exist");
            if(Hash(File.ReadAllBytes(Path.Combine(c.AppRoot,"logo.png")))!=Hash(Data("Branding/logo.png"))||Hash(File.ReadAllBytes(Path.Combine(c.AppRoot,"F4E FOX SENSE.ico")))!=Hash(Data("Branding/F4E FOX SENSE.ico")))throw new Exception("Installed branding missing");
            using(Image logo=LogoImage()){if(logo.Width<128||logo.Height<128)throw new Exception("Embedded logo is invalid");}
            log.AppendLine("PASS: logo PNG and ICO embedded, installed, and decoded successfully");
            using(Image background=SetupBackground()){if(background.Width<600||background.Height<400)throw new Exception("Setup background is invalid");}
            log.AppendLine("PASS: user setup background embedded and decoded successfully");
            RestorePortrait(c,false);if(Hash(File.ReadAllBytes(portrait))!=Hash(originalPortrait))throw new Exception("Portrait restore mismatch");Install(c,false,false);
            File.WriteAllBytes(portrait,Utf8.GetBytes("foreign image edit"));bool refusedPortrait=false;try{RestorePortrait(c,false);}catch(IOException){refusedPortrait=true;}if(!refusedPortrait||Utf8.GetString(File.ReadAllBytes(portrait))!="foreign image edit")throw new Exception("Foreign portrait protection failed");File.WriteAllBytes(portrait,Data("Portrait/jester_portrait.png"));
            log.AppendLine("PASS: exact supplied 2048x2048 portrait installed, original backup restored byte-for-byte, reinstall and foreign-change protection");
            c.ReplacePortrait=false;File.WriteAllBytes(portrait,originalPortrait);Install(c,false,false);if(Hash(File.ReadAllBytes(portrait))!=Hash(originalPortrait))throw new Exception("Unchecked portrait changed game image");c.ReplacePortrait=true;File.WriteAllBytes(portrait,Data("Portrait/jester_portrait.png"));
            log.AppendLine("PASS: unchecked portrait leaves existing game image unchanged");
            if(KnownGameRoot(c.AppRoot,c.DcsRoot,null)!=c.GameRoot)throw new Exception("Existing configured game path not reused");
            string externalGame=Path.Combine(root,"Custom Game With Spaces");string externalPortrait=Path.Combine(externalGame,PortraitRelative);Directory.CreateDirectory(Path.GetDirectoryName(externalPortrait));File.WriteAllBytes(externalPortrait,originalPortrait);
            Directory.CreateDirectory(Path.Combine(c.DcsRoot,"Logs"));File.WriteAllText(Path.Combine(c.DcsRoot,@"Logs\dcs.log"),"Command line: \""+Path.Combine(externalGame,@"bin-mt\DCS.exe")+"\" --restarted");
            if(KnownGameRoot(Path.Combine(root,"No Config"),c.DcsRoot,null)!=externalGame)throw new Exception("Custom game path from DCS log not detected");
            string steam=Path.Combine(root,"Steam");string library=Path.Combine(root,"External Steam Library");Directory.CreateDirectory(Path.Combine(steam,"steamapps"));File.WriteAllText(Path.Combine(steam,@"steamapps\libraryfolders.vdf"),"\"libraryfolders\" { \"1\" { \"path\" \""+library.Replace("\\","\\\\")+"\" } }");
            if(!SteamLibraryRoots(steam).Contains(library))throw new Exception("External Steam library not detected");
            FoxConfig noGame=new FoxConfig{AppRoot=Path.Combine(c.DcsRoot,@"Mods\No Game Test"),DcsRoot=c.DcsRoot,JesterRoot=c.JesterRoot};
            Install(noGame,false,false,false);
            if(!String.IsNullOrEmpty(noGame.GameRoot)||!noGame.PortraitStatus.StartsWith("Portrait skipped")||!File.Exists(Path.Combine(noGame.AppRoot,"F4E FOX SENSE.exe")))throw new Exception("Missing game blocked HUD installation or status not reported");
            log.AppendLine("PASS: configured path reuse, custom bin-mt path from DCS log, external Steam VDF and complete HUD install when portrait is unavailable");
            string probe=File.ReadAllText(Path.Combine(c.JesterRoot,"F4RwrProbe.lua"));if(!probe.Contains(FindLogPath(c))||probe.Contains(@"__FOX_PROBE_LOG__"))throw new Exception("Probe path not configured");
            log.AppendLine("PASS: profile paths with spaces, Jester log path configured correctly; app resides in Saved Games DCS Mods");
            string validApp=c.AppRoot;c.AppRoot=Path.Combine(c.DcsRoot,"Scripts","InvalidApp");bool rejectedRoot=false;
            try{Validate(c);}catch(IOException){rejectedRoot=true;}c.AppRoot=validApp;
            if(!rejectedRoot)throw new Exception("Invalid Saved Games placement accepted");
            string init=Path.Combine(c.JesterRoot,@"init\StartF4RwrProbe.lua");File.WriteAllText(init,"-- foreign custom file",Utf8);
            bool refused=false;try{Install(c,false,false);}catch(IOException){refused=true;}if(!refused||File.ReadAllText(init)!="-- foreign custom file")throw new Exception("Foreign overwrite protection failed");
            log.AppendLine("PASS: foreign Jester modification refused before external writes");
            string output;int code=RunHud(c,"-SelfTest",out output);log.Append(output);if(code!=0)throw new Exception("Embedded HUD tests failed");
            code=RunHud(c,"-Demo -RuntimeControlsTest",out output);log.Append(output);if(code!=0)throw new Exception("Production control initialization tests failed");
            string launcher=Path.Combine(c.AppRoot,"F4E FOX SENSE.exe");
            if(Hash(File.ReadAllBytes(launcher))!=Hash(Data("App/F4E FOX SENSE.exe")))throw new Exception("Installed launcher differs from resource");
            ProcessStartInfo start=new ProcessStartInfo(launcher,"--self-test");start.UseShellExecute=false;start.CreateNoWindow=true;start.WorkingDirectory=c.AppRoot;
            using(Process process=Process.Start(start)){process.WaitForExit();if(process.ExitCode!=0)throw new Exception("Native launcher to HUD chain failed");}
            log.AppendLine("PASS: standard ZIP resource extraction, separate launcher bytes and launcher-to-HUD chain under RemoteSigned");
            File.WriteAllText(report,log.ToString(),Utf8);return 0;
        }catch(Exception e){log.AppendLine(e.ToString());File.WriteAllText(report,log.ToString(),Utf8);return 1;}
    }
    [STAThread] static int Main(string[] args) {
        Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
        try {
            if(args.Length>0&&args[0]=="--self-test")return SelfTest(Full(args[1]));
            if(args.Length>0&&args[0]=="--preview-completion"){ShowComplete(null,new FoxConfig{AppRoot=Full(args[1])});return 0;}
            if((args.Length>0&&args[0]=="--launch")||Path.GetFileName(Application.ExecutablePath).Equals("F4E FOX SENSE.exe",StringComparison.OrdinalIgnoreCase))return Launch(BaseRoot);
            if(args.Length>0&&args[0]=="--render-setup"){Setup(Full(args[1]));return 0;}
            Setup(null);return 0;
        }catch(Exception e){if(args.Length>0&&args[0]=="--render-setup"){File.WriteAllText(args[1]+".error.txt",e.ToString());return 1;}MessageBox.Show(e.Message,"F4E FOX SENSE",MessageBoxButtons.OK,MessageBoxIcon.Information);return 1;}
    }
}
