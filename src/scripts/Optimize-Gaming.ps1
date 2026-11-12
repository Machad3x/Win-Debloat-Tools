Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\Get-HardwareInfo.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\Open-File.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\Title-Templates.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\debloat-helper\Remove-ItemPropertyVerified.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\debloat-helper\Set-ItemPropertyVerified.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\utils\Individual-Tweaks.psm1"

# Adapted from: https://github.com/davidajudua/LowLatencyToolkit
# Adapted from: https://github.com/theantipopau/windows11nontouchgamingoptimizer
# Adapted from: https://exmtweaks.com/en-us/blog/10-more-hidden-tweak

function Optimize-Gaming() {
    [CmdletBinding()]
    param(
        [Switch] $Revert,
        [Int]    $Zero = 0,
        [Int]    $One = 1,
        [Array]  $EnableStatus = @(
            @{ Symbol = "-"; Status = "Disabling"; }
            @{ Symbol = "+"; Status = "Enabling"; }
        )
    )
    $TweakType = "Gaming"

    If (($Revert)) {
        Write-Status -Types "*", $TweakType -Status "Reverting the tweaks is set to '$Revert'." -Warning
        $Zero = 1
        $One = 0
        $EnableStatus = @(
            @{ Symbol = "*"; Status = "Restoring"; }
            @{ Symbol = "*"; Status = "Re-Disabling"; }
        )
    }

    # Initialize all Path variables used to Registry Tweaks
    $PathToCUGameConfigStore = "HKCU:\System\GameConfigStore"
    $PathToCUGameDVR = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    $PathToCUGameBar = "HKCU:\SOFTWARE\Microsoft\GameBar"
    $PathToLMPoliciesGameDVR = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    $PathToLMDwm = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
    $PathToLMGraphicsDrivers = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $PathToLMGraphicsScheduler = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler"
    $PathToLMPriorityControl = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    $PathToGpuClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"

    Write-Title "Gaming Tweaks"

    Write-Section "Game Mode & Game DVR"
    If (!$Revert) {
        Disable-XboxGameBarDVRandMode
    } Else {
        Enable-XboxGameBarDVRandMode
    }

    Write-Status -Types "*", $TweakType -Status "Enabling Game Mode..."
    Set-ItemPropertyVerified -Path "$PathToCUGameBar" -Name "AllowAutoGameMode" -Type DWord -Value 1
    Set-ItemPropertyVerified -Path "$PathToCUGameBar" -Name "AutoGameModeEnabled" -Type DWord -Value 1

    Write-Status -Types "+", $TweakType -Status "Keeping fullscreen optimizations enabled for better performance..."

    Write-Status -Types $EnableStatus[0].Symbol, $TweakType -Status "$($EnableStatus[0].Status) Game DVR background recording..."
    If (!$Revert) {
        Set-ItemPropertyVerified -Path "$PathToCUGameDVR" -Name "AppCaptureEnabled" -Type DWord -Value 0
        If (!(Test-Path "$PathToLMPoliciesGameDVR")) { New-Item -Path "$PathToLMPoliciesGameDVR" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$PathToLMPoliciesGameDVR" -Name "AllowGameDVR" -Type DWord -Value 0
    } Else {
        Remove-ItemPropertyVerified -Path "$PathToCUGameDVR" -Name "AppCaptureEnabled"
        Remove-ItemPropertyVerified -Path "$PathToLMPoliciesGameDVR" -Name "AllowGameDVR"
    }

    Write-Section "CPU & Power Plan (Vendor-Aware)"
    $CpuName = (Get-CPU -NameOnly).Trim()
    Write-Status -Types "@", $TweakType -Status "Detected CPU: $CpuName" -Warning

    If ($CpuName -match 'Ryzen.*X3D') {
        Write-Status -Types "+", $TweakType -Status "Ryzen X3D detected: keeping Balanced power plan for core parking (AMD driver)." 
        powercfg -SetActive 381b4222-f694-41f0-9685-ff5bb260df2e
    } ElseIf ($CpuName -match 'Ryzen') {
        Write-Status -Types "+", $TweakType -Status "Ryzen detected: using High Performance plan; install AMD chipset driver for Ryzen High Performance plan." 
        powercfg -SetActive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    } ElseIf ($CpuName -match 'Intel') {
        Write-Status -Types "+", $TweakType -Status "Intel detected: using High Performance plan; let Thread Director handle hybrid cores (do not pin cores)." 
        powercfg -SetActive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    } Else {
        Write-Status -Types "+", $TweakType -Status "Using High Performance power plan..." 
        powercfg -SetActive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    }

    Write-Section "Foreground & Input Priority"
    Write-Status -Types "+", $TweakType -Status "Prioritizing foreground (game) processes..."
    If (!$Revert) {
        Set-ItemPropertyVerified -Path "$PathToLMPriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 38
    } Else {
        Set-ItemPropertyVerified -Path "$PathToLMPriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 2
    }

    Write-Status -Types "-", $TweakType -Status "Disabling mouse acceleration..."
    If (!$Revert) {
        Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Type String -Value "0"
        Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Type String -Value "0"
        Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Type String -Value "0"
    } Else {
        Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Type String -Value "1"
        Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Type String -Value "6"
        Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Type String -Value "10"
    }

    Write-Status -Types "+", $TweakType -Status "Increasing keyboard/mouse input queue size..."
    ForEach ($QueuePath in @("HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters", "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters")) {
        If (!(Test-Path "$QueuePath")) { New-Item -Path "$QueuePath" -Force | Out-Null }
        If (!$Revert) {
            If ($QueuePath -like "*kbdclass*") {
                Set-ItemPropertyVerified -Path "$QueuePath" -Name "KeyboardDataQueueSize" -Type DWord -Value 0x1000
            } Else {
                Set-ItemPropertyVerified -Path "$QueuePath" -Name "MouseDataQueueSize" -Type DWord -Value 0x1000
            }
        } Else {
            Remove-ItemPropertyVerified -Path "$QueuePath" -Name "KeyboardDataQueueSize"
            Remove-ItemPropertyVerified -Path "$QueuePath" -Name "MouseDataQueueSize"
        }
    }

    Write-Section "Display & Windowed Games"
    Write-Status -Types "+", $TweakType -Status "Enabling optimizations for windowed games (DirectX 10/11)..."
    If (!$Revert) {
        $DirectXPath = "HKCU:\\Software\\Microsoft\\DirectX\\UserGpuPreferences"
        $GraphicsSettingsPath = "HKCU:\\Software\\Microsoft\\DirectX\\GraphicsSettings"
        If (!(Test-Path "$DirectXPath")) { New-Item -Path "$DirectXPath" -Force | Out-Null }
        If (!(Test-Path "$GraphicsSettingsPath")) { New-Item -Path "$GraphicsSettingsPath" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$DirectXPath" -Name "DirectXUserGlobalSettings" -Type String -Value "SwapEffectUpgradeEnable=1;"
        Set-ItemPropertyVerified -Path "$GraphicsSettingsPath" -Name "SwapEffectUpgradeCache" -Type DWord -Value 1
    } Else {
        Remove-ItemPropertyVerified -Path "HKCU:\\Software\\Microsoft\\DirectX\\UserGpuPreferences" -Name "DirectXUserGlobalSettings"
        Remove-ItemPropertyVerified -Path "HKCU:\\Software\\Microsoft\\DirectX\\GraphicsSettings" -Name "SwapEffectUpgradeCache"
    }

    Write-Status -Types "@", $TweakType -Status "MPO and GPU preemption tweaks are intentionally NOT applied automatically (can cause black screens/instability). Use vendor tools if needed." -Warning

    Write-Section "Network Latency"
    Write-Status -Types "@", $TweakType -Status "Nagle's algorithm tweaks are NOT applied automatically (often placebo/counterproductive on modern networks)." -Warning

    Write-Section "GPU Vendor-Specific Tweaks (Agnostic Detection)"
    $DetectedGpus = Get-GPU
    Write-Status -Types "@", $TweakType -Status "Detected GPU(s): $DetectedGpus" -Warning

    If (Test-Path "$PathToGpuClass") {
        Get-ChildItem -Path "$PathToGpuClass" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            $GpuDescriptor = (Get-ItemProperty -Path $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            If ([String]::IsNullOrWhiteSpace($GpuDescriptor)) { return }

            If ($GpuDescriptor -match 'NVIDIA') {
                Write-Caption "NVIDIA GPU detected: $GpuDescriptor"
                If (!$Revert) {
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "PreferSystemMemoryContiguous" -Type DWord -Value 1
                    # Enable MSI mode for the NVIDIA GPU (safe, reduces DPC latency)
                    Try {
                        $PnpDevice = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'NVIDIA' } | Select-Object -First 1
                        If ($PnpDevice) {
                            $MsiPath = "HKLM:\\SYSTEM\\CurrentControlSet\\Enum\\$($PnpDevice.InstanceId)\\Device Parameters\\Interrupt Management\\MessageSignaledInterruptProperties"
                            If (!(Test-Path "$MsiPath")) { New-Item -Path "$MsiPath" -Force | Out-Null }
                            Set-ItemPropertyVerified -Path "$MsiPath" -Name "MSISupported" -Type DWord -Value 1
                        }
                    } Catch {
                        Write-Status -Types "?", $TweakType -Status "Could not enable MSI mode automatically." -Warning
                    }
                } Else {
                    Remove-ItemPropertyVerified -Path $_.PSPath -Name "PreferSystemMemoryContiguous"
                }
                # Disable NVIDIA telemetry (hellzerg/optimizer)
                If (!$Revert) {
                    Try {
                        $NvFtsPath = "HKLM:\\SOFTWARE\\NVIDIA Corporation\\Global\\FTS"
                        If (!(Test-Path "$NvFtsPath")) { New-Item -Path "$NvFtsPath" -Force | Out-Null }
                        Set-ItemPropertyVerified -Path "$NvFtsPath" -Name "EnableRID44231" -Type DWord -Value 0
                        Set-ItemPropertyVerified -Path "$NvFtsPath" -Name "EnableRID64640" -Type DWord -Value 0
                        Set-ItemPropertyVerified -Path "$NvFtsPath" -Name "EnableRID66610" -Type DWord -Value 0
                        $NvCpPath = "HKLM:\\SOFTWARE\\NVIDIA Corporation\\NvControlPanel2\\Client"
                        If (Test-Path "$NvCpPath") { Set-ItemPropertyVerified -Path "$NvCpPath" -Name "OptInOrOutPreference" -Type DWord -Value 0 }
                        Stop-Service -Name "NvTelemetryContainer" -Force -ErrorAction SilentlyContinue
                        Set-Service -Name "NvTelemetryContainer" -StartupType Disabled -ErrorAction SilentlyContinue
                    } Catch {
                        Write-Status -Types "?", $TweakType -Status "Could not disable NVIDIA telemetry automatically." -Warning
                    }
                }
                Write-Status -Types "@", $TweakType -Status "NVIDIA checklist: Low Latency Mode = On/Ultra, Power Management = Prefer Maximum Performance, Texture Filtering = High Performance, Shader Cache = Driver Default or larger (never disabled), enable G-SYNC/Adaptive Sync, keep drivers updated. Advanced clock locking (DisableDynamicPstate/P-State 0) only with benchmarking." -Warning
            } ElseIf ($GpuDescriptor -match 'AMD|Radeon') {
                Write-Caption "AMD GPU detected: $GpuDescriptor"
                If ($GpuDescriptor -match 'RX\\s?9') {
                    Write-Status -Types "@", $TweakType -Status "Radeon RX 9000 detected: ULPS is NOT disabled automatically (can cause instability)." -Warning
                } Else {
                    If (!$Revert) {
                        Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps" -Type DWord -Value 0
                        Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps_NA" -Type DWord -Value 0
                        Set-ItemPropertyVerified -Path $_.PSPath -Name "PP_DisableULPS" -Type DWord -Value 1
                    } Else {
                        Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps" -Type DWord -Value 1
                        Remove-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps_NA"
                        Remove-ItemPropertyVerified -Path $_.PSPath -Name "PP_DisableULPS"
                    }
                }
                Write-Status -Types "@", $TweakType -Status "AMD checklist: Enable Anti-Lag/Anti-Lag+, Radeon Boost, Texture Filtering = Performance, enable SAM/ReBAR in BIOS, keep drivers updated. Avoid disabling clock gating/power saving unless benchmarked." -Warning
            } ElseIf ($GpuDescriptor -match 'Intel') {
                Write-Caption "Intel GPU detected: $GpuDescriptor"
                Write-Status -Types "@", $TweakType -Status "Intel checklist: keep drivers updated, enable HAGS, enable Resizable BAR in BIOS for Arc, use Intel Graphics Software (XeLL where available, Low Latency On), do not pin cores (Thread Director)." -Warning
            } Else {
                Write-Status -Types "?", $TweakType -Status "Unknown GPU vendor: $GpuDescriptor" -Warning
            }
        }
    } Else {
        Write-Status -Types "?", $TweakType -Status "GPU class registry path not found, skipping vendor-specific tweaks." -Warning
    }

    Write-Section "Advanced Multimedia Profile (hellzerg/optimizer)"
    If (!$Revert) {
        Set-ItemPropertyVerified -Path "$PathToLMMultimediaSystemProfile" -Name "NoLazyMode" -Type DWord -Value 1
        Set-ItemPropertyVerified -Path "$PathToLMMultimediaSystemProfile" -Name "AlwaysOn" -Type DWord -Value 1
        $LowLatencyPath = "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Low Latency"
        If (!(Test-Path "$LowLatencyPath")) { New-Item -Path "$LowLatencyPath" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$LowLatencyPath" -Name "GPU Priority" -Type DWord -Value 0
        Set-ItemPropertyVerified -Path "$LowLatencyPath" -Name "Priority" -Type DWord -Value 8
        Set-ItemPropertyVerified -Path "$LowLatencyPath" -Name "Scheduling Category" -Type String -Value "Medium"
        Set-ItemPropertyVerified -Path "$LowLatencyPath" -Name "SFIO Priority" -Type String -Value "High"
    } Else {
        Remove-ItemPropertyVerified -Path "$PathToLMMultimediaSystemProfile" -Name "NoLazyMode"
        Remove-ItemPropertyVerified -Path "$PathToLMMultimediaSystemProfile" -Name "AlwaysOn"
        Remove-ItemPropertyVerified -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Low Latency" -Name "GPU Priority"
        Remove-ItemPropertyVerified -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Low Latency" -Name "Priority"
        Remove-ItemPropertyVerified -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Low Latency" -Name "Scheduling Category"
        Remove-ItemPropertyVerified -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Low Latency" -Name "SFIO Priority"
    }

    Write-Section "HPET (Advanced, Use At Own Risk)"
    Write-Status -Types "@", $TweakType -Status "HPET tweaks are NOT applied automatically. Run manually if desired: bcdedit /deletevalue useplatformclock ; bcdedit /set disabledynamictick yes (revert: bcdedit /set useplatformclock true ; bcdedit /set disabledynamictick no)." -Warning

    Write-Section "Shader Cache"
    Write-Status -Types "+", $TweakType -Status "Increasing Windows D3D shader cache size limit to 4096 MB..."
    If (!$Revert) {
        $D3DPath = "HKLM:\\SOFTWARE\\Microsoft\\Direct3D"
        If (!(Test-Path "$D3DPath")) { New-Item -Path "$D3DPath" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$D3DPath" -Name "ShaderCacheSizeInMB" -Type DWord -Value 4096
    } Else {
        Remove-ItemPropertyVerified -Path "HKLM:\\SOFTWARE\\Microsoft\\Direct3D" -Name "ShaderCacheSizeInMB"
    }

    Write-Section "CPU Vendor Checklists"
    If ($CpuName -match 'Ryzen') {
        Write-Status -Types "@", $TweakType -Status "Ryzen checklist: install AMD chipset driver, enable EXPO/XMP, PBO + Curve Optimizer (stability test), Smart Access Memory/ReBAR, keep Game Mode on (core parking on X3D), avoid manual core affinity." -Warning
    } ElseIf ($CpuName -match 'Intel') {
        Write-Status -Types "@", $TweakType -Status "Intel checklist: keep drivers updated, enable XMP, let Thread Director handle hybrid cores, enable ReBAR for Arc, avoid manual core affinity." -Warning
    }

    Write-Section "Virtualization-Based Security (Optional)"
    Write-Status -Types "@", $TweakType -Status "Memory Integrity (HVCI) and VBS are NOT changed automatically; disable them manually only if you accept the security trade-off (can break anti-cheat/WSL)." -Warning
}

If (!$Revert) {
    Optimize-Gaming # Apply gaming-focused optimizations
} Else {
    Optimize-Gaming -Revert
}
