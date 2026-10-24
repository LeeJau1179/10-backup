# re-patch-storyline.ps1
# 用途：StoryLine 插件每次被 Obsidian 更新后，会回滚下面两处补丁，跑本脚本可一键重新打上：
#   1. 看板虚拟滚动（threshold:40 → threshold:1e9）：否则 board 里超过 40 张卡片的 Act 列拖拽时跳到底部。
#   2. 故事线轨道图（Subway map）筛选器默认全不选：打开视图时不显示任何线，在筛选菜单里勾选要看的线；菜单有「全部显示」「全部不选」。
#
# 用法：右键 "使用 PowerShell 运行"，或：
#       powershell -ExecutionPolicy Bypass -File re-patch-storyline.ps1
# 打完后：在 Obsidian 里 设置 → 社区插件 → 禁用再启用 StoryLine（或重启 Obsidian）即可生效。

$ErrorActionPreference = "Stop"

$pluginDir = "D:\Obsidian-S\.obsidian\plugins\storyline"
$mainJs = Join-Path $pluginDir "main.js"
$manifest = Join-Path $pluginDir "manifest.json"

if (-not (Test-Path -LiteralPath $mainJs)) {
    Write-Host "[错误] 找不到 main.js: $mainJs" -ForegroundColor Red
    exit 1
}

# 读取当前插件版本（仅用于备份命名）
$version = "unknown"
if (Test-Path -LiteralPath $manifest) {
    try {
        $mf = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json
        $version = $mf.version
    } catch { }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$content = [System.IO.File]::ReadAllText($mainJs, $utf8NoBom)

function Count-Text([string]$text, [string]$part) {
    return ([regex]::Matches($text, [regex]::Escape($part))).Count
}

$patches = @(
    @{ Name = '看板虚拟滚动'; Old = 'threshold:40'; New = 'threshold:1e9' },
    @{ Name = '筛选器·初始化'; Old = @'
this.hiddenPlotlines=new Set;
'@; New = @'
this.shownPlotlines=new Set;
'@ },
    @{ Name = '筛选器·按钮状态'; Old = @'
cls:`clickable-icon${this.hiddenPlotlines.size>0?" is-active":""}`}),T=C.createSpan();Jr.setIcon(T,"filter"),be(C,this.hiddenPlotlines.size>0?`Filtering: ${this.hiddenPlotlines.size} hidden`:"Filter plotlines")
'@; New = @'
cls:`clickable-icon${this.shownPlotlines.size>0?" is-active":""}`}),T=C.createSpan();Jr.setIcon(T,"filter"),be(C,this.shownPlotlines.size>0?`筛选故事线（已选 ${this.shownPlotlines.size} 条）`:"筛选故事线（未选）")
'@ },
    @{ Name = '筛选器·菜单'; Old = @'
O.addItem(F=>{F.setTitle("Show all").setIcon("eye").onClick(()=>{this.hiddenPlotlines.clear(),this.refresh()})}),O.addSeparator();for(let F of L){let D=this.hiddenPlotlines.has(F);O.addItem(N=>{N.setTitle(`${D?"   ":"\u2713 "}${this.formatPlotlineName(F)}`).onClick(()=>{D?this.hiddenPlotlines.delete(F):this.hiddenPlotlines.add(F),this.refresh()})})}
'@; New = @'
O.addItem(F=>{F.setTitle("全部显示").setIcon("eye").onClick(()=>{this.shownPlotlines=new Set(L),this.refresh()})}),O.addItem(F=>{F.setTitle("全部不选").setIcon("eye-off").onClick(()=>{this.shownPlotlines.clear(),this.refresh()})}),O.addSeparator();for(let F of L){let D=!this.shownPlotlines.has(F);O.addItem(N=>{N.setTitle(`${D?"   ":"\u2713 "}${this.formatPlotlineName(F)}`).onClick(()=>{D?this.shownPlotlines.add(F):this.shownPlotlines.delete(F),this.refresh()})})}
'@ },
    @{ Name = '筛选器·轨道图渲染'; Old = @'
let C=w.filter(T=>!this.hiddenPlotlines.has(T));this.renderSubwayMap(v,E,y,C)}
'@; New = @'
let C=w.filter(T=>this.shownPlotlines.has(T));C.length===0?v.createDiv({cls:"story-line-empty",text:"还没选故事线：点上方筛选按钮，勾选要看的线。"}):this.renderSubwayMap(v,E,y,C)}
'@ }
)

# 先逐项检查，全部通过才写入
$todo = @()
foreach ($p in $patches) {
    $oldCount = Count-Text $content $p.Old
    $newCount = Count-Text $content $p.New
    if ($oldCount -eq 0 -and $newCount -ge 1) {
        Write-Host "[提示] 已打过：$($p.Name)" -ForegroundColor DarkGray
    } elseif ($oldCount -eq 1 -and $newCount -eq 0) {
        $todo += $p
    } else {
        Write-Host "[错误] $($p.Name)：原文出现 $oldCount 次、补丁文出现 $newCount 次。可能插件结构已变（v$version），请人工检查后处理，main.js 未改动。" -ForegroundColor Red
        exit 1
    }
}

if ($todo.Count -eq 0) {
    Write-Host "[提示] 补丁都已存在（v$version），无需重复打。若问题仍存在，请先重载插件。" -ForegroundColor Green
    exit 0
}

# 备份（带版本号，避免覆盖旧备份）
$bak = Join-Path $pluginDir "main.js.bak-$version"
if (-not (Test-Path -LiteralPath $bak)) {
    Copy-Item -LiteralPath $mainJs -Destination $bak
    Write-Host "[备份] $bak" -ForegroundColor Cyan
} else {
    Write-Host "[备份] 已存在，跳过: $bak" -ForegroundColor DarkGray
}

$newContent = $content
foreach ($p in $todo) { $newContent = $newContent.Replace($p.Old, $p.New) }
[System.IO.File]::WriteAllText($mainJs, $newContent, $utf8NoBom)

# 验证
$check = [System.IO.File]::ReadAllText($mainJs, $utf8NoBom)
$failed = $false
foreach ($p in $todo) {
    if ((Count-Text $check $p.Old) -eq 0 -and (Count-Text $check $p.New) -ge 1) {
        Write-Host "[成功] $($p.Name)" -ForegroundColor Green
    } else {
        Write-Host "[错误] 验证未通过：$($p.Name)。请从备份恢复 main.js。" -ForegroundColor Red
        $failed = $true
    }
}
if ($failed) { exit 1 }
Write-Host "下一步：在 Obsidian 里 设置 → 社区插件 → 禁用再启用 StoryLine（或重启 Obsidian）。" -ForegroundColor Yellow
