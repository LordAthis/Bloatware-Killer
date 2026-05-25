# Bloatware-Killer
Mindenféle a rendszerbe települő kéretlen reklám és gyártói felesleges programok, applikációk, stb...


# RTS - Bloatware Killer (v0.1.17)

Az RTS (Repair-Toning-Settings) okoszisztema modularis resze. Gyarto- es szegmensspecifikus elore telepitett szoftverek (bloatware), kretlen reklamprogramok es felesleges hatter-szolgalltatasok automatizalt felkutatasa, naplozasa, kezelese es torlese Windows 7, 10 es 11 rendszereken.

##  A Projekt Struktura

```text
Bloatware-Killer/
│
├── Launcher.ps1          # Fő indító, jogosultság, tápellátás és verziókezelő
├── .gitignore            # Git szűrőfájl (LOG és ideiglenes fájlok kizárása)
├── README.md             # Szerviz szintű szakmai dokumentáció
│
├── Data/                 # Gyártói JSON adatbázisok (verziózva)
│   ├── Acer/
│   ├── Asus/
│   ├── Dell/
│   ├── Gigabyte/
│   ├── Hp/
│   ├── Lenovo/
│   └── Msi/
│
└── Scripts/              # PowerShell végrehajtó modulok (.NET alapokon)
    ├── Searching.ps1     # Kereső és kiértékelő modul
    ├── Killer.ps1        # Ellenőrzött, erőszakos törlő és IFEO blokkoló modul
    └── ReInstall.ps1     # Helyreállító modul (IFEO tiltások feloldása)
```

## ⚙️ Mukodesi Elv es Szerviz Logika

A szkriptcsomag szigoruan koveti az **"Ellenorzes -> Naplozas -> Vegrehajtas (csak ha szukseges) -> Naplozas"** lancolatot, minimalizalva a felesleges lemezmuveleteket es elkerulve az al-hibauzenetek generalasat a rendszerben.

1. **Jogosultsag es Frissites:** A `Launcher.ps1` .NET alapon UAC jogot emel, majd ellenorzi a futtatott szkript verziojat a `C:\Windows\Scripts\Bloatware-Killer` mappaban talalhato verzioval szemben. Ha ujabb verzio van a pendrive-on, automatikusan lefrissiti a helyi tarolot, es a tiszta környezetből indul ujra.
2. **Környezetvedelem:** Vizsgalja a hordozhato eszkozok tapellatasat (akkumulator csekkolas), es a futas idejere .NET API-n keresztul letiltja a Windows elalvasi/piheno modjat.
3. **Konzekvens Naplozas:** Minden egyes modul (`Searching`, `Killer`, `ReInstall`) az indulasakor **explicit modon beirja a sajat aktualis verzioszamat** a kozponti, napi logfajlba.
4. **Biztonsagos Kiertekeles:** A `Killer.ps1` a gyarto uninstaller folyamatainak inditasa utan .NET alapu `$Proc.WaitForExit()` hurokkal megvarja a fizikai torles veget, majd a summary kiirasa elott 3 masodperces kenyszeritett pihenot alkalmaz, igy a statisztika mindig a valos ideju registry-allapotot mutatja.

##  Szakmai Indoklas es Gyartoi Tapasztalatok (Reddit r/sysadmin alapjan)

A gyartok komoly penzeket kapnak az elore telepitett szoftverek elhelyezeseert. Szervizeles es karbantartas soran ezek eltavolitasa kritikus a rendszer stabilitasa es sebessege erdekeben.

### 💻 Laptop Szegmens

* **HP (Hewlett-Packard):**
  * *HP Support Assistant / HP Insights:* Folyamatosan futnak a hatterben, feleslegesen eszik a CPU-t es a memoriat, mikozben instabil driver-frissitesekkel kekhalalt okozhatnak.
  * *HP Connection Optimizer:* Hires a halozati telemetria kuldeserol es a rejtelyes Wi-Fi/Ethernet szakadasok generalasarol.
  * *HP JumpStart Bridge:* Az elso inditaskor megjeleno kretlen Dropbox/Adobe felugro reklamok fokezeloje.
  * *HP Documentation:* Offline PDF-ek es haszontalan utmutatok, amik csak a helyet foglaljak.
