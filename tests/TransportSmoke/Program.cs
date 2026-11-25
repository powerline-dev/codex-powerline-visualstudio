using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using CodexPowerline.VisualStudio;

internal static class Program
{
    private static async Task<int> Main(string[] args)
    {
        var fixture = Path.Combine(Path.GetTempPath(), "powerline-vs-bridge-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(fixture);
        var originalPath = Environment.GetEnvironmentVariable("PATH");
        TerminalProcess session = null;
        try
        {
            var node = FindNode(originalPath);
            File.WriteAllText(Path.Combine(fixture, "codex-powerline.cmd"), "@\"" + node + "\" \"%~dp0mock.cjs\"\r\n");
            File.WriteAllText(Path.Combine(fixture, "mock.cjs"),
                "console.log('BRIDGE_READY:'+process.pid);require('node:readline').createInterface({input:process.stdin}).on('line',line=>console.log('BRIDGE_ECHO:'+line));", new UTF8Encoding(false));
            Environment.SetEnvironmentVariable("PATH", fixture + Path.PathSeparator + originalPath);
            var output = new StringBuilder();
            var ready = new TaskCompletionSource<bool>();
            var echoed = new TaskCompletionSource<bool>();
            session = new TerminalProcess(Path.GetFullPath(args[0]), async message =>
            {
                if ((string)message["type"] == "hostError")
                {
                    ready.TrySetException(new Exception((string)message["text"]));
                    echoed.TrySetException(new Exception((string)message["text"]));
                    return;
                }
                if ((string)message["type"] != "output") return;
                output.Append((string)message["text"]);
                await session.SendAsync(new { type = "ack", generation = (long)message["generation"] });
                if (Regex.IsMatch(output.ToString(), @"BRIDGE_READY:\d+")) ready.TrySetResult(true);
                if (output.ToString().Contains("BRIDGE_ECHO:hello \u017elut\u00fd")) echoed.TrySetResult(true);
            });
            await session.SendAsync(new { type = "start", cwd = fixture, cols = 90, rows = 30 });
            await WithTimeout(ready.Task);
            var pid = int.Parse(Regex.Match(output.ToString(), @"BRIDGE_READY:(\d+)").Groups[1].Value);
            await session.SendAsync(new { type = "input", text = "hello \u017elut\u00fd\r" });
            await WithTimeout(echoed.Task);
            await session.StopAsync();
            try
            {
                using (var process = Process.GetProcessById(pid))
                    if (!process.HasExited) throw new Exception("The CLI survived transport shutdown.");
            }
            catch (ArgumentException) { }
            Console.WriteLine("PASS .NET Framework transport: UTF-8 input/output and process cleanup.");
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error);
            return 1;
        }
        finally
        {
            if (session != null) await session.StopAsync();
            Environment.SetEnvironmentVariable("PATH", originalPath);
            var fullPath = Path.GetFullPath(fixture);
            if (Path.GetDirectoryName(fullPath).TrimEnd(Path.DirectorySeparatorChar) != Path.GetTempPath().TrimEnd(Path.DirectorySeparatorChar)
                || !Path.GetFileName(fullPath).StartsWith("powerline-vs-bridge-", StringComparison.Ordinal))
                throw new Exception("Unexpected fixture cleanup path.");
            Directory.Delete(fullPath, true);
        }
    }

    private static async Task WithTimeout(Task task)
    {
        if (await Task.WhenAny(task, Task.Delay(15000)) != task) throw new TimeoutException("The terminal transport did not respond.");
        await task;
    }

    private static string FindNode(string searchPath)
    {
        foreach (var folder in searchPath.Split(Path.PathSeparator))
        {
            var candidate = Path.Combine(folder.Trim('"'), "node.exe");
            if (File.Exists(candidate)) return candidate;
        }
        throw new FileNotFoundException("Node.js is not on PATH.");
    }
}
