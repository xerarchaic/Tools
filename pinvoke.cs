using System.Runtime.InteropServices;

// These should be included inside the class (Add Class Member)

[StructLayout(LayoutKind.Sequential)]
public struct STARTUPINFO
{
    public int cb;
    public string lpReserved, lpDesktop, lpTitle;
    public int dwX, dwY, dwXSize, dwYSize;
    public int dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
    public short wShowWindow, cbReserved2;
    public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
}

[StructLayout(LayoutKind.Sequential)]
public struct PROCESS_INFORMATION
{
    public IntPtr hProcess, hThread;
    public int dwProcessId, dwThreadId;
}

[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
static extern bool CreateProcess(
    string lpApplicationName,
    string lpCommandLine,
    IntPtr lpProcessAttributes,
    IntPtr lpThreadAttributes,
    bool bInheritHandles,
    uint dwCreationFlags,
    IntPtr lpEnvironment,
    string lpCurrentDirectory,
    ref STARTUPINFO lpStartupInfo,
    out PROCESS_INFORMATION lpProcessInformation
);

// Example of calling it from a method (e.g. Edit method button1_Click):
private void button1_Click(object sender, EventArgs e)
{
    STARTUPINFO si = new STARTUPINFO();
    si.cb = Marshal.SizeOf(si);
    PROCESS_INFORMATION pi;

    bool success = CreateProcess(
        null,
        "cmd.exe",          // or "powershell.exe"
        IntPtr.Zero,
        IntPtr.Zero,
        false,
        0,
        IntPtr.Zero,
        null,
        ref si,
        out pi
    );

    if (!success)
    {
        int err = Marshal.GetLastWin32Error();
        MessageBox.Show("Failed: " + err);  // error code helps diagnose BT block
    }
}
