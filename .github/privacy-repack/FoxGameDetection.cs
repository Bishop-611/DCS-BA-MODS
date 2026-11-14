internal static partial class Fox {
    static string ValidGameRoot(string path) {
        try{if(!String.IsNullOrWhiteSpace(path)){path=Full(path.Trim('"'));if(File.Exists(Path.Combine(path,PortraitRelative)))return path;}}catch{}
        return "";
    }
    static string KnownGameRoot(string appRoot,string profileRoot,string preferred) {
        string valid=ValidGameRoot(preferred);if(valid!="")return valid;
        try{
            string file=Path.Combine(appRoot,"fox-config.json");
            if(File.Exists(file)){FoxConfig old=ReadJson<FoxConfig>(file);valid=ValidGameRoot(old.GameRoot);if(valid!="")return valid;}
        }catch{}
        // Bounded, shared read of the existing log header; no full-disk search.
        try{
            string file=Path.Combine(profileRoot,@"Logs\dcs.log");
            using(FileStream stream=new FileStream(file,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))
            using(StreamReader reader=new StreamReader(stream)) {
                char[] data=new char[131072];int count=reader.Read(data,0,data.Length);string text=new string(data,0,count);
                Match match=Regex.Match(text,@"[A-Za-z]:[\\/][^\r\n""<>]*?[\\/]bin(?:-mt)?[\\/]DCS\.exe",RegexOptions.IgnoreCase);
                if(match.Success){valid=ValidGameRoot(Path.GetDirectoryName(Path.GetDirectoryName(match.Value)));if(valid!="")return valid;}
            }
        }catch{}
        return "";
    }
    static string RegistryText(Microsoft.Win32.RegistryHive hive,Microsoft.Win32.RegistryView view,string key,string value) {
        try{using(var root=Microsoft.Win32.RegistryKey.OpenBaseKey(hive,view))using(var entry=root.OpenSubKey(key)){return entry==null?"":Convert.ToString(entry.GetValue(value));}}catch{return "";}
    }
    static List<string> SteamLibraryRoots(string steam) {
        List<string> roots=new List<string>();if(String.IsNullOrWhiteSpace(steam))return roots;roots.Add(steam);
        try{
            string file=Path.Combine(steam,@"steamapps\libraryfolders.vdf");
            if(new FileInfo(file).Length<2097152){
                foreach(Match match in Regex.Matches(File.ReadAllText(file),"\"path\"\\s*\"([^\"]+)\"",RegexOptions.IgnoreCase))roots.Add(match.Groups[1].Value.Replace("\\\\","\\"));
            }
        }catch{}
        return roots;
    }
    static string FindGameRoot(string appRoot=null,string profileRoot=null,string preferred=null) {
        string valid=KnownGameRoot(appRoot,profileRoot,preferred);if(valid!="")return valid;
        List<string> steam=new List<string>();steam.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),"Steam"));
        foreach(var hive in new[]{Microsoft.Win32.RegistryHive.CurrentUser,Microsoft.Win32.RegistryHive.LocalMachine})
        foreach(var view in new[]{Microsoft.Win32.RegistryView.Registry64,Microsoft.Win32.RegistryView.Registry32}) {
            foreach(string key in new[]{@"Software\Eagle Dynamics\DCS World",@"Software\Eagle Dynamics\DCS World OpenBeta"})
            foreach(string value in new[]{"Path","InstallPath","InstallLocation"}){valid=ValidGameRoot(RegistryText(hive,view,key,value));if(valid!="")return valid;}
            foreach(string value in new[]{"SteamPath","InstallPath"}){string path=RegistryText(hive,view,@"Software\Valve\Steam",value);if(!String.IsNullOrWhiteSpace(path))steam.Add(path);}
        }
        foreach(string folder in steam)foreach(string library in SteamLibraryRoots(folder)){
            valid=ValidGameRoot(Path.Combine(library,@"steamapps\common\DCSWorld"));if(valid!="")return valid;
        }
        foreach(string path in new[]{Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),@"Eagle Dynamics\DCS World"),Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),@"Eagle Dynamics\DCS World OpenBeta")}){
            valid=ValidGameRoot(path);if(valid!="")return valid;
        }
        return "";
    }
}
