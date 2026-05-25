# 
# Aktuális Fájl: Searching.ps1
# Bloatware Killer - Kereső és kiértékelő modul
# Gyártóspecifikus bloatware elemek automatizált keresése, naplózása, kezelése, és törlése.
# Verzió v0.1.9
#

Function Write-Log {
    Param([string]$Message, [string]$Type = "INFO")
    $LogLine = "[$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Type] $Message"
    Write-Host $LogLine
    [System.IO.File]::AppendAllText($LogFile, $LogLine + [System.Environment]::NewLine)
}

Write-Log "Searching modul v0.1.9 elinditva."

$VendorFolder = ""
if ($ComputerVendor -like "*HP*" -or $ComputerVendor -like "*Hewlett-Packard*") { $VendorFolder = "Hp" }
elseif ($ComputerVendor -like "*Dell*") { $VendorFolder = "Dell" }
elseif ($ComputerVendor -like "*Lenovo*") { $VendorFolder = "Lenovo" }

if (-not $VendorFolder) {
    Write-Log "Nem tamogatott gyarto: $ComputerVendor" "WARN"
    Exit
}

$JsonPath = [System.IO.Path]::Combine($TargetDir, "Data", $VendorFolder, "$($VendorFolder.ToLower())_bloatware.json")

if (-not [System.IO.File]::Exists($JsonPath)) {
    Write-Log "Adatbazis hiany: $JsonPath" "ERROR"
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
if ([System.IO.File]::Exists($LogFile)) {
    $PastLogs = Get-Content -Path $LogFile -ErrorAction SilentlyContinue
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
Write-Host "          BLOATWARE KILLER v0.1.9 - EREDMENYEK      " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Rendszer: Windows $OSVersion | Gyarto: $ComputerVendor"
Write-Host "--------------------------------------------------"

if ($ToKill.Count -gt 0) {
    Write-Host "Eltavolitasra javasolt szoftverek:" -ForegroundColor Yellow
    foreach ($Item in $ToKill) {
        Write-Host " [-] $($Item.Name) (Magyarazat: $($Item.Comment))" -ForegroundColor Red
        Write-Log "Kereses eredmenye - Eltavolitando: $($Item.Name)"
    }
    
    $Choice = Read-Host "`nSzeretned elinditani a takaritast? (I/N)"
    if ($Choice -eq "I" -or $Choice -eq "i") {
        Write-Log "Szervizes joovaahagyta a takaritast. Elokeszites a Killer.ps1 inditasara..."
        
        # --- IDEIGLENES VÁRAKOZTATÁS A KÉRÉSEDRE ---
        Write-Host "`n[TESZT] Nyomj meg egy gombot a Killer.ps1 modul betoltese elott..." -ForegroundColor Magentai
        [System.Console]::ReadKey($true) | Out-Null
        
        # JAVÍTVA: Előre kiértékelt string útvonal a dot-sourcing híváshoz, így nincs parancshiba!
        $KillerScriptPath = "$TargetDir\Scripts\Killer.ps1"
        . $KillerScriptPath
    } else {
        Write-Log "Szervizes elutasitotta a takaritast." "WARN"
    }
} else {
    Write-Host "Nem talaltam aktiv eltavolitando gyartoi bloatware-t." -ForegroundColor Green
    Write-Log "Nem talalhato aktiv bloatware a rendszerben."
    
    if ($AlreadyCleaned.Count -gt 0) {
        Write-Host "`nKorabban mar torolve lettek errol a geprol:" -ForegroundColor Gray
        foreach ($Cleaned in $AlreadyCleaned) {
            Write-Host " [V] $($Cleaned.Name)" -ForegroundColor Gray
        }
        
        $Rechoice = Read-Host "`nMinden tiszta. Szeretnel valamit VISSZATELEPITENI? (I/N)"
        if ($Rechoice -eq "I" -or $Rechoice -eq "i") {
            Write-Log "Szervizes a helyreallitast valasztotta. ReInstall.ps1 inditasa..."
            $ReinstallScriptPath = "$TargetDir\Scripts\ReInstall.ps1"
            . $ReinstallScriptPath
        }
    }
}
