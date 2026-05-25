<#
.SYNOPSIS
    Bloatware Killer - Kereső és kiértékelő modul
.VERSION
    0.1
#>

Write-Log "Kereso modul elinditva..."

# Gyártó standardizálása a JSON-mappákhoz
$VendorFolder = ""
if ($ComputerVendor -like "*HP*" -or $ComputerVendor -like "*Hewlett-Packard*") { $VendorFolder = "Hp" }
elseif ($ComputerVendor -like "*Dell*") { $VendorFolder = "Dell" }
elseif ($ComputerVendor -like "*Lenovo*") { $VendorFolder = "Lenovo" }

if (-not $VendorFolder) {
    Write-Log "Nem tamogatott vagy ismeretlen gyartó: $ComputerVendor" "WARN"
    Exit
}

$JsonPath = "$TargetDir\Data\$VendorFolder\$($VendorFolder.ToLower())_bloatware.json"

if (-not (Test-Path $JsonPath)) {
    Write-Log "Nem található adatbázis fájl ehhez a gyártóhoz: $JsonPath" "ERROR"
    Exit
}

$BloatwareDatabase = Get-Content -Raw -Path $JsonPath | ConvertFrom-Json
$InstalledApps = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion

$ToKill = @()
$AlreadyCleaned = @()

# Korábbi logfájlok átfésülése, hogy lássuk, töröltük-e már valaha
$PastLogs = Get-ChildItem -Path $LogDir -Filter "*.log" | Get-Content

foreach ($App in $BloatwareDatabase) {
    # Ellenőrizzük, hogy az adott Windows verzióra vonatkozik-e
    if ($OSVersion -ge $App.MinWinVersion) {
        
        # Megnézzük a múltbéli logokban
        $WasCleanedBefore = $PastLogs | Where-Object { $_ -like "*Sikeresen eltavolitva: $($App.Name)*" }
        
        # Megnézzük a jelenleg telepítettek között
        $IsInstalled = $InstalledApps | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }

        if ($IsInstalled -and $App.Action -eq "Remove") {
            $ToKill += $App
        } elseif ($WasCleanedBefore -and -not $IsInstalled) {
            $AlreadyCleaned += $App
        }
    }
}

# --- EREDMÉNYEK KIÍRÁSA ÉS INTERAKCIÓ ---
Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          BLOATWARE KILLER v0.1 - EREDMENYEK       " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Rendszer: Windows $OSVersion | Gyarto: $ComputerVendor"
Write-Host "--------------------------------------------------"

if ($ToKill.Count -gt 0) {
    Write-Host "Eltavolitasra javasolt szoftverek:" -ForegroundColor Yellow
    foreach ($Item in $ToKill) {
        Write-Host " [-] $($Item.Name) (Magyarazat: $($Item.Comment))" -ForegroundColor LightRed
    }
    
    $Choice = Read-Host "`nSzeretned elinditani a takaritast? (I/N)"
    if ($Choice -eq "I" -or $Choice -eq "i") {
        Write-Log "Szervizes jovahagyta a takaritast. Killer.ps1 meghivasa..."
        . "$TargetDir\Scripts\Killer.ps1"
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
            . "$TargetDir\Scripts\ReInstall.ps1"
        }
    }
}
