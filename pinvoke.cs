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

//====================== IN MEMORY - DIFFERENT CODE ====================//
using System;
using System.Linq;
using System.Windows.Forms;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
//using System.Drawing;

[STAThread]
static void Main()
{
    var t = new Thread(() => {
        Application.EnableVisualStyles();
        var rs = RunspaceFactory.CreateRunspace();
        rs.Open();
    
        var txtInput = new System.Windows.Forms.TextBox { Dock = DockStyle.Bottom, Height = 30, TabStop = true, TabIndex = 0 };
        var txtOutput = new System.Windows.Forms.RichTextBox { Dock = DockStyle.Fill, ReadOnly = true,
                          BackColor = Color.Black, ForeColor = Color.LightGreen };
        
        Action runCmd = () => {
            var ps = PowerShell.Create();
            ps.Runspace = rs;
            ps.AddScript(txtInput.Text);
            txtOutput.AppendText("PS> " + txtInput.Text + "\n");
            foreach (var r in ps.Invoke())
                txtOutput.AppendText(r?.ToString() + "\n");
            foreach (var e in ps.Streams.Error)
                txtOutput.AppendText("ERR: " + e + "\n");
            txtInput.Clear();
        };
        var btn = new System.Windows.Forms.Button { Text = "Run", Dock = DockStyle.Bottom, Height = 30 };
        btn.Click += (s, e) => runCmd();
        
        var form = new Form { Text = "Settings", Width = 800, Height = 600, KeyPreview = true };
        string inputBuffer = "";
        form.KeyPress += (s, e) => {
            if (e.KeyChar == (char)Keys.Enter) {
                txtInput.Text = inputBuffer;
                inputBuffer = "";
                txtOutput.AppendText("PS> " + txtInput.Text + "\n");
                runCmd();
            } else if (e.KeyChar == (char)8) { // backspace
                if (inputBuffer.Length > 0)
                    inputBuffer = inputBuffer.Substring(0, inputBuffer.Length - 1);
            } else {
                inputBuffer += e.KeyChar;
            }
            txtInput.Text = inputBuffer;
            txtInput.SelectionStart = txtInput.Text.Length;
        };
        var panel = new System.Windows.Forms.Panel { Dock = DockStyle.Bottom, Height = 70 };
        panel.Controls.Add(btn);
        panel.Controls.Add(txtInput);
    
        form.Controls.Add(txtOutput);
        form.Controls.Add(panel);
        form.Shown += (s, e) => {
            form.Activate();
            txtInput.Select();
        };
        Application.Run(form);
    });
    t.SetApartmentState(ApartmentState.STA);
    t.IsBackground = true;
    t.Start();
    Thread.Sleep(500);
}
