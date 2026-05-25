# 
# Aktuális Fájl: ReInstall.ps1
# Bloatware Killer - Visszaállító / Helyreállító modul
# Gyártóspecifikus bloatware elemek automatizált keresése, naplózása, kezelése, és törlése.
# Verzió v0.1.16
#

Function Write-Log {
    Param([string]$Message, [string]$Type = "INFO")
    $LogLine = "[$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Type] $Message"
    Write-Host $LogLine
    [System.IO.File]::AppendAllText($LogFile, $LogLine + [System.Environment]::NewLine)
}

# Explicit módon naplózzuk a fájl saját verzióját a konzekvencia miatt
Write-Log "ReInstall modul v0.1.16 elinditva. Helyreallitas megkezdese..."
Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          BLOATWARE KILLER - HELYREALLITAS         " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$RestoredCount = 0

foreach ($App in $AlreadyCleaned) {
    if ($App.RegistryBlock) {
        $IfeoPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($App.RegistryName).exe"
        
        # ELLENŐRZÉS: Létezik-e az adott IFEO registry kulcs?
        $RegKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($IfeoPath, $true)
        
        if ($RegKey) {
            $Value = $RegKey.GetValue("Debugger")
            if ($Value) {
                Write-Log "ReInstall: Registry tiltas detektalva ($($App.Name)). Feloldas..."
                Write-Host "[+] Tiltas feloldasa: $($App.Name)" -ForegroundColor Green
                
                try {
                    $RegKey.DeleteValue("Debugger")
                    Write-Log "ReInstall: Tiltas sikeresen feloldva: $($App.Name)"
                    $RestoredCount++
                } catch {
                    Write-Log "ReInstall: HIBA a registry ertek torlese kozben: $($App.Name)" "ERROR"
                }
            }
            $RegKey.Close()
        }
    }
}

Write-Host "--------------------------------------------------"
if ($RestoredCount -gt 0) {
    Write-Host "[VEGZETT] A kivalasztott szoftverek tiltasa feloldva." -ForegroundColor Green
    Write-Log "Helyreallitas befejezve. Helyreallitott elemek: $RestoredCount"
} else {
    Write-Host "[INFO] Nem talaltam aktivalt registry tiltast a rendszerben." -ForegroundColor Yellow
    Write-Log "ReInstall: Nem volt mit feloldani."
}

Write-Host "`nNyomj meg egy gombot a kilepeshez..." -ForegroundColor Cyan
[System.Console]::ReadKey($true) | Out-Null
