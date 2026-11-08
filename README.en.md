[한국어](README.md) · **English**

# Simple .exe Maker

Create a small Windows launcher EXE for a program or script you use often. Put the launcher on your desktop or move it to another folder, then use it like a remote control to start the original file where it already lives. The launcher remembers the original path, so rebuild it if you move the target.

Drop in a single target to use its existing icon. Maker reads the embedded icon from an EXE or the icon configured for a shortcut. For BAT and CMD, it uses the Windows file type icon. To pick a different icon, drop in the target and an image together.

This program was developed on Windows 11. Operation on Linux, macOS, or other environments is not guaranteed.

## Why I built it

I built this tool because I found the arrow overlay on Windows shortcut (`.lnk`) icons distracting. The goal was to make a small EXE that works like a remote control, using the icon you want without the shortcut arrow and launching the original program or script from wherever you keep the launcher.

## Getting started

1. Download `Simple_.exe_Maker_v2.4.1.zip` from [Releases](../../releases) and extract it.
2. Select the target file to use its existing icon, or select the target and an image together to use a custom icon.
3. Drag the selected files onto `Simple_.exe_Maker_v2.4.1.bat`.
4. Save the launcher to the Maker folder or your desktop, then run the generated EXE.

| Input | Supported formats |
| --- | --- |
| Launch target | BAT, CMD, LNK, EXE |
| Custom icon | ICO, PNG, JPG, JPEG, BMP, GIF, TIF, TIFF |

Images other than ICO must be square. Creating a launcher requires Windows and the .NET Framework 4.x C# compiler (`csc.exe`). Maker checks the Windows .NET Framework folders for the compiler first. If you need to install .NET Framework, see the [official Microsoft .NET Framework downloads](https://dotnet.microsoft.com/en-us/download/dotnet-framework) for versions compatible with your Windows installation.

## Icons and launch paths

- For EXEs, Maker tries the embedded icon first. For LNK files, it tries the shortcut's configured icon first. BAT and CMD use the Windows file type icon. If automatic extraction fails, Maker generates the launcher with a default icon.
- For LNK files, Maker reads the target path, arguments, working directory, and window state. To include launch arguments, use a working shortcut as the input.
- The launcher runs the original file from its original path. If you move the target, rebuild the launcher using the new path.
- The actual filename includes invisible Unicode characters so Windows can distinguish icon cache entries. Generated EXEs are unsigned.
- Maker runs from a single BAT file and invokes Windows PowerShell and the C# compiler internally.

On Windows 11, the author verified that Maker creates a launcher with the target’s existing icon when no custom image is provided, and that the launcher still starts the original target after being moved to another folder.

[Detailed guide (Korean)](USER_GUIDE.ko.txt) · [Detailed guide (English)](USER_GUIDE.en.txt) · [Changelog (Korean)](CHANGELOG.ko.txt)

## Permission

You may use and modify this software and redistribute original or modified copies free of charge. You may not sell original or modified copies or charge for downloading or providing them. [Full permission notice](LICENSE.md)
