#
# Bloatware Killer - Vegrehajto / Eltavolito modul (.NET alapon)
# Verzio 0.1
#

Write-Log "Killer modul elinditva. Takaritas megkezdodott..."

# AppX / UWP Alkalmazások törlése (pl. HP Smart)
foreach ($App in $ToKill) {
    if ($App.RegistryName -eq "HPSmart" -or $App.RegistryName -eq "HPJumpstart") {
        Write-Log "UWP Alkalmazas eltavolitasa: $($App.Name)"
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$($App.RegistryName)*" } | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$($App.RegistryName)*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
}

# Hagyományos Win32 szoftverek eltávolítása a Registry Uninstall kulcsok alapján
$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$InstalledItems = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue

foreach ($App in $ToKill) {
    # Biztonsági szolgáltatások leállítása törlés előtt (pl. HP Wolf Security)
    $ServiceKeywords = @("HP", "Wolf", "SureClick", "Analytics")
    foreach ($Keyword in $ServiceKeywords) {
        $Services = Get-Service | Where-Object { $_.DisplayName -like "*$Keyword*" -or $_.Name -like "*$Keyword*" }
        foreach ($Service in $Services) {
            if ($Service.Status -eq "Running") {
                Write-Log "Szolgaltatas leallitasa: $($Service.Name)"
                Stop-Service -Name $Service.Name -Force -ErrorAction SilentlyContinue
                Set-Service -Name $Service.Name -StartupType Disabled -ErrorAction SilentlyContinue
            }
        }
    }

    # Megkeressük a pontos UninstallString-et
    $Match = $InstalledItems | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }
    
    if ($Match) {
        foreach ($Item in $Match) {
            $Unstring = $Item.UninstallString
            if ($Unstring) {
                Write-Log "Szoftver eltavolitasa folyamatban: $($App.Name)"
                
                # MSI alapú csendes eltávolítás előkészítése
                if ($Unstring -like "msiexec*") {
                    $Args = $Unstring -replace "msiexec.exe", "" -replace "/I", "/X"
                    $Args += " /qn /norestart"
                    $Proc = [System.Diagnostics.Process]::Start("msiexec.exe", $Args.Trim())
                    $Proc.WaitForExit()
                } else {
                    # Ha EXE alapú uninstaller, megpróbáljuk a standard csendes kapcsolókat
                    # Levágjuk az idézőjeleket, ha vannak
                    $CleanUnstring = $Unstring -replace '"', ''
                    if ($CleanUnstring -like "*.exe*") {
                        $ExePath = $CleanUnstring.Substring(0, $CleanUnstring.IndexOf(".exe") + 4)
                        $Args = "/S /silent /verysilent /qn /norestart"
                        try {
                            $Proc = [System.Diagnostics.Process]::Start($ExePath, $Args)
                            $Proc.WaitForExit()
                        } catch {
                            Write-Log "EXE Uninstaller hiba, direktben futtatas..." "WARN"
                        }
                    }
                }
                Write-Log "Sikeresen eltavolitva: $($App.Name)"
            }
        }
    }

    # --- REGISTRY BLOKKOLÁS (IFEO TILTÁS) ---
    if ($App.RegistryBlock) {
        Write-Log "Registry tiltas alkalmazasa a kovetkezohoz: $($App.Name)"
        $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($App.RegistryName).exe"
        if (-not (Test-Path $IfeoPath)) {
            New-Item -Path $IfeoPath -Force | Out-Null
        }
        # Beállítjuk a debugger kulcsot egy nem létező fájlra, így a program soha többé nem tud elindulni
        Set-ItemProperty -Path $IfeoPath -Name "Debugger" -Value "cmd.exe /c exit" -Force
    }
}

# Makacs HP shortcut-ok és reklámmappák törlése a lemezről
$GarbagePaths = @(
    "C:\ProgramData\HP\TCO",
    "C:\Online Services",
    "C:\Users\Public\Desktop\TCO Certified.lnk"
)
foreach ($Path in $GarbagePaths) {
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue
        Write-Log "Szemet konyvtar/parancsikon torolve: $Path"
    }
}

Write-Host "`nA takaritas befejezodott! Ellenorizd a logfajlt a reszletekert." -ForegroundColor Green
