# 从 GitHub 拉取 micromamba 最新版，刷新本地 bucket 里的 manifest
# 用法: pwsh -File ~\scoop\buckets\self\update-micromamba.ps1
#       然后: scoop update micromamba
$ErrorActionPreference = 'Stop'
$repo = 'mamba-org/micromamba-releases'
$manifestPath = Join-Path $PSScriptRoot 'bucket\micromamba.json'

# 取最新 tag：优先 GitHub API，被限流时退回 releases/latest 的跳转地址
try {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'scoop' }
    $ver = $rel.tag_name
} catch {
    Write-Host "GitHub API 不可用（$($_.Exception.Message.Split([Environment]::NewLine)[0])），改用跳转地址取版本"
    $final = curl.exe -sL -o NUL -w '%{url_effective}' "https://github.com/$repo/releases/latest"
    if ($final -notmatch '/tag/(.+)$') { throw "无法确定最新版本: $final" }
    $ver = $Matches[1]
}

$sha = (Invoke-WebRequest "https://github.com/$repo/releases/download/$ver/micromamba-win-64.sha256" -UseBasicParsing).Content.Trim()
if ($sha -notmatch '^[a-fA-F0-9]{64}$') { throw "拿到的 sha256 不合法: $sha" }

$json = Get-Content $manifestPath -Raw | ConvertFrom-Json
if ($json.version -eq $ver -and $json.architecture.'64bit'.hash -eq $sha) {
    Write-Host "已是最新: $ver"
    return
}

$json.version = $ver
$json.architecture.'64bit'.url = "https://github.com/$repo/releases/download/$ver/micromamba-win-64.exe#/micromamba.exe"
$json.architecture.'64bit'.hash = $sha
$json | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding utf8

git -C $PSScriptRoot diff --quiet
if ($LASTEXITCODE -ne 0) {
    git -C $PSScriptRoot -c user.name=ZhuanZ -c user.email=zhuanz@local commit -qam "micromamba $ver"
}

Write-Host "manifest 已更新到 $ver，接着执行: scoop update micromamba"
