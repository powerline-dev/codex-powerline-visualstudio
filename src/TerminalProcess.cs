using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace CodexPowerline.VisualStudio
{
    internal sealed class TerminalProcess : IDisposable
    {
        private readonly Process process;
        private readonly StreamWriter input;
        private readonly SemaphoreSlim writer = new SemaphoreSlim(1, 1);
        private bool disposed;
        private Task shutdown = Task.CompletedTask;

        public TerminalProcess(string extensionDirectory, Func<JObject, Task> onMessage)
        {
            var node = FindNode();
            process = new Process
            {
                StartInfo = new ProcessStartInfo(node, "\"" + Path.Combine(extensionDirectory, "runtime", "terminal-host.cjs") + "\"")
                {
                    WorkingDirectory = extensionDirectory,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    StandardOutputEncoding = new UTF8Encoding(false),
                    StandardErrorEncoding = new UTF8Encoding(false)
                }
            };
            process.Start();
            input = new StreamWriter(process.StandardInput.BaseStream, new UTF8Encoding(false)) { AutoFlush = true };
            _ = ReadOutputAsync(onMessage);
            _ = ReadErrorsAsync(onMessage);
        }

        public bool IsRunning => !disposed && !process.HasExited;

        private static string FindNode()
        {
            foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
            {
                if (!Path.IsPathRooted(directory.Trim('"'))) continue;
                var candidate = Path.Combine(directory.Trim('"'), "node.exe");
                if (File.Exists(candidate)) return candidate;
            }
            throw new FileNotFoundException("Node.js was not found on PATH. Install x64 Node.js 22.12 or newer, then restart Visual Studio.");
        }

        public async Task SendAsync(object message)
        {
            await writer.WaitAsync().ConfigureAwait(false);
            try
            {
                if (disposed || process.HasExited) return;
                await input.WriteLineAsync(JsonConvert.SerializeObject(message)).ConfigureAwait(false);
            }
            finally { writer.Release(); }
        }

        private async Task ReadOutputAsync(Func<JObject, Task> onMessage)
        {
            try
            {
                string line;
                while (!disposed && (line = await process.StandardOutput.ReadLineAsync().ConfigureAwait(false)) != null)
                {
                    await onMessage(JObject.Parse(line)).ConfigureAwait(false);
                }
                if (!disposed) await onMessage(new JObject { ["type"] = "hostError", ["text"] = "The terminal host stopped. Use Restart Terminal." }).ConfigureAwait(false);
            }
            catch (Exception error) when (error is IOException || error is ObjectDisposedException || error is JsonException || error is InvalidOperationException)
            {
                if (!disposed) await onMessage(new JObject { ["type"] = "hostError", ["text"] = error.Message }).ConfigureAwait(false);
            }
        }

        private async Task ReadErrorsAsync(Func<JObject, Task> onMessage)
        {
            try
            {
                string line;
                while (!disposed && (line = await process.StandardError.ReadLineAsync().ConfigureAwait(false)) != null)
                    await onMessage(new JObject { ["type"] = "hostError", ["text"] = line }).ConfigureAwait(false);
            }
            catch (Exception error) when (error is IOException || error is ObjectDisposedException || error is InvalidOperationException) { }
        }

        public void Dispose() { _ = StopAsync(); }

        public Task StopAsync()
        {
            if (disposed) return shutdown;
            disposed = true;
            // Do not block the IDE while node-pty shuts down the console process tree.
            shutdown = Task.Run(async () =>
            {
                await writer.WaitAsync().ConfigureAwait(false);
                try
                {
                    input.Close();
                    if (!process.WaitForExit(8000)) process.Kill();
                }
                catch (Exception error) when (error is InvalidOperationException || error is IOException) { }
                finally { process.Dispose(); writer.Release(); }
            });
            return shutdown;
        }
    }
}
