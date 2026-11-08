@echo off
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion
title Simple_.exe_Maker v2.4.0

if "%~1"=="" goto :usage
if not "%~3"=="" goto :usage

set "SEM_ARG1=%~f1"
set "SEM_ARG2="
if not "%~2"=="" set "SEM_ARG2=%~f2"
set "SEM_MAKER_DIR=%~dp0"
set "SEM_SELF=%~f0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:SEM_SELF);$m='###SIMPLE_EXE_MAKER_PS_'+'START###';$i=$s.IndexOf($m);if($i -lt 0){Write-Host '내부 스크립트를 찾을 수 없습니다.';exit 99};$p=$s.Substring($i+$m.Length);Invoke-Expression $p"
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
    echo 생성에 실패했습니다.
    echo.
    echo 계속하려면 아무 키나 누르세요 . . .
    pause >nul
    exit /b %RC%
)

echo 계속하려면 아무 키나 누르세요 . . .
pause >nul
exit /b 0

:usage
echo.
echo Simple_.exe_Maker v2.4.0
echo ============================
echo 실행 대상 1개 또는 실행 대상 + 아이콘 2개를 이 파일 위로 드래그 앤 드롭하세요.
echo 실행 대상만 넣으면 기존 아이콘을 자동으로 가져옵니다.
echo.
echo [실행 대상]
echo - .bat 파일
echo - .cmd 파일
echo - '바로가기' 파일 (.lnk)
echo - .exe 파일
echo.
echo [아이콘: 직접 지정할 때만 추가]
echo - .ico
echo - 정사각형 이미지 (.png / .jpg / .jpeg / .bmp / .gif / .tif / .tiff)
echo.
echo 이미지 파일은 반드시 1:1 비율이어야 합니다.
echo 1:1이 아니면 EXE를 생성하지 않습니다.
echo.
echo 계속하려면 아무 키나 누르세요 . . .
pause >nul
exit /b 1

###SIMPLE_EXE_MAKER_PS_START###

$ErrorActionPreference = 'Stop'
$TempDir = $null

function Fail([string]$Message) {
    throw $Message
}

function Escape-CSharpVerbatim([string]$Text) {
    if ($null -eq $Text) { return '' }
    return $Text.Replace('"', '""')
}

function New-HiddenIdentifier {
    # 사용자에게는 보이지 않지만 Windows에는 서로 다른 파일명으로 인식되도록
    # Zero Width Space(U+200B)와 Zero Width Non-Joiner(U+200C)를 사용한다.
    # 12자리 = 2^12 = 4,096개 조합.
    $chars = @([char]0x200B, [char]0x200C)
    $builder = New-Object System.Text.StringBuilder

    $value = Get-Random -Minimum 0 -Maximum 4096
    for ($i = 0; $i -lt 12; $i++) {
        [void]$builder.Append($chars[(($value -shr $i) -band 1)])
    }

    return $builder.ToString()
}

