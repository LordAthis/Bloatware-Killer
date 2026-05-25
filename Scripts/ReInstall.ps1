#
# Bloatware Killer - Visszaallito / Helyreallito modul (.NET alapon)
# Verzió: 0.1
# A kommentek ekezetesek, a kiirt uzenetek ekezetmentesek.
#

Write-Log "ReInstall modul elinditva. Helyreallitas megkezdese..."
Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          BLOATWARE KILLER - HELYREALLITAS         " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$RestoredCount = 0

foreach ($App in $AlreadyCleaned) {
    if ($App.RegistryBlock) {
        $IfeoPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image Execution Options\$($App.RegistryName).exe"
        
        # .NET-alapú Registry kezelés a maximális stabilitásért
        $RegKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($IfeoPath, $true)
        
        if ($RegKey) {
            $Value = $RegKey.GetValue("Debugger")
            if ($Value) {
                Write-Log "Registry tiltas feloldasa a kovetkezohoz: $($App.Name)"
                Write-Host "[+] Tiltas feloldasa: $($App.Name)" -ForegroundColor Green
                
                try {
                    $RegKey.DeleteValue("Debugger")
                    $RestoredCount++
                } catch {
                    Write-Log "Hiba a registry ertek torlese kozben: $($App.Name)" "ERROR"
                }
            }
            $RegKey.Close()
        }
    }
}

Write-Host "--------------------------------------------------"
if ($RestoredCount -gt 0) {
    Write-Host "[VÉGZETT] A kivalasztott szoftverek tiltasa feloldva." -ForegroundColor Green
    Write-Host "Most mar ujratelepithetok es futtathatok a gyari programok." -ForegroundColor Green
} else {
    Write-Host "[INFO] Nem talaltam aktivalt registry tiltast a rendszerben." -ForegroundColor Yellow
}

Write-Log "Helyreallitasi folyamat lezarva. Varakozas a felhasznalora..."

# --- AZ ÁLTALAD JELZETT HIBA JAVÍTÁSA: A SCRIPT MEGÁLLÍTÁSA ---
Write-Host "`nNyomj meg egy gombot a kilepeshez..." -ForegroundColor Windows
[System.Console]::ReadKey($true) | Out-Null
