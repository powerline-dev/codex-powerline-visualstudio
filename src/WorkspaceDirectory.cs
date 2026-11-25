using System;
using System.IO;
using EnvDTE;
using Microsoft.VisualStudio.Shell;

namespace CodexPowerline.VisualStudio
{
    internal static class WorkspaceDirectory
    {
        public static string Get()
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            var dte = ServiceProvider.GlobalProvider.GetService(typeof(DTE)) as DTE;
            // Prefer the active project, then the solution, including Open Folder workspaces.
            try
            {
                var project = dte?.ActiveDocument?.ProjectItem?.ContainingProject;
                var projectFile = project?.FullName;
                if (!string.IsNullOrEmpty(projectFile) && File.Exists(projectFile))
                    return Path.GetDirectoryName(projectFile);
                var solution = dte?.Solution?.FullName;
                if (!string.IsNullOrEmpty(solution))
                {
                    if (Directory.Exists(solution)) return solution;
                    if (File.Exists(solution)) return Path.GetDirectoryName(solution);
                }
                var document = dte?.ActiveDocument?.FullName;
                if (!string.IsNullOrEmpty(document) && File.Exists(document)) return Path.GetDirectoryName(document);
            }
            catch (System.Runtime.InteropServices.COMException) { }
            return Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        }
    }
}