function New-MultiSizeIco {
    param(
        [Parameter(Mandatory=$true)][string]$SourceImage,
        [Parameter(Mandatory=$true)][string]$OutputIco
    )

    Add-Type -AssemblyName System.Drawing

    $img = $null
    try {
        $img = [System.Drawing.Image]::FromFile($SourceImage)

        if ($img.Width -ne $img.Height) {
            Fail '입력된 이미지의 규격이 1:1이 아닙니다.'
        }

        $sizes = @(256, 128, 64, 48, 32, 24, 16)
        $frames = New-Object System.Collections.Generic.List[byte[]]

        foreach ($size in $sizes) {
            $bmp = $null
            $g = $null
            $ms = $null

            try {
                $bmp = New-Object System.Drawing.Bitmap -ArgumentList $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
                $g = [System.Drawing.Graphics]::FromImage($bmp)

                $g.Clear([System.Drawing.Color]::Transparent)
                $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

                $g.DrawImage($img, 0, 0, $size, $size)

                $ms = New-Object System.IO.MemoryStream
                $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                $frames.Add($ms.ToArray())
            }
            finally {
                if ($ms) { $ms.Dispose() }
                if ($g) { $g.Dispose() }
                if ($bmp) { $bmp.Dispose() }
            }
        }

        $fs = [System.IO.File]::Open(
            $OutputIco,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        $bw = New-Object System.IO.BinaryWriter($fs)

        try {
            # ICONDIR
            $bw.Write([UInt16]0)
            $bw.Write([UInt16]1)
            $bw.Write([UInt16]$frames.Count)

            $offset = 6 + (16 * $frames.Count)

            for ($i = 0; $i -lt $frames.Count; $i++) {
                $size = $sizes[$i]
                $data = $frames[$i]
                $wh = if ($size -eq 256) { 0 } else { $size }

                # ICONDIRENTRY
                $bw.Write([Byte]$wh)
                $bw.Write([Byte]$wh)
                $bw.Write([Byte]0)
                $bw.Write([Byte]0)
                $bw.Write([UInt16]1)
                $bw.Write([UInt16]32)
                $bw.Write([UInt32]$data.Length)
                $bw.Write([UInt32]$offset)

                $offset += $data.Length
            }

            foreach ($data in $frames) {
                $bw.Write($data)
            }
        }
        finally {
            $bw.Dispose()
            $fs.Dispose()
        }
    }
    finally {
        if ($img) { $img.Dispose() }
    }
}

function Initialize-IconReader {
    if ('SemIconReader' -as [type]) { return }
    Add-Type -AssemblyName System.Drawing
    $code = @'
using System;
using System.IO;
using System.Drawing;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class SemIconReader
{
    private delegate bool EnumName(IntPtr module, IntPtr type, IntPtr name, IntPtr param);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr LoadLibraryEx(string path, IntPtr file, uint flags);
    [DllImport("kernel32.dll")] private static extern bool FreeLibrary(IntPtr module);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    private static extern bool EnumResourceNames(IntPtr module, IntPtr type, EnumName callback, IntPtr param);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    private static extern IntPtr FindResource(IntPtr module, IntPtr name, IntPtr type);
    [DllImport("kernel32.dll")] private static extern uint SizeofResource(IntPtr module, IntPtr resource);
    [DllImport("kernel32.dll")] private static extern IntPtr LoadResource(IntPtr module, IntPtr resource);
    [DllImport("kernel32.dll")] private static extern IntPtr LockResource(IntPtr resource);
    [DllImport("user32.dll")] private static extern bool DestroyIcon(IntPtr icon);
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    private struct FileInfo {
        public IntPtr Icon; public int Index; public uint Attributes;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string DisplayName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=80)] public string TypeName;
    }
    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    private static extern IntPtr SHGetFileInfo(string path, uint attributes, out FileInfo info, uint size, uint flags);

    private static byte[] ReadResource(IntPtr module, IntPtr name, int type) {
        IntPtr res = FindResource(module, name, new IntPtr(type));
        if (res == IntPtr.Zero) throw new InvalidDataException("Icon resource missing.");
        uint length = SizeofResource(module, res);
        if (length == 0 || length > 67108864) throw new InvalidDataException("Invalid icon size.");
        IntPtr data = LockResource(LoadResource(module, res));
        if (data == IntPtr.Zero) throw new InvalidDataException("Cannot read icon resource.");
        byte[] bytes = new byte[(int)length]; Marshal.Copy(data, bytes, 0, bytes.Length); return bytes;
    }
    // Keep every frame of the selected icon group, including original PNG/alpha data.
    public static bool ResourceIcon(string path, int index, string output) {
        IntPtr module = IntPtr.Zero;
        IntPtr allocatedName = IntPtr.Zero;
        try {
            if (String.Equals(Path.GetExtension(path), ".ico", StringComparison.OrdinalIgnoreCase)) {
                byte[] bytes = File.ReadAllBytes(path);
                if (bytes.Length < 6 || BitConverter.ToUInt16(bytes,0) != 0 ||
                    BitConverter.ToUInt16(bytes,2) != 1 || BitConverter.ToUInt16(bytes,4) == 0) return false;
                using (Icon check = new Icon(path)) { }
                File.WriteAllBytes(output, bytes); return true;
            }
            // Data/resource mapping only: do not run the source EXE or DLL entry point.
            module = LoadLibraryEx(Path.GetFullPath(path), IntPtr.Zero, 0x60);
            if (module == IntPtr.Zero) return false;
            List<object> names = new List<object>();
            EnumName callback = delegate(IntPtr m, IntPtr t, IntPtr n, IntPtr p) {
                // Copy names during enumeration; callback pointers are not retained.
                long value = n.ToInt64();
                names.Add((value & ~65535L) == 0 ? (object)(int)value : Marshal.PtrToStringUni(n)); return true;
            };
            EnumResourceNames(module, new IntPtr(14), callback, IntPtr.Zero);
            GC.KeepAlive(callback);
            IntPtr selected;
            if (index < 0) {
                long id = -(long)index;
                if (id > 65535) return false;
                selected = new IntPtr(id);
            } else {
                if (index >= names.Count) return false;
                if (names[index] is int) selected = new IntPtr((int)names[index]);
                else { allocatedName = Marshal.StringToHGlobalUni((string)names[index]); selected = allocatedName; }
            }
            byte[] group = ReadResource(module, selected, 14);
            if (group.Length < 6 || BitConverter.ToUInt16(group,0) != 0 || BitConverter.ToUInt16(group,2) != 1) return false;
            int count = BitConverter.ToUInt16(group,4);
            if (count < 1 || group.Length < 6 + 14 * count) return false;
            List<byte[]> frames = new List<byte[]>();
            for (int i=0; i<count; i++) {
                int id = BitConverter.ToUInt16(group, 6 + 14*i + 12);
                frames.Add(ReadResource(module, new IntPtr(id), 3));
            }
            using (MemoryStream stream = new MemoryStream())
            using (BinaryWriter writer = new BinaryWriter(stream)) {
                writer.Write((ushort)0); writer.Write((ushort)1); writer.Write((ushort)count);
                uint offset = (uint)(6 + 16*count);
                for (int i=0; i<count; i++) {
                    writer.Write(group, 6 + 14*i, 8);
                    writer.Write((uint)frames[i].Length); writer.Write(offset);
                    offset = checked(offset + (uint)frames[i].Length);
                }
                foreach (byte[] frame in frames) writer.Write(frame);
                writer.Flush();
                byte[] ico = stream.ToArray();
                using (MemoryStream verify = new MemoryStream(ico))
                using (Icon check = new Icon(verify)) { }
                File.WriteAllBytes(output, ico);
            }
            return true;
        } catch { return false; }
        finally {
            if (allocatedName != IntPtr.Zero) Marshal.FreeHGlobal(allocatedName);
            if (module != IntPtr.Zero) FreeLibrary(module);
        }
    }
    // BAT/CMD association icons and resource-extraction fallback. No shortcut overlay flags.
    public static bool ShellIcon(string path, string output) {
        FileInfo info = new FileInfo();
        try {
            IntPtr result = SHGetFileInfo(path, 0, out info, (uint)Marshal.SizeOf(typeof(FileInfo)), 0x100);
            if (result == IntPtr.Zero || info.Icon == IntPtr.Zero) return false;
            using (Icon icon = Icon.FromHandle(info.Icon))
            using (FileStream stream = File.Create(output)) icon.Save(stream);
            return true;
        } catch { return false; }
        finally { if (info.Icon != IntPtr.Zero) DestroyIcon(info.Icon); }
    }
}
'@
    Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing -ErrorAction Stop | Out-Null
}

