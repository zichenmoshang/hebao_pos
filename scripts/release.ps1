# 发版打标脚本：以 pubspec.yaml 的 version 为唯一版本源，自动创建并推送
# 带 v 前缀的 git tag（如 pubspec 为 1.2.0+3，则打 tag v1.2.0）。
#
# 用法：
#   pwsh ./scripts/release.ps1            # 创建并推送 tag
#   pwsh ./scripts/release.ps1 -Local     # 只在本地创建，不推送
#   pwsh ./scripts/release.ps1 -Force     # 已存在同名 tag 时，删除后重建（谨慎）
#
# 前置：请先把 pubspec.yaml 的 version 改为目标版本，并提交该改动。
param(
    [switch]$Local,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspec = Join-Path $repoRoot 'pubspec.yaml'

if (-not (Test-Path $pubspec)) {
    Write-Error "找不到 pubspec.yaml：$pubspec"
}

# 从 pubspec.yaml 解析 version: X.Y.Z+build（取 + 之前的主版本号）
$line = Select-String -Path $pubspec -Pattern '^\s*version:\s*(.+)$' | Select-Object -First 1
if (-not $line) {
    Write-Error 'pubspec.yaml 中未找到 version 字段'
}
$rawVersion = $line.Matches[0].Groups[1].Value.Trim()
$version = ($rawVersion -split '\+')[0].Trim()

if ($version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "版本号格式应为 X.Y.Z，当前解析为：$version"
}

$tag = "v$version"
Write-Host "pubspec 版本：$version  ->  git tag：$tag" -ForegroundColor Cyan

# 工作区必须干净，防止把未提交内容误当发布点
$dirty = git -C $repoRoot status --porcelain
if ($dirty) {
    Write-Error '工作区有未提交改动，请先提交或暂存后再发版。'
}

# 校验本地/远程是否已存在同名 tag
$localExists = git -C $repoRoot tag --list $tag
$remoteExists = git -C $repoRoot ls-remote --tags origin "refs/tags/$tag"

if ($localExists -or $remoteExists) {
    if (-not $Force) {
        Write-Error "tag $tag 已存在。确认要重建请加 -Force（会删除旧 tag）。"
    }
    Write-Warning "删除已存在的 tag：$tag"
    if ($localExists) { git -C $repoRoot tag -d $tag | Out-Null }
    if ($remoteExists) { git -C $repoRoot push origin ":refs/tags/$tag" | Out-Null }
}

# 在当前提交上创建带注释的 tag
git -C $repoRoot tag -a $tag -m "release $tag"
Write-Host "已在本地创建 tag：$tag" -ForegroundColor Green

if ($Local) {
    Write-Host '-Local 模式：未推送。需要推送时执行 git push origin ' -NoNewline
    Write-Host $tag
    exit 0
}

git -C $repoRoot push origin $tag
Write-Host "已推送 tag：$tag" -ForegroundColor Green
