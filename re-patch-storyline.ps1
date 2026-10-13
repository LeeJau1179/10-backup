# re-patch-storyline.ps1
# 用途：StoryLine 插件每次被 Obsidian 更新后，会回滚看板虚拟滚动补丁（threshold:40 → threshold:1e9），
#       导致 board 里超过 40 张卡片的 Act 列拖拽时跳到底部。跑本脚本可一键重新打补丁。
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

$old = "threshold:40"
$new = "threshold:1e9"
$oldCount = ([regex]::Matches($content, [regex]::Escape($old))).Count
$newCount = ([regex]::Matches($content, [regex]::Escape($new))).Count

if ($oldCount -eq 0 -and $newCount -ge 1) {
    Write-Host "[提示] 补丁已存在（v$version），无需重复打。若拖拽问题仍存在，请先重载插件。" -ForegroundColor Green
    exit 0
}

if ($oldCount -ne 1) {
    Write-Host "[错误] 预期 threshold:40 恰好出现 1 次，实际 $oldCount 次。可能插件结构已变，请人工检查后处理。" -ForegroundColor Red
    exit 1
}

# 备份（带版本号，避免覆盖旧备份）
$bak = Join-Path $pluginDir "main.js.bak-$version"
if (-not (Test-Path -LiteralPath $bak)) {
    Copy-Item -LiteralPath $mainJs -Destination $bak
    Write-Host "[备份] $bak" -ForegroundColor Cyan
} else {
    Write-Host "[备份] 已存在，跳过: $bak" -ForegroundColor DarkGray
}

$newContent = $content.Replace($old, $new)
[System.IO.File]::WriteAllText($mainJs, $newContent, $utf8NoBom)

# 验证
$check = [System.IO.File]::ReadAllText($mainJs, $utf8NoBom)
$leftOld = ([regex]::Matches($check, [regex]::Escape($old))).Count
$leftNew = ([regex]::Matches($check, [regex]::Escape($new))).Count
if ($leftOld -eq 0 -and $leftNew -ge 1) {
    Write-Host "[成功] 补丁已打（v$version）：threshold:40 → threshold:1e9" -ForegroundColor Green
    Write-Host "下一步：在 Obsidian 里 设置 → 社区插件 → 禁用再启用 StoryLine（或重启 Obsidian）。" -ForegroundColor Yellow
} else {
    Write-Host "[错误] 验证未通过：threshold:40 剩余 $leftOld，threshold:1e9 现有 $leftNew。请从备份恢复 main.js。" -ForegroundColor Red
    exit 1
}