function Get-AutomaticIcon {
    param([string]$TargetPath, [string]$IconLocation, [string]$ShortcutDirectory, [string]$OutputIco)
    try {
        Initialize-IconReader
        if (-not [string]::IsNullOrWhiteSpace($IconLocation)) {
            # Split at the final comma; commas inside quoted filenames remain intact.
            $location = [Environment]::ExpandEnvironmentVariables($IconLocation).Trim()
            $index = 0
            $match = [regex]::Match($location, '^(.*),\s*(-?\d+)\s*$')
            if ($match.Success) {
                $location = $match.Groups[1].Value.Trim()
                $index = [int]::Parse($match.Groups[2].Value)
            }
            $location = $location.Trim([char]34)
            if (-not [IO.Path]::IsPathRooted($location)) {
                $location = Join-Path $ShortcutDirectory $location
            }
            if ([SemIconReader]::ResourceIcon($location, $index, $OutputIco)) {
                Write-Host '바로가기에 지정된 아이콘을 가져왔습니다.'
                return $true
            }
            Write-Host '지정된 아이콘을 읽지 못해 실제 실행 대상의 아이콘을 확인합니다.'
        }
    }
    catch { Write-Host '지정 아이콘 확인에 실패하여 실행 대상의 아이콘을 확인합니다.' }

    try {
        Initialize-IconReader
        if ([SemIconReader]::ResourceIcon($TargetPath, 0, $OutputIco)) {
            Write-Host '실행 대상의 내장 아이콘을 가져왔습니다.'
            return $true
        }
        if ([SemIconReader]::ShellIcon($TargetPath, $OutputIco)) {
            Write-Host 'Windows에서 제공하는 대상 아이콘을 가져왔습니다.'
            return $true
        }
    }
    catch { }
    return $false
}

