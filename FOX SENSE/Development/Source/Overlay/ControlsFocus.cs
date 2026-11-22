using System;

using System.Runtime.InteropServices;
using System.Windows.Interop;

// A hook on our own HWND only. No keyboard hook, game injection or focus forcing.
public sealed class FoxControlsFocus : IDisposable {
    [StructLayout(LayoutKind.Sequential)] public struct ScreenPoint { public int X, Y; }
    [DllImport("user32.dll")] static extern bool GetCursorPos(out ScreenPoint point);
    public static ScreenPoint CursorPosition() { ScreenPoint point; GetCursorPos(out point); return point; }
    public const int HotkeyId = 0x4F58;
    readonly IntPtr handle;
    readonly HwndSource source;
    readonly HwndSourceHook hook;
    bool disposed;
    public bool HotkeyRegistered { get; private set; }
    public bool SystemEnding { get; private set; }
    public event EventHandler ToggleRequested;
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int index);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int index, int value);
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h, int id);

    public FoxControlsFocus(IntPtr handle, bool registerHotkey) {
        this.handle = handle;
        source = HwndSource.FromHwnd(handle);
        if (source == null) throw new ArgumentException("A WPF window handle is required.");
        // Do not add WS_EX_TRANSPARENT: controls must receive mouse clicks.
        SetWindowLong(handle, -20, GetWindowLong(handle, -20) | 0x08000000);
        hook = WindowMessage;
        source.AddHook(hook);
        if (registerHotkey) HotkeyRegistered = RegisterHotKey(handle, HotkeyId, 0x4003, 0x79); // Ctrl+Alt+F10, no repeat
    }
    IntPtr WindowMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled) {
        if(message==0x0011)SystemEnding=true;
        if(message==0x0016)SystemEnding=wParam!=IntPtr.Zero;
        if (message == 0x0021) { // WM_MOUSEACTIVATE
            handled = true;
            return new IntPtr(3); // MA_NOACTIVATE: keep click, do not activate
        }
        if (message == 0x0312 && wParam.ToInt32() == HotkeyId) {
            handled = true;
            EventHandler handler = ToggleRequested;
            if (handler != null) handler(this, EventArgs.Empty);
        }
        return IntPtr.Zero;
    }
    public void Dispose() {
        if (disposed) return;
        disposed = true;
        if (HotkeyRegistered) { UnregisterHotKey(handle, HotkeyId); HotkeyRegistered = false; }
        source.RemoveHook(hook);
    }
}
