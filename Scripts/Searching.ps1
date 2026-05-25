<#
.SYNOPSIS
    Bloatware Killer - Kereső és kiértékelő modul
.VERSION
    0.1.1
#>


Write-Log "Kereso modul elinditva..."

$VendorFolder = ""
if ($ComputerVendor -like "*HP*" -or $ComputerVendor -like "*Hewlett-Packard*") { $VendorFolder = "Hp" }
elseif ($ComputerVendor -like "*Dell*") { $VendorFolder = "Dell" }
elseif ($ComputerVendor -like "*Lenovo*") { $VendorFolder = "Lenovo" }

if (-not $VendorFolder) {
    Write-Log "Nem tamogatott vagy ismeretlen gyarto: $ComputerVendor" "WARN"
    Exit
}

$JsonPath = [System.IO.Path]::Combine($TargetDir, "Data", $VendorFolder, "$($VendorFolder.ToLower())_bloatware.json")

if (-not [System.IO.File]::Exists($JsonPath)) {
    Write-Log "Nem talalhato adatbazis fajl ehhez a gyartohoz: $JsonPath" "ERROR"
    Exit
}

$BloatwareDatabase = Get-Content -Raw -Path $JsonPath | ConvertFrom-Json

$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$InstalledApps = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue | Select-Object DisplayName, DisplayVersion

$ToKill = @()
$AlreadyCleaned = @()

$PastLogs = @()
if ([System.IO.Directory]::Exists($LogDir)) {
    $PastLogs = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue | Get-Content -ErrorAction SilentlyContinue
}

foreach ($App in $BloatwareDatabase) {
    if ($OSVersion -ge $App.MinWinVersion) {
        $WasCleanedBefore = $PastLogs | Where-Object { $_ -like "*Sikeresen eltavolitva: $($App.Name)*" }
        $IsInstalled = $InstalledApps | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }

        if ($IsInstalled -and $App.Action -eq "Remove") {
            $ToKill += $App
        } elseif ($WasCleanedBefore -and -not $IsInstalled) {
            $AlreadyCleaned += $App
        }
    }
}

Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          BLOATWARE KILLER v0.1 - EREDMENYEK       " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Rendszer: Windows $OSVersion | Gyarto: $ComputerVendor"
Write-Host "--------------------------------------------------"

if ($ToKill.Count -gt 0) {
    Write-Host "Eltavolitasra javasolt szoftverek:" -ForegroundColor Yellow
    foreach ($Item in $ToKill) {
        # LightRed lecserelve Red-re a kompatibilitas miatt
        Write-Host " [-] $($Item.Name) (Magyarazat: $($Item.Comment))" -ForegroundColor Red
    }
    
    $Choice = Read-Host "`nSzeretned elinditani a takaritast? (I/N)"
    if ($Choice -eq "I" -or $Choice -eq "i") {
        Write-Log "Szervizes joovaahagyta a takaritast. Killer.ps1 meghivasa..."
        . [System.IO.Path]::Combine($TargetDir, "Scripts", "Killer.ps1")
    }
} else {
    Write-Host "Nem talaltam aktiv eltavolitando gyartoi bloatware-t ezen a gepen." -ForegroundColor Green
    
    if ($AlreadyCleaned.Count -gt 0) {
        Write-Host "`nKorabban mar torolve lettek errol a geprol:" -ForegroundColor Gray
        foreach ($Cleaned in $AlreadyCleaned) {
            Write-Host " [V] $($Cleaned.Name)" -ForegroundColor Gray
        }
        
        $Rechoice = Read-Host "`nMinden tiszta. Szeretnel valamit VISSZATELEPITENI / HELYREALLITANI? (I/N)"
        if ($Rechoice -eq "I" -or $Rechoice -eq "i") {
            Write-Log "Szervizes a helyreallitasi menut valasztotta. ReInstall.ps1 meghivasa..."
            . [System.IO.Path]::Combine($TargetDir, "Scripts", "ReInstall.ps1")
        }
    }
}
