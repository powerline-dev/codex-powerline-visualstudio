using System;
using System.ComponentModel.Design;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.VisualStudio.Shell;
using Microsoft.VisualStudio.Shell.Interop;

namespace CodexPowerline.VisualStudio
{
    [PackageRegistration(UseManagedResourcesOnly = true, AllowsBackgroundLoading = true)]
    [InstalledProductRegistration("Codex Powerline", "Codex Powerline sidebar terminal", "0.1.1")]
    [ProvideMenuResource("Menus.ctmenu", 1)]
    [ProvideToolWindow(typeof(PowerlineToolWindow), Style = VsDockStyle.Tabbed,
        Window = ToolWindowGuids80.SolutionExplorer, Orientation = ToolWindowOrientation.Right, DockedWidth = 500)]
    [Guid("0758e57c-d87d-4e9c-9acf-073bfc06d943")]
    public sealed class PowerlinePackage : AsyncPackage
    {
        internal static PowerlinePackage Instance { get; private set; }

        public PowerlinePackage() { Instance = this; }

        protected override async Task InitializeAsync(CancellationToken cancellationToken, IProgress<ServiceProgressData> progress)
        {
            await JoinableTaskFactory.SwitchToMainThreadAsync(cancellationToken);
            var commands = await GetServiceAsync(typeof(IMenuCommandService)) as OleMenuCommandService;
            commands?.AddCommand(new MenuCommand(OpenTerminal,
                new CommandID(new Guid("40fbb5cd-94aa-4539-bf64-9f42f385996a"), 0x0100)));
        }

        private void OpenTerminal(object sender, EventArgs args)
        {
            _ = JoinableTaskFactory.RunAsync(async () =>
            {
                try
                {
                    await ShowToolWindowAsync(typeof(PowerlineToolWindow), 0, true, DisposalToken);
                }
                catch (Exception error)
                {
                    ActivityLog.LogError("Codex Powerline", error.ToString());
                }
            });
        }
    }
}