function Read-ShortcutInfo {
    param(
        [Parameter(Mandatory=$true)][string]$ShortcutPath
    )

    $shell = $null
    $shortcut = $null

    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($ShortcutPath)

        $target = [Environment]::ExpandEnvironmentVariables([string]$shortcut.TargetPath)
        $args = [string]$shortcut.Arguments
        $work = [Environment]::ExpandEnvironmentVariables([string]$shortcut.WorkingDirectory)
        $style = [int]$shortcut.WindowStyle

        if ([string]::IsNullOrWhiteSpace($target)) {
            Fail "이 '바로가기' 파일에서는 일반 실행 대상을 확인할 수 없습니다.`n특수 바로가기 또는 Microsoft Store 앱 바로가기는 현재 지원하지 않습니다."
        }

        if ([string]::IsNullOrWhiteSpace($work) -and (Test-Path -LiteralPath $target -PathType Leaf)) {
            $work = [System.IO.Path]::GetDirectoryName($target)
        }

        return [PSCustomObject]@{
            TargetPath       = $target
            Arguments        = $args
            WorkingDirectory = $work
            WindowStyle      = $style
            IconLocation     = [string]$shortcut.IconLocation
        }
    }
    finally {
        if ($shortcut) {
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
        }
        if ($shell) {
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
        }
    }
}

