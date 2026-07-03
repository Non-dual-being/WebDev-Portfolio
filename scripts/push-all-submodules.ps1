param(
    [string]$CommitMessage = "chore: update project files",
    [string]$RootCommitMessage = "chore: update portfolio submodule references",
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptPath

Set-Location $root

Write-Host ""
Write-Host "========================================"
Write-Host "WebDev-Portfolio submodule push script"
Write-Host "Root: $root"
Write-Host "========================================"

if (-not (Test-Path ".gitmodules")) {
    throw "Geen .gitmodules gevonden. Draai dit script vanuit of binnen de WebDev-Portfolio repo."
}

# Lees alleen echte 'path =' regels uit .gitmodules.
# Dit is betrouwbaarder dan git config --get-regexp bij submodule-namen met spaties.
$submodulePaths = Get-Content ".gitmodules" |
    Where-Object { $_ -match "^\s*path\s*=\s*(.+)\s*$" } |
    ForEach-Object { $Matches[1].Trim() }

if (-not $submodulePaths -or $submodulePaths.Count -eq 0) {
    throw "Geen submodule paths gevonden in .gitmodules."
}

Write-Host ""
Write-Host "Gevonden submodules:"
$submodulePaths | ForEach-Object { Write-Host "- $_" }

foreach ($path in $submodulePaths) {
    $fullPath = Join-Path $root $path

    Write-Host ""
    Write-Host "========================================"
    Write-Host "Submodule: $path"
    Write-Host "========================================"

    if (-not (Test-Path $fullPath)) {
        Write-Host "WAARSCHUWING: Pad bestaat niet, overslaan: $fullPath"
        continue
    }

    Push-Location $fullPath

    try {
        $branch = (git branch --show-current).Trim()

        if ([string]::IsNullOrWhiteSpace($branch)) {
            Write-Host "WAARSCHUWING: Deze submodule staat detached. Overslaan: $path"
            continue
        }

        $remote = git remote get-url origin 2>$null

        if ([string]::IsNullOrWhiteSpace($remote)) {
            Write-Host "WAARSCHUWING: Geen origin remote gevonden. Overslaan: $path"
            continue
        }

        Write-Host "Branch: $branch"
        Write-Host "Remote: $remote"
        Write-Host ""

        git status -sb

        # Commit alle tracked, modified, deleted en untracked bestanden in deze submodule.
        git add -A

        $changes = git status --porcelain

        if ($changes) {
            Write-Host ""
            Write-Host "Wijzigingen gevonden. Committen..."
            git commit -m $CommitMessage
        } else {
            Write-Host "Geen lokale wijzigingen om te committen."
        }

        if (-not $NoPush) {
            Write-Host ""
            Write-Host "Pushen naar origin/$branch..."
            git push -u origin $branch
        } else {
            Write-Host "NoPush actief: submodule niet gepusht."
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "Hoofdrepo bijwerken"
Write-Host "========================================"

Set-Location $root

# Stage gewijzigde submodule pointers en .gitmodules.
git add .gitmodules

foreach ($path in $submodulePaths) {
    git add -- "$path"
}

git status

$rootChanges = git status --porcelain

if ($rootChanges) {
    Write-Host ""
    Write-Host "Hoofdrepo heeft wijzigingen. Committen..."
    git commit -m $RootCommitMessage

    if (-not $NoPush) {
        Write-Host ""
        Write-Host "Hoofdrepo pushen naar origin/main..."
        git push origin main
    } else {
        Write-Host "NoPush actief: hoofdrepo niet gepusht."
    }
} else {
    Write-Host "Geen wijzigingen in de hoofdrepo om te committen."
}

Write-Host ""
Write-Host "========================================"
Write-Host "Eindcontrole"
Write-Host "========================================"

git status
git submodule status --recursive

Write-Host ""
Write-Host "Klaar."
