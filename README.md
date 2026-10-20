# Game Fixer

Current version: **3.0.1** — New face

[![CI](https://github.com/FamiliaCuba/gamefixer/actions/workflows/ci.yml/badge.svg)](https://github.com/FamiliaCuba/gamefixer/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/FamiliaCuba/gamefixer)](https://github.com/FamiliaCuba/gamefixer/releases)

Game Fixer is a Windows desktop tool by FamiliaCuba for checking, repairing, and measuring a gaming PC. Version 3.0.1 is a standalone window. There is nothing else to install and no loose folders to keep: you open one `GameFixer.exe`.

Test mode is on by default. In that mode the app explains what it would do and does not change the PC. Live mode applies the change and asks for confirmation before it touches the system.

Download the executable from [Releases](https://github.com/FamiliaCuba/gamefixer/releases).

Discord: [FamiliaCuba](https://discord.gg/WecrFkBGGx)

## What it is for

A gaming PC collects temporary files, startup programs, slow DNS settings, old drivers, and one-off tweaks. Game Fixer puts those jobs in one clear window:

- It diagnoses the PC without changing anything.
- It cleans and repairs Windows after you switch to Live mode.
- It finds installed games and offers a tweak for each one it knows.
- It measures CPU, memory, disk, and network, then compares the run with the previous one.
- It builds a support report and a code you can copy.

The interface is Spanish when the Windows language starts with "es". Every other language gets English. Text that comes from Windows itself, such as a Windows notice, is shown as a notice. It is not reported as a Game Fixer failure.

## Requirements

- Windows 10 or 11, 64-bit.
- Administrator rights. Windows asks once when the executable opens, because several repairs read the system registry and the performance counters.
- To build the window from source: PowerShell 5.1 and .NET Framework 4, which already ship with Windows.

Python, Node, and a database are not required.

## How the window works

Opening `GameFixer.exe` shows the app. The menu is on the left. Cards for the selected section are on the right. Live meters and the version line sit along the bottom.

1. Read the card. The text says whether that action changes the PC.
2. Click the card. The **What's happening** panel shows progress from 0 to 100 and the result.
3. If the action changes the system and you are in Live mode, a confirmation names that action.
4. A successful run is titled **Done**. A Windows notice is not shown as a Game Fixer failure.

The status panel does not cover the cards. Long output opens with **Show technical detail**.

### Test mode and Live mode

The side panel has two states:

| State | What it does |
| --- | --- |
| Test | Simulates the action. The PC does not change. |
| Live | Applies the action after you confirm. |

The button at the bottom of that section says **Switch to live** or **Back to test**.

### Meters

The bottom band reads the PC once a second:

| Meter | What it shows |
| --- | --- |
| CPU | Processor use, as a percentage. |
| RAM | Memory in use and the total, in GB. |
| GPU | 3D activity of the busiest engine, plus VRAM when the sensor answers. |
| Disk | Megabytes per second. The bar reaches full around 200 MB/s. |
| Network | Download in Mb/s, with upload underneath. The bar reaches full around 100 Mb/s. |

A little activity does not turn the bar red. Red means the load is already high.

## Sections

### Home

| Card | Effect |
| --- | --- |
| Full diagnostic | System, CPU, GPU, disks, and events. Changes nothing. |
| Windows health | Services, storage, and problem signs. Changes nothing. |
| Quick diagnostic | Hardware, drivers, and game settings. Changes nothing. |
| Auto-Fix | Restore point, benchmark, cleanup, tweaks, and a report. Asks first. |
| Gamer optimization | Power plan, Game Mode, and network. Test mode is respected. |

Home also lists recent actions saved on the PC: time, name, whether it ran in test or live, and whether it succeeded.

When a diagnostic finds games, a chip opens that game's tweak if the catalog has one. Otherwise the chip only reports the name.

### Repair

| Card | Effect |
| --- | --- |
| Startup programs | Lists what starts with Windows. Click one to remove it. Test mode only simulates the removal. |
| Clean temporary files | Every cleanup category at once. |
| Empty recycle bin | Empties the recycle bin. |
| Clean WinSxS | Removes old Windows components. |
| SFC | Checks the Windows files. |
| DISM | Repairs the Windows image. |
| SFC and DISM | Both repairs, one after the other. |
| CHKDSK | Checks `C:` read-only. It does not schedule a restart. |
| Stutter | Usual settings against stuttering. |
| Audio | Restarts the audio stack. |
| Input lag | Input-latency settings. |
| Enable HAGS | Turns on hardware-accelerated GPU scheduling. |
| Turn off mouse acceleration | Turns off pointer acceleration. |
| Restore point | Creates a point before other changes. |
| View backups | Lists saved registry backups. |
| Restore last backup | Returns to the last registry backup. |

Actions that change the system respect Test mode.

### Games

| Card | Effect |
| --- | --- |
| Detect games | Steam, Epic, Riot, Xbox, EA, Battle.net, Ubisoft, and GOG. |
| GPU information | Name, driver, and memory. |
| Driver version | Compares the installed driver and can open the vendor's download page. It does not download or install the driver. |
| Clear shader cache | Clears the GPU shader cache. |
| GPU maximum performance | The graphics-card power plan. |
| Gamer, Streaming, Office, Power saver | Applies that profile. |
| View plugins | Lists the `.psm1` files in the `plugins` folder. |

A tweak is ready for CS2, VALORANT, Rainbow Six, Apex, Fortnite, Warzone, Battlefield, Delta Force, The Finals, Marvel Rivals, League of Legends, Dota 2, Rust, DayZ, ARK, GTA V, Red Dead 2, Cyberpunk 2077, Elden Ring, Minecraft, Tarkov, and PUBG.

### Network

| Card | Effect |
| --- | --- |
| Latency | Ping to the network module targets. |
| Connections | Shows active connections. |
| Cloudflare DNS | Sets DNS to 1.1.1.1. |
| Google DNS | Sets DNS to 8.8.8.8. |
| Reset DNS | Returns to automatic DNS. |
| Restart adapter | Flushes the DNS cache and restarts the adapter that has internet. It does not reset the whole network stack. |

### Benchmark

Each test can run alone, or all of them together:

- CPU benchmark
- RAM benchmark
- Disk benchmark
- Network benchmark
- Full benchmark, with CPU, RAM, disk, and network

The first run of a test only stores the result. From the second run on, the window compares it with the previous one and says whether it went up, down, or stayed the same. There is no comparison on the first run.

The network test measures ping and download. It does not use the Ookla client.

### Support

Support asks for an optional note about what is failing and builds a PC report. When it finishes, it shows a large code and a copy button. That code is what you send on Discord so the report can be found.

The report does not collect passwords or browser secrets. The text is stripped of the user name, the PC name, MAC addresses, disk serial numbers, and IP addresses.

## What it does not do

- It does not install drivers. The driver card opens the vendor's official page.
- It does not format disks, and it does not schedule `chkdsk` for the next reboot.
- It does not change the PC while Test mode is on.
- The executable is not part of the source tree. `dist\` stays out of the repository. The `.exe` is published on Releases.

## Build the window

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pack-exe.ps1
```

The output is `dist\GameFixer.exe`. Close the executable if it is already open. The compiler cannot write the file while it is in use.

The window source is `tools\GameFixerUi.cs`. Packaging embeds `GameFixer.ps1`, `version.txt`, the license, `modules\`, and `plugins\` inside the executable. It does not embed `config.json`.

## Console

`GameFixer.ps1` is still the engine. The window runs it underneath. You can also start it by hand:

```powershell
.\GameFixer.ps1
.\GameFixer.ps1 -Live
```

Without `-Live` it stays in test mode. With `-Live` it applies the changes.

## Tests

```powershell
.\tests\Run-Tests.ps1
```

Every push to `main` runs the suite on GitHub Actions.

## Repository privacy

`config.json` is local and is not versioned. Session logs, reports, benchmarks, and the `dist` folder stay out of Git as well.

## License

MIT. Copyright 2026 FamiliaCuba.