try {
    $arg1 = $env:SEM_ARG1
    $arg2 = $env:SEM_ARG2
    $makerDir = $env:SEM_MAKER_DIR

    if ([string]::IsNullOrWhiteSpace($arg1)) {
        Fail '실행 대상 파일이 필요합니다.'
    }
    $files = @($arg1)
    if (-not [string]::IsNullOrWhiteSpace($arg2)) { $files += $arg2 }

    foreach ($f in $files) {
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) {
            Fail "파일을 찾을 수 없습니다: $f"
        }
    }

    $launchExts = @('.bat', '.cmd', '.lnk', '.exe')
    $imageExts = @('.ico', '.png', '.jpg', '.jpeg', '.bmp', '.gif', '.tif', '.tiff')

    $launchFiles = @($files | Where-Object {
        $launchExts -contains ([System.IO.Path]::GetExtension($_).ToLowerInvariant())
    })

    $imageFiles = @($files | Where-Object {
        $imageExts -contains ([System.IO.Path]::GetExtension($_).ToLowerInvariant())
    })

    if ($launchFiles.Count -ne 1 -or
        ($files.Count -eq 2 -and $imageFiles.Count -ne 1) -or
        ($files.Count -eq 1 -and $imageFiles.Count -ne 0)) {
        Fail "입력 형식이 올바르지 않습니다.`n실행 대상(.bat / .cmd / .lnk / .exe) 1개만 넣거나, 실행 대상 1개와 아이콘 1개를 함께 넣어 주세요."
    }

    $launchFile = $launchFiles[0]
    $imageFile = $null
    if ($imageFiles.Count -eq 1) { $imageFile = $imageFiles[0] }

    if ([string]::IsNullOrWhiteSpace($makerDir)) {
        $makerDir = [Environment]::GetFolderPath('Desktop')
    }

    # ================================================================
    # C# 컴파일러 확인
    # ================================================================
    $candidates = @(
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
    )

    $csc = $candidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if (-not $csc) {
        $cmd = Get-Command csc.exe -ErrorAction SilentlyContinue
        if ($cmd) { $csc = $cmd.Source }
    }

    if (-not $csc) {
        Fail 'C# 컴파일러(csc.exe)를 찾을 수 없습니다. .NET Framework 4.x가 설치/활성화되어 있는지 확인하세요.'
    }

    $TempDir = Join-Path $env:TEMP ('SimpleExeMaker_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    # ================================================================
    # 실행 대상 분석
    # ================================================================
    $launchExt = [System.IO.Path]::GetExtension($launchFile).ToLowerInvariant()

    $targetPath = ''
    $arguments = ''
    $workingDirectory = ''
    $windowStyle = 1
    $iconLocation = ''

    if ($launchExt -eq '.bat' -or $launchExt -eq '.cmd') {
        Write-Host ''
        if ($launchExt -eq '.cmd') { Write-Host '실행 대상: CMD 파일' } else { Write-Host '실행 대상: BAT 파일' }

        $targetPath = $launchFile
        $workingDirectory = [System.IO.Path]::GetDirectoryName($launchFile)
    }
    elseif ($launchExt -eq '.lnk') {
        Write-Host ''
        Write-Host "실행 대상: '바로가기' 파일(.lnk)"
        Write-Host '바로가기의 실행 정보를 읽는 중...'

        $info = Read-ShortcutInfo -ShortcutPath $launchFile

        $targetPath = $info.TargetPath
        $arguments = $info.Arguments
        $workingDirectory = $info.WorkingDirectory
        $windowStyle = $info.WindowStyle
        $iconLocation = $info.IconLocation
    }
    elseif ($launchExt -eq '.exe') {
        Write-Host ''
        Write-Host '실행 대상: EXE 파일'
        $targetPath = $launchFile
        $arguments = ''
        $workingDirectory = [System.IO.Path]::GetDirectoryName($launchFile)
        $windowStyle = 1
    }

    $iconPath = $null
    $iconDescription = '기본 EXE 아이콘'
    if ($null -ne $imageFile) {
        # ================================================================
        # 아이콘 준비
        # ================================================================
        $imageExt = [System.IO.Path]::GetExtension($imageFile).ToLowerInvariant()

        if ($imageExt -eq '.ico') {
            $iconPath = $imageFile
        }
        else {
            $iconPath = Join-Path $TempDir 'GeneratedIcon.ico'

            Write-Host ''
            Write-Host '아이콘 이미지를 확인하는 중...'

            try {
                New-MultiSizeIco -SourceImage $imageFile -OutputIco $iconPath
            }
            catch {
                if ($_.Exception.Message -eq '입력된 이미지의 규격이 1:1이 아닙니다.') {
                    Write-Host ''
                    Write-Host '오류: 입력된 이미지의 규격이 1:1이 아닙니다.'
                    Write-Host '정사각형 이미지를 사용해 주세요.'
                    Write-Host 'EXE 생성을 취소합니다.'
                    Write-Host ''
                    exit 20
                }

                throw
            }
        }
        $iconDescription = $imageFile
    }
    else {
        Write-Host ''
        Write-Host '기존 아이콘을 자동으로 가져오는 중...'
        $autoIcon = Join-Path $TempDir 'OriginalIcon.ico'
        $shortcutDir = [IO.Path]::GetDirectoryName($launchFile)
        if (Get-AutomaticIcon -TargetPath $targetPath -IconLocation $iconLocation -ShortcutDirectory $shortcutDir -OutputIco $autoIcon) {
            $iconPath = $autoIcon
            $iconDescription = '원본/대상 아이콘 자동 가져오기'
        }
        else {
            Write-Host '원본 아이콘을 가져올 수 없어 기본 EXE 아이콘으로 생성합니다.'
        }
    }

    # ================================================================
    # 임시 출력 경로
    # 최종 위치는 컴파일 성공 후 사용자가 선택한다.
    # ================================================================
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($launchFile)
    $tempExePath = Join-Path $TempDir ($baseName + '.exe')

    # ================================================================
    # 런처 C# 소스 생성
    # ================================================================
    $targetCS = Escape-CSharpVerbatim $targetPath
    $argsCS = Escape-CSharpVerbatim $arguments
    $workCS = Escape-CSharpVerbatim $workingDirectory

    $styleCS = switch ($windowStyle) {
        3 { 'ProcessWindowStyle.Maximized' }
        7 { 'ProcessWindowStyle.Minimized' }
        default { 'ProcessWindowStyle.Normal' }
    }

    $source = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

internal static class Program
{    [STAThread]
    private static void Main()
    {
        const string TargetPath = @"$targetCS";
        const string Arguments = @"$argsCS";
        const string WorkingDirectory = @"$workCS";
        var psi = new ProcessStartInfo
        {
            FileName = TargetPath,
            Arguments = Arguments,
            UseShellExecute = true,
            WindowStyle = $styleCS
        };

        if (!string.IsNullOrWhiteSpace(WorkingDirectory))
            psi.WorkingDirectory = WorkingDirectory;

        Process.Start(psi);
    }
}
"@

    $csPath = Join-Path $TempDir 'Launcher.cs'
    Set-Content -LiteralPath $csPath -Value $source -Encoding UTF8

    # ================================================================
    # EXE 생성
    # ================================================================
    Write-Host ''
    Write-Host '런처 EXE를 생성하는 중...'
    Write-Host ('실행 대상 : ' + $launchFile)
    Write-Host ('실제 대상 : ' + $targetPath)
    Write-Host ('아이콘     : ' + $iconDescription)
    Write-Host ''

    $compileArgs = @('/nologo', '/target:winexe', '/optimize+')
    if (-not [string]::IsNullOrWhiteSpace($iconPath)) {
        $compileArgs += '/win32icon:' + $iconPath
    }
    $compileArgs += '/out:' + $tempExePath
    $compileArgs += $csPath
    & $csc @compileArgs

    if ($LASTEXITCODE -ne 0) {
        Fail "컴파일에 실패했습니다. 종료 코드: $LASTEXITCODE"
    }

    if (-not (Test-Path -LiteralPath $tempExePath -PathType Leaf)) {
        Fail '컴파일은 끝났지만 EXE 파일이 생성되지 않았습니다.'
    }

    Write-Host ''
    Write-Host '.exe 생성이 완료되었습니다.'
    Write-Host ''
    Write-Host '저장할 위치를 선택해 주세요.'
    Write-Host '[1] Simple_.exe_Maker 폴더'
    Write-Host '[2] 바탕화면'
    Write-Host ''

    do {
        $choice = (Read-Host '번호를 입력하세요 (1/2)').Trim()

        if ($choice -eq '1') {
            $destinationDir = $makerDir
        }
        elseif ($choice -eq '2') {
            $destinationDir = [Environment]::GetFolderPath('Desktop')
        }
        else {
            Write-Host '1 또는 2를 입력해 주세요.'
        }
    } while ($choice -ne '1' -and $choice -ne '2')

    if ([string]::IsNullOrWhiteSpace($destinationDir)) {
        Fail '선택한 저장 위치를 확인할 수 없습니다.'
    }

    # ------------------------------------------------------------
    # v2.2.0 숨은 식별자 방식
    # ------------------------------------------------------------
    # 매 생성마다 실제 파일명 끝에 12자리의 보이지 않는 식별자를 붙인다.
    # 사용자가 보는 이름은 사실상 같지만 Windows는 다른 파일명으로 인식한다.
    #
    # 예:
    #   표시상: ComfyUI.exe
    #   실제:   ComfyUI<보이지 않는 12자리 식별자>.exe
    #
    # 이전 생성 기록은 저장하지 않는다.
    # 우연히 같은 조합이 나와 실제 경로가 겹치면 새 식별자를 다시 생성한다.

    $visibleBaseName = $baseName

    # 원본 EXE와 같은 폴더에 생성하는 경우,
    # 사용자가 원본과 런처를 구분할 수 있도록 표시 이름에 Launcher를 붙인다.
    if (
        ([System.IO.Path]::GetExtension($launchFile) -ieq '.exe') -and
        [string]::Equals(
            [System.IO.Path]::GetFullPath($destinationDir),
            [System.IO.Path]::GetFullPath([System.IO.Path]::GetDirectoryName($launchFile)),
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        $visibleBaseName = $baseName + ' Launcher'
    }

    # 무작위 재추첨은 최대 32회. 이후에는 4,096개 조합을 한 번씩 확인한다.
    # 최악의 경우에도 유한하게 끝나며, 빈 조합이 있는데 임의로 중단하지 않는다.
    $outPath = $null
    for ($attempt = 0; $attempt -lt 32; $attempt++) {
        $hiddenId = New-HiddenIdentifier
        $candidate = Join-Path $destinationDir ($visibleBaseName + $hiddenId + '.exe')
        if (-not (Test-Path -LiteralPath $candidate)) {
            $outPath = $candidate
            break
        }
    }

    if ($null -eq $outPath) {
        for ($value = 0; $value -lt 4096; $value++) {
            $builder = New-Object System.Text.StringBuilder
            for ($i = 0; $i -lt 12; $i++) {
                [void]$builder.Append([char](0x200B + (($value -shr $i) -band 1)))
            }
            $candidate = Join-Path $destinationDir ($visibleBaseName + $builder.ToString() + '.exe')
            if (-not (Test-Path -LiteralPath $candidate)) {
                $outPath = $candidate
                break
            }
        }
    }

    if ($null -eq $outPath) {
        Fail '같은 표시 이름에 사용할 수 있는 4,096개 식별자가 모두 사용 중입니다. 기존 런처를 정리하거나 다른 저장 위치를 선택해 다시 생성해 주세요.'
    }

    Move-Item -LiteralPath $tempExePath -Destination $outPath

    Write-Host ''
    Write-Host '저장이 완료되었습니다.'
    Write-Host ('표시 이름   : ' + $visibleBaseName + '.exe')
    Write-Host ('실제 경로   : ' + $outPath)
    Write-Host ''
}
catch {
    Write-Host ''
    Write-Host ('오류: ' + $_.Exception.Message)
    Write-Host ''
    exit 1
}
finally {
    if ($TempDir -and (Test-Path -LiteralPath $TempDir)) {
        Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
