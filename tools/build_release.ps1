# SHODAN Stat Editor Offline：按当前源码打包，并检查 exe / 快捷方式的链路。
#   1. 把当前源码（src\stat_editor_offline.lua、offline\*.lua、启动器与运行库）打包到
#      offline\release\<yyyyMMdd-HHmmss>\SHODAN Stat Editor Offline\，与 package.py 的 portable 版布局一致
#   2. 校验打包结果与源码一致，把项目根目录的“SHODAN Stat Editor Offline.lnk”指向新 exe
#   3. 检测：正在运行的编辑器进程（含没有窗口的残留进程），桌面 / 开始菜单 / 项目根目录里指向
#      “SHODAN Stat Editor Offline.exe”的快捷方式，以及它们指向的那份是否与当前源码一致
# 由项目根目录的 build_release.bat 调用。参数：-NoShortcut 只打包，不改快捷方式；
#   -Dev <commit>  标记为来自该上游开发提交（写进 build.txt 的 dev=，窗口标题显示 “v<版本> dev <commit>”）。
param([switch]$NoShortcut, [string]$Dev = '')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)
$top = 'SHODAN Stat Editor Offline'
$exeName = 'SHODAN Stat Editor Offline.exe'

function Say([string]$text, [string]$color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Fail([string]$text) { Write-Host ('失败：' + $text) -ForegroundColor Red; exit 1 }
function Sha([string]$path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash }
function In-Root([string]$rel) { Join-Path $root $rel }

Say ('项目：' + $root) 'Cyan'

# ------------------------------------------------------------------ 1. 来源文件（发布路径 -> 源文件）
# 与 package.py 一样包含 offline/ 下的全部运行时模块，避免新增组件漏打包。
$modules = Get-ChildItem -LiteralPath (In-Root 'offline') -Filter '*.lua' -File | Sort-Object Name | Select-Object -ExpandProperty BaseName
$files = [ordered]@{}
$files[$exeName]             = In-Root ('offline\launcher\' + $exeName)
$files['lua51.dll']          = In-Root 'offline\runtime\lua51.dll'
$files['libsodium.dll']      = In-Root 'offline\runtime\libsodium.dll'
$files['shodan_hash.dll']    = In-Root 'offline\launcher\shodan_hash.dll'
$files['app\stat_editor.lua'] = In-Root 'src\stat_editor_offline.lua'
foreach ($m in $modules) { $files['app\' + $m + '.lua'] = In-Root ('offline\' + $m + '.lua') }
$files['app\entity_names.tsv']  = In-Root 'offline\entity_names.tsv'
$files['app\entity_catalog.default.json'] = In-Root 'offline\entity_catalog.default.json'
$files['ENTITY_DEMOLITION.md']  = In-Root 'offline\ENTITY_DEMOLITION.md'
$files['ENTITY_COMPONENTS.md']  = In-Root 'offline\ENTITY_COMPONENTS.md'
$files['BOMBARDMENT_COMPONENTS.md'] = In-Root 'offline\BOMBARDMENT_COMPONENTS.md'
$files['ORBITAL_WEAPON_COMPONENTS.md'] = In-Root 'offline\ORBITAL_WEAPON_COMPONENTS.md'
$files['NAMED_PARAMETERS.md'] = In-Root 'offline\NAMED_PARAMETERS.md'
$files['PLAYER_SAVE.md'] = In-Root 'offline\PLAYER_SAVE.md'
$files['PRESETS.md'] = In-Root 'offline\PRESETS.md'
$files['PRELOAD_COMPONENTS.md'] = In-Root 'offline\PRELOAD_COMPONENTS.md'
$files['PLANET_SETTINGS.md'] = In-Root 'offline\PLANET_SETTINGS.md'
$files['ENEMY_DATA.md'] = In-Root 'offline\ENEMY_DATA.md'
$files['UPSTREAM_4.5.1_PORT.md'] = In-Root 'offline\UPSTREAM_4.5.1_PORT.md'
$files['PLAYER_DATA.md'] = In-Root 'offline\PLAYER_DATA.md'
$files['SPAWN_EDITOR.md'] = In-Root 'offline\SPAWN_EDITOR.md'
$files['MODIFIER_ATTACHMENTS.md'] = In-Root 'offline\MODIFIER_ATTACHMENTS.md'
$files['REFERENCE_NAVIGATION.md'] = In-Root 'offline\REFERENCE_NAVIGATION.md'
$files['RECORD_NAMES.md'] = In-Root 'offline\RECORD_NAMES.md'
$files['STRATAGEM_COMPONENTS.md'] = In-Root 'offline\STRATAGEM_COMPONENTS.md'
$files['DAMAGE_COMPONENTS.md'] = In-Root 'offline\DAMAGE_COMPONENTS.md'
$files['PROJECTILE_COMPONENTS.md'] = In-Root 'offline\PROJECTILE_COMPONENTS.md'
$files['EXPLOSION_COMPONENTS.md'] = In-Root 'offline\EXPLOSION_COMPONENTS.md'
$files['ARC_COMPONENTS.md'] = In-Root 'offline\ARC_COMPONENTS.md'
$files['BEAM_COMPONENTS.md'] = In-Root 'offline\BEAM_COMPONENTS.md'
$files['ENTITY_CATALOG_API.md'] = In-Root 'offline\ENTITY_CATALOG_API.md'
$files['ENTITY_CATALOG_SCHEMA.json'] = In-Root 'offline\entity_catalog.schema.json'

$missing = @()
foreach ($k in $files.Keys) {
    if (-not (Test-Path -LiteralPath $files[$k] -PathType Leaf)) { $missing += $files[$k] }
}
if ($missing.Count -gt 0) { Fail ("缺少源文件：`n  " + ($missing -join "`n  ")) }

$panel = $files['app\stat_editor.lua']
$panelText = [IO.File]::ReadAllText($panel, $utf8)
if ($panelText -match "version = '([\d.]+)'") { $version = $Matches[1] } else { Fail '在 src\stat_editor_offline.lua 里找不到版本号' }
$srcHash = Sha $panel

# ------------------------------------------------------------------ 2. 打包
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$releaseDir = In-Root ('offline\release\' + $stamp)
$out = Join-Path $releaseDir $top
if (Test-Path -LiteralPath $releaseDir) { Fail ('文件夹已存在：' + $releaseDir) }
New-Item -ItemType Directory -Force -Path (Join-Path $out 'app') | Out-Null
Say ('打包 v' + $version + ' -> ' + $out) 'Cyan'

# 测试用的 --[[DEV]] ... --[[/DEV]] 段不进发布版（package.py 同样处理；stat_editor.lua 原样复制）
$devBlock = '(?s)[ \t]*--\[\[DEV\]\].*?--\[\[/DEV\]\][^\n]*\n'
foreach ($k in $files.Keys) {
    $dst = Join-Path $out $k
    if ($k -like 'app\*.lua' -and $k -ne 'app\stat_editor.lua') {
        $text = [IO.File]::ReadAllText($files[$k], $utf8)
        $text = [regex]::Replace($text, $devBlock, '')
        if ($text.Contains('SHODAN_HOST_TEST')) { Fail ($k + ' 里还留有测试代码（SHODAN_HOST_TEST）') }
        [IO.File]::WriteAllText($dst, $text, $utf8)
    } else {
        Copy-Item -LiteralPath $files[$k] -Destination $dst -Force
    }
}

# build.txt：版本、提交、渠道、上游开发提交，以及打包时间（显示在窗口标题上，看得出跑的是哪一次打包）
$commit = ''
if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (In-Root '.git'))) {
    try { $commit = (& git -C $root rev-parse HEAD 2>$null | Select-Object -First 1) } catch { $commit = '' }
    if (-not $commit) { $commit = '' }
}
$Dev = ($Dev -replace '\s', '').ToLowerInvariant()
$channel = if ($Dev) { 'dev' } else { 'local' }
$devLine = if ($Dev) { "dev=$Dev`n" } else { '' }
$buildTxt = "version=$version`ncommit=$commit`nchannel=$channel`n" + $devLine + "built=$stamp`n"
[IO.File]::WriteAllText((Join-Path $out 'app\build.txt'), $buildTxt, $utf8)

# 说明与第三方许可
$readme = In-Root 'offline\RELEASE_README.txt'
if (Test-Path -LiteralPath $readme) {
    [IO.File]::WriteAllText((Join-Path $out 'README.txt'), [IO.File]::ReadAllText($readme, $utf8).Replace('{version}', $version), $utf8)
}
# the global presets folder beside the exe (the editor keeps preset_library.json there)
New-Item -ItemType Directory -Force -Path (Join-Path $out 'Presets') | Out-Null
Copy-Item -LiteralPath (In-Root 'offline\PRESETS_FOLDER_README.txt') -Destination (Join-Path $out 'Presets\README.txt') -Force
$licenses = @('LuaJIT.txt', 'libsodium.txt') | ForEach-Object { In-Root ('offline\licenses\' + $_) } | Where-Object { Test-Path -LiteralPath $_ }
if ($licenses.Count -gt 0) {
    $parts = $licenses | ForEach-Object { ([IO.File]::ReadAllText($_, $utf8)).Trim() }
    $notices = ($parts -join ("`n`n" + ('=' * 79) + "`n`n")) + "`n"
    [IO.File]::WriteAllText((Join-Path $out 'THIRD-PARTY-NOTICES.txt'), $notices.Replace("`r`n", "`n").Replace("`n", "`r`n"), $utf8)
}

# 校验：每个文件都在且不为空；面板代码与源码逐字节一致
foreach ($k in $files.Keys) {
    $f = Join-Path $out $k
    if (-not (Test-Path -LiteralPath $f) -or (Get-Item -LiteralPath $f).Length -eq 0) { Fail ('打包后缺少或为空：' + $k) }
}
$builtExe = Join-Path $out $exeName
if ((Sha (Join-Path $out 'app\stat_editor.lua')) -ne $srcHash) { Fail '打包后的 app\stat_editor.lua 与源码不一致' }
Say ('打包完成，面板代码 SHA256 ' + $srcHash.Substring(0, 12) + '（与源码一致）') 'Green'

# ------------------------------------------------------------------ 3. 项目根目录的快捷方式
$shell = New-Object -ComObject WScript.Shell
$link = In-Root ($top + '.lnk')
if ($NoShortcut) {
    Say '（-NoShortcut：没有改快捷方式）' 'Yellow'
} else {
    $sc = $shell.CreateShortcut($link)
    $sc.TargetPath = $builtExe
    $sc.WorkingDirectory = $out
    $sc.IconLocation = $builtExe + ',0'
    $sc.Description = 'SHODAN Stat Editor Offline v' + $version + '，打包于 ' + $stamp
    $sc.Save()
    Say ('快捷方式已更新：' + $link) 'Green'
    Say ('  -> ' + $builtExe) 'Green'
}

# ------------------------------------------------------------------ 4. 链路检测
Say ''
Say '==== 链路检测 ====' 'Cyan'

# 一份编辑器（exe 所在文件夹）的面板代码是否与当前源码一致
function Copy-State([string]$exe) {
    if (-not $exe) { return '（目标为空）' }
    if (-not (Test-Path -LiteralPath $exe)) { return '目标 exe 不存在' }
    $code = Join-Path (Split-Path -Parent $exe) 'app\stat_editor.lua'
    if (-not (Test-Path -LiteralPath $code)) { return '旁边没有 app\stat_editor.lua' }
    $b = Join-Path (Split-Path -Parent $exe) 'app\build.txt'
    $built = ''
    if (Test-Path -LiteralPath $b) {
        $m = [regex]::Match([IO.File]::ReadAllText($b, $utf8), 'built=(\S+)')
        if ($m.Success) { $built = '，打包于 ' + $m.Groups[1].Value }
    }
    if ((Sha $code) -eq $srcHash) { return '与当前源码一致' + $built }
    return '旧版本：与当前源码不一致' + $built
}

# 正在运行的编辑器：它在启动时读取代码，改动要关掉重开才生效；没有窗口的是残留进程
$procs = @(Get-CimInstance Win32_Process -Filter "Name = '$exeName'" -ErrorAction SilentlyContinue)
if ($procs.Count -eq 0) {
    Say '没有正在运行的编辑器。'
} else {
    $stale = @()
    foreach ($p in $procs) {
        $gp = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
        $hasWindow = $gp -and $gp.MainWindowHandle -ne [IntPtr]::Zero
        $state = Copy-State $p.ExecutablePath
        $line = '运行中 PID ' + $p.ProcessId + '：' + $p.ExecutablePath + '（' + $state + '）'
        if ($hasWindow) { Say $line 'Yellow' } else { Say ($line + ' —— 没有窗口，可能是卡住的残留进程') 'Red'; $stale += $p }
    }
    Say '编辑器只在启动时读取代码：要看到新版本，先关掉上面这些，再用新快捷方式打开。' 'Yellow'
    if ($stale.Count -gt 0) {
        $answer = Read-Host ('结束这 ' + $stale.Count + ' 个没有窗口的残留进程？(Y/N)')
        if ($answer -match '^[Yy]') {
            foreach ($p in $stale) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
            Say '已结束。' 'Green'
        }
    }
}

# 指向编辑器的快捷方式：桌面（含 OneDrive 桌面、公共桌面）、开始菜单、项目根目录
$places = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    [Environment]::GetFolderPath('StartMenu'),
    [Environment]::GetFolderPath('CommonStartMenu'),
    $root
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
$found = 0
$seen = @{}
foreach ($place in $places) {
    $depth = if ($place -eq $root) { 0 } else { 3 }
    $links = Get-ChildItem -LiteralPath $place -Filter '*.lnk' -Recurse -Depth $depth -ErrorAction SilentlyContinue
    foreach ($l in $links) {
        if ($seen.ContainsKey($l.FullName)) { continue }
        $seen[$l.FullName] = $true
        try { $target = $shell.CreateShortcut($l.FullName).TargetPath } catch { continue }
        if ($target -and ((Split-Path -Leaf $target) -ieq $exeName)) {
            $found++
            $state = Copy-State $target
            $color = if ($state.StartsWith('与当前源码一致')) { 'Green' } else { 'Red' }
            Say ('快捷方式：' + $l.FullName) $color
            Say ('  -> ' + $target + '（' + $state + '）') $color
        }
    }
}
if ($found -eq 0) { Say '没有找到指向编辑器的快捷方式。' }
Say ''
Say ('完成。请用项目根目录的“' + $top + '.lnk”启动；窗口标题会显示“build ' + $stamp + '”，最后统一为“Reorganized by Thodmc”。') 'Cyan'
