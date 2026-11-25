using System;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Media.Imaging;
using Microsoft.VisualStudio.Imaging;
using Microsoft.VisualStudio.Imaging.Interop;
using Microsoft.VisualStudio.Shell;
using Microsoft.VisualStudio.Shell.Interop;

namespace CodexPowerline.VisualStudio
{
    [Guid("20936011-f4b8-4930-871b-0e5e436853f4")]
    public sealed class PowerlineToolWindow : ToolWindowPane
    {
        private readonly TerminalControl terminal;
        private readonly IImageHandle icon;

        public PowerlineToolWindow() : base(null)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            Caption = "Codex Powerline";
            var images = ServiceProvider.GlobalProvider.GetService(typeof(SVsImageService)) as IVsManagedImageService;
            var iconPath = Path.Combine(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location), "assets", "icon.png");
            icon = images?.AddCustomImage(new BitmapImage(new Uri(iconPath, UriKind.Absolute)), false);
            BitmapImageMoniker = icon?.Moniker ?? KnownMonikers.Console;
            Content = terminal = new TerminalControl();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) terminal.Dispose();
            base.Dispose(disposing);
        }
    }
}