* **DELL:**
  * *Dell SupportAssist & Remediation:* Kozismerten sulyos hatter-terhelest generalnak. A Remediation modul gyakran okoz rendszerinditasi hurokhibakat (Boot Loop).
  * *SmartByte Network Service:* Az egyik legkarosabb szoftver. A halozati forgalom priorizalasanak alcazva kepes az internetkapcsolat savszelesseget akar 50-70%-kal is lefojtani.
* **LENOVO:**
  * *Lenovo Vantage Service:* A lakossagi verzio tele van akciokkal, reklamokkal es felhos targyhely-ajanlatokkal.
  * *System Interface Foundation (ImController):* Regebben tobb sulyos biztonsagi rest (privilege escalation) is felfedeztek benne a kutatok, felesleges hatter-bejlentkezo szoftver.
* **ACER:**
  * *Acer Care Center:* Tisztitonak alcazott bloatware, ami folyamatosan monitorozza a hattertarat, felesleges i/o muveleteket es lassulast generalva.

### 🖥️ Asztali (PC) es Alaplapi Szegmens

Az egyedi epitesu vagy markas asztali szamitogepeknel (MSI, Gigabyte, ASUS alaplapok) talalhatok a legagresszivebb karterto szoftvercsomagok. Ezeket a rendszergazdak az elso helyen torlik, mert instabilitast, felesleges CPU-tuskeget es kekhalalt okoznak.

* **MSI Desktop Szegmens:**
  * *MSI Center:* Sulyos hatterbeli telemetria, rendkivul instabil RGB- es hardvervezerlo szoftver, ami feleslegesen fut az automatikus inditasban.
  * *MSI Driver Utility Installer:* Minden tiszta Windows telepites es inditas utan eroszakosan felugro ablak, ami megprobalja atvenni a Windows Update szerepet, felesleges vagy elavult szoftvereket eroltetve a felhasznalora. Az r/sysadmin es r/MSI_Gaming kozossegek egyontetű velemenye alapjan azonnal eltavolitando.
* **GIGABYTE Desktop Szegmens:**
  * *GIGABYTE Control Center (GCC) & APP Center:* A Gigabyte asztali alaplapjai a BIOS-bol (WPBT tablan keresztul) injektaljak be ezeket a programokat az operacios rendszerbe a felhasznalo tudta nelkul. Ezek sokszor hibas, elavult drivereket eroltetnek a gepre, sulyos CPU-terhelest es mikro-szaggatasokat okozva a jatekok vagy professzionalis munkak alatt.
* **ASUS Desktop Szegmens:**
  * *Armoury Crate:* Az egyik legrosszabbul optimalizalt hardverkezelo szoftver a piacon. Telepiteskor tobb tucat kulonallo, egymast fojgato hatterfolyamatra es szolgalltatasra torezedik szet, jelentosen megemelve a rendszer alapjarati fogyasztasat es keslelteteset (DPC Latency).

## 🛡️ IFEO Ujratelepites Elleni Vedelem

Mivel a Windows Update vagy a gyartoi BIOS-injekciok hajlamosak a szoftvereket a hatterben automatikusan visszatelepiteni, a szkript **IFEO (Image File Execution Options)** registry-alapu futasgatlast alkalmaz a kritikus elemekre. A programok `.exe` fajljaihoz tarsitott `Debugger` kulcsot atiranyitja egy azonnal kilepo folyamatra (`cmd.exe /c exit`), igy a bloatware-ek abban az esetben sem kepesek tobbe elindulni vagy hatterfolyamatot inditani, ha valami kesobb visszamasolna oket a lemezre.

