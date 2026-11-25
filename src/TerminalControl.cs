using System;
using System.IO;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.VisualStudio.PlatformUI;
using Microsoft.VisualStudio.Shell;
using Microsoft.VisualStudio.Threading;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace CodexPowerline.VisualStudio
{
    internal sealed class TerminalControl : UserControl, IDisposable
    {
        private const string Origin = "https://powerline.local/";
        private readonly WebView2 browser = new WebView2();
        private readonly JoinableTaskFactory taskFactory = PowerlinePackage.Instance.JoinableTaskFactory;
        private readonly TextBlock status = new TextBlock { Text = "Starting terminal...", Margin = new Thickness(8, 4, 8, 4), TextWrapping = TextWrapping.Wrap };
        private readonly string extensionDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        private TerminalProcess session;
        private bool initialized;
        private bool disposed;
        private int cols;
        private int rows;

        public TerminalControl()
        {
            var panel = new DockPanel();
            var header = new StackPanel { Orientation = Orientation.Horizontal };
            var restart = new Button { Content = "Restart Terminal", Margin = new Thickness(4), Padding = new Thickness(8, 2, 8, 2) };
            restart.Click += Restart;
            header.Children.Add(restart);
            header.Children.Add(status);
            DockPanel.SetDock(header, Dock.Top);
            panel.Children.Add(header);
            panel.Children.Add(browser);
            Content = panel;
            Loaded += Initialize;
            VSColorTheme.ThemeChanged += ThemeChanged;
            ApplyNativeTheme();
        }

        private void RunUiTask(Func<Task> action)
        {
            _ = taskFactory.RunAsync(async () =>
            {
                await ThreadHelper.JoinableTaskFactory.SwitchToMainThreadAsync();
                try { await action(); }
                catch (Exception error)
                {
                    if (!disposed) status.Text = error.Message;
                    ActivityLog.LogError("Codex Powerline", error.ToString());
                }
            });
        }

        private void Initialize(object sender, RoutedEventArgs args) => RunUiTask(InitializeAsync);

        private async Task InitializeAsync()
        {
            await ThreadHelper.JoinableTaskFactory.SwitchToMainThreadAsync();
            if (initialized || disposed) return;
            initialized = true;
            try
            {
                var profile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CodexPowerline", "VisualStudio", "WebView2");
                var environment = await CoreWebView2Environment.CreateAsync(null, profile);
                if (disposed) return;
                await browser.EnsureCoreWebView2Async(environment);
                if (disposed) return;
                var core = browser.CoreWebView2;
                core.Settings.AreHostObjectsAllowed = false;
                core.Settings.AreDefaultContextMenusEnabled = false;
                core.Settings.AreDefaultScriptDialogsEnabled = false;
                core.Settings.AreDevToolsEnabled = false;
                core.Settings.IsStatusBarEnabled = false;
                core.Settings.IsZoomControlEnabled = false;
                core.SetVirtualHostNameToFolderMapping("powerline.local", Path.Combine(extensionDirectory, "web", "dist"), CoreWebView2HostResourceAccessKind.DenyCors);
                core.NavigationStarting += (_, navigation) => { navigation.Cancel = navigation.Uri != Origin + "index.html"; };
                core.FrameNavigationStarting += (_, navigation) => { navigation.Cancel = true; };
                core.NewWindowRequested += (_, request) => { request.Handled = true; };
                core.PermissionRequested += (_, request) => { request.State = CoreWebView2PermissionState.Deny; };
                core.DownloadStarting += (_, download) => { download.Cancel = true; };
                core.WebMessageReceived += Receive;
                core.NavigationCompleted += (_, navigation) =>
                {
                    if (navigation.IsSuccess) SendTheme();
                    else status.Text = "Terminal page could not load: " + navigation.WebErrorStatus;
                };
                core.Navigate(Origin + "index.html");
            }
            catch (Exception error)
            {
                status.Text = "Could not open the terminal. Check the Microsoft Edge WebView2 Runtime. " + error.Message;
                ActivityLog.LogError("Codex Powerline", error.ToString());
            }
        }

        private void Receive(object sender, CoreWebView2WebMessageReceivedEventArgs args) => RunUiTask(() => ReceiveAsync(args));

        private async Task ReceiveAsync(CoreWebView2WebMessageReceivedEventArgs args)
        {
            await ThreadHelper.JoinableTaskFactory.SwitchToMainThreadAsync();
            if (disposed || args.Source != Origin + "index.html" || args.WebMessageAsJson.Length > 262144) return;
            try
            {
                var message = JObject.Parse(args.WebMessageAsJson);
                var type = (string)message["type"];
                if (type == "resize" && message["cols"]?.Type == JTokenType.Integer && message["rows"]?.Type == JTokenType.Integer)
                {
                    var newCols = (int)message["cols"];
                    var newRows = (int)message["rows"];
                    if (newCols < 1 || newCols > 1000 || newRows < 1 || newRows > 1000) return;
                    cols = newCols;
                    rows = newRows;
                    if (session == null) await StartAsync();
                    else await session.SendAsync(new { type = "resize", cols, rows });
                }
                else if (type == "input" && message["text"]?.Type == JTokenType.String && ((string)message["text"]).Length <= 65536)
                {
                    if (session != null) await session.SendAsync(new { type = "input", text = (string)message["text"] });
                }
                else if (type == "ack" && message["generation"]?.Type == JTokenType.Integer && session != null)
                    await session.SendAsync(new { type = "ack", generation = (long)message["generation"] });
            }
            catch (Exception error) { status.Text = error.Message; }
        }

        private async Task StartAsync()
        {
            await ThreadHelper.JoinableTaskFactory.SwitchToMainThreadAsync();
            if (disposed || cols == 0 || rows == 0) return;
            var directory = WorkspaceDirectory.Get();
            session = new TerminalProcess(extensionDirectory, async message =>
            {
                await ThreadHelper.JoinableTaskFactory.SwitchToMainThreadAsync();
                if (disposed) return;
                var type = (string)message["type"];
                if (type == "hostError") status.Text = (string)message["text"];
                else if (type == "started") status.Text = directory;
                else if (type == "exited") status.Text = "Exited. Use Restart Terminal.";
                else if (type == "output" || type == "reset") browser.CoreWebView2?.PostWebMessageAsJson(message.ToString(Formatting.None));
            });
            await session.SendAsync(new { type = "start", cwd = directory, cols, rows });
        }

        private void Restart(object sender, RoutedEventArgs args) => RunUiTask(RestartAsync);

        private async Task RestartAsync()
        {
            await ThreadHelper.JoinableTaskFactory.SwitchToMainThreadAsync();
            if (disposed || browser.CoreWebView2 == null) return;
            try
            {
                if (session == null || !session.IsRunning)
                {
                    session?.Dispose();
                    session = null;
                    await StartAsync();
                }
                else await session.SendAsync(new { type = "start", cwd = WorkspaceDirectory.Get(), cols, rows });
            }
            catch (Exception error) { status.Text = error.Message; }
        }

        private void ThemeChanged(ThemeChangedEventArgs args)
        {
            RunUiTask(() => { if (!disposed) { ApplyNativeTheme(); SendTheme(); } return Task.CompletedTask; });
        }

        private void ApplyNativeTheme()
        {
            var background = VSColorTheme.GetThemedColor(EnvironmentColors.ToolWindowBackgroundColorKey);
            var foreground = VSColorTheme.GetThemedColor(EnvironmentColors.ToolWindowTextColorKey);
            Background = new SolidColorBrush(Color.FromArgb(background.A, background.R, background.G, background.B));
            status.Foreground = new SolidColorBrush(Color.FromArgb(foreground.A, foreground.R, foreground.G, foreground.B));
        }

        private void SendTheme()
        {
            if (browser.CoreWebView2 == null || disposed) return;
            var background = VSColorTheme.GetThemedColor(EnvironmentColors.ToolWindowBackgroundColorKey);
            var foreground = VSColorTheme.GetThemedColor(EnvironmentColors.ToolWindowTextColorKey);
            browser.CoreWebView2.PostWebMessageAsJson(JsonConvert.SerializeObject(new {
                type = "theme", background = $"#{background.R:X2}{background.G:X2}{background.B:X2}",
                foreground = $"#{foreground.R:X2}{foreground.G:X2}{foreground.B:X2}"
            }));
        }

        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            VSColorTheme.ThemeChanged -= ThemeChanged;
            if (session != null) _ = taskFactory.RunAsync(() => session.StopAsync());
            browser.Dispose();
        }
    }
}
