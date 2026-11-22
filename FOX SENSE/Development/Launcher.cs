using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Windows.Forms;
using System.Web.Script.Serialization;
[assembly:System.Reflection.AssemblyTitle("F4E FOX SENSE")]
[assembly:System.Reflection.AssemblyProduct("F4E FOX SENSE")]
[assembly:System.Reflection.AssemblyDescription("DCS F-4E HUD launcher")]
[assembly:System.Reflection.AssemblyVersion("0.10.13.0")]
[assembly:System.Reflection.AssemblyFileVersion("0.10.13.0")]
public sealed class LaunchConfig { public string AppRoot; public string DcsRoot; }
internal static class FoxLauncher {
 [STAThread] static int Main(string[] args) {
  bool test=args.Length>0&&args[0]=="--self-test";
  try {
   string root=AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
   LaunchConfig config=new JavaScriptSerializer().Deserialize<LaunchConfig>(File.ReadAllText(Path.Combine(root,"fox-config.json")));
   if(!Path.GetFullPath(config.AppRoot).TrimEnd('\\').Equals(root,StringComparison.OrdinalIgnoreCase))throw new IOException("Application configuration does not match this folder.");
   string script=Path.Combine(root,@"Runtime\Overlay\Overlay.ps1");if(!File.Exists(script))throw new FileNotFoundException("HUD runtime is missing. Run Install / Update.",script);
   bool created;using(Mutex mutex=new Mutex(true,test?"Local\\F4E_FOX_SENSE_TEST_"+Guid.NewGuid().ToString("N"):"Local\\F4E_FOX_SENSE",out created)) {
    if(!created){if(!test)MessageBox.Show("F4E FOX SENSE is already running.","F4E FOX SENSE");return 0;}
    ProcessStartInfo info=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe"));
    info.Arguments="-NoProfile -STA -ExecutionPolicy RemoteSigned -File \""+script+"\" "+(test?"-SelfTest":"-ProfileRoot \""+Path.GetFullPath(config.DcsRoot)+"\"");
    info.WorkingDirectory=Path.Combine(root,"Runtime");info.UseShellExecute=false;info.CreateNoWindow=true;info.RedirectStandardError=true;info.RedirectStandardOutput=true;
    using(Process process=new Process()) {
     process.StartInfo=info;StringBuilder output=new StringBuilder();
     process.OutputDataReceived+=delegate(object sender,DataReceivedEventArgs e){if(e.Data!=null)lock(output)output.AppendLine(e.Data);};
     process.ErrorDataReceived+=delegate(object sender,DataReceivedEventArgs e){if(e.Data!=null)lock(output)output.AppendLine(e.Data);};
     process.Start();process.BeginOutputReadLine();process.BeginErrorReadLine();process.WaitForExit();process.WaitForExit();
     if(process.ExitCode!=0){File.WriteAllText(Path.Combine(root,"launch-error.txt"),output.ToString());if(!test)MessageBox.Show("The HUD could not start. See launch-error.txt. PowerShell policy is respected; this app does not change your system policy.","F4E FOX SENSE");}
     return process.ExitCode;
    }
   }
  }catch(Exception error){if(test)Console.Error.WriteLine(error);else MessageBox.Show(error.Message,"F4E FOX SENSE");return 1;}
 }
}
