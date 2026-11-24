# 완료작업정리.ps1
# 끝난 작업 폴더에서 최종본/썸네일/메모만 남기고 나머지를 '정리대기' 폴더로 옮깁니다.
# 아무것도 지우지 않습니다. 옮겨진 파일은 직접 확인 후 외장하드로 옮기거나 삭제하세요.
#
# 사용법 (PowerShell):
#   미리보기:  .\완료작업정리.ps1 -Project "D:\회사\01_숏폼편집\채널A\2026-11-24_영상제목"
#   실제실행:  .\완료작업정리.ps1 -Project "D:\회사\...\2026-11-24_영상제목" -Run
#
# 실행이 막히면 먼저 한 번:  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

param(
    [Parameter(Mandatory = $true)][string]$Project,
    [string]$Holding = "",
    [switch]$Run
)

$keepWords = @('최종', 'final', '썸네일', 'thumb', 'thumbnail', '메모', 'memo')
$keepExt   = @('.txt', '.md', '.docx', '.hwp', '.hwpx', '.pdf')

if (-not (Test-Path -LiteralPath $Project -PathType Container)) {
    Write-Host "폴더가 없습니다: $Project" -ForegroundColor Red
    exit 1
}
$Project = (Resolve-Path -LiteralPath $Project).Path.TrimEnd('\')
$name = Split-Path $Project -Leaf
if ($Holding -eq "") {
    $Holding = Join-Path (Split-Path $Project -Parent) "정리대기"
}
$dest = Join-Path $Holding $name

function Test-Keep($file) {
    $rel = $file.FullName.Substring($Project.Length).ToLower()
    foreach ($w in $keepWords) { if ($rel.Contains($w.ToLower())) { return $true } }
    if ($keepExt -contains $file.Extension.ToLower()) { return $true }
    return $false
}

$files = Get-ChildItem -LiteralPath $Project -Recurse -File -Force
$keep = @(); $move = @()
foreach ($f in $files) { if (Test-Keep $f) { $keep += $f } else { $move += $f } }

$moveBytes = ($move | Measure-Object Length -Sum).Sum
if (-not $moveBytes) { $moveBytes = 0 }
$gb = [math]::Round($moveBytes / 1GB, 2)

Write-Host ""
Write-Host "== 남길 파일: $($keep.Count)개 ==" -ForegroundColor Green
$keep | ForEach-Object { Write-Host "  $($_.FullName.Substring($Project.Length))" }
Write-Host ""
Write-Host "== 정리대기로 옮길 파일: $($move.Count)개 (약 $gb GB) ==" -ForegroundColor Yellow
$move | ForEach-Object { Write-Host "  $($_.FullName.Substring($Project.Length))" }
Write-Host ""

if ($keep.Count -eq 0) {
    Write-Host "남길 파일(최종/썸네일/메모)이 하나도 없습니다. 폴더 정리를 먼저 확인하세요. 중단합니다." -ForegroundColor Red
    exit 1
}

if (-not $Run) {
    Write-Host "미리보기만 했습니다. 실제로 옮기려면 끝에 -Run 을 붙여 다시 실행하세요." -ForegroundColor Cyan
    exit 0
}

foreach ($f in $move) {
    $rel = $f.FullName.Substring($Project.Length).TrimStart('\')
    $target = Join-Path $dest $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
    Move-Item -LiteralPath $f.FullName -Destination $target
}
# 비어버린 하위 폴더 제거
Get-ChildItem -LiteralPath $Project -Recurse -Directory -Force |
    Sort-Object { $_.FullName.Length } -Descending |
    Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } |
    Remove-Item -Force

Write-Host "완료: $($move.Count)개 파일을 $dest 로 옮겼습니다." -ForegroundColor Green
