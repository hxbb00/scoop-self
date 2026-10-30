# Refresh the local bucket manifest with the latest micromamba release.
# Usage: pwsh -File ~\scoop\buckets\self\update-micromamba.ps1
#        then: scoop update micromamba
$ErrorActionPreference = 'Stop'
$repo = 'mamba-org/micromamba-releases'
$manifestPath = Join-Path $PSScriptRoot 'bucket\micromamba.json'

# Latest tag: GitHub API first, fall back to the releases/latest redirect when rate limited.
try {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'scoop' }
    $ver = $rel.tag_name
} catch {
    Write-Host "GitHub API unavailable (rate limit?), using releases/latest redirect instead."
    $final = curl.exe -sL -o NUL -w '%{url_effective}' "https://github.com/$repo/releases/latest"
    if ($final -notmatch '/tag/(.+)$') { throw "Cannot resolve latest version from: $final" }
    $ver = $Matches[1]
}

$sha = (curl.exe -sL "https://github.com/$repo/releases/download/$ver/micromamba-win-64.sha256") -join ''
$sha = $sha.Trim()
if ($sha -notmatch '^[a-fA-F0-9]{64}$') { throw "Invalid sha256: $sha" }

$json = Get-Content $manifestPath -Raw | ConvertFrom-Json
if ($json.version -eq $ver -and $json.architecture.'64bit'.hash -eq $sha) {
    Write-Host "Already up to date: $ver"
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

Write-Host "Manifest updated to $ver. Now run: scoop update micromamba"
