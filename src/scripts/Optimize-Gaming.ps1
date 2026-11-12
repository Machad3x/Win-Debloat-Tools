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

    Write-Status -Types $EnableStatus[0].Symbol, $TweakType -Status "$($EnableStatus[0].Status) fullscreen optimizations globally..."
    If (!$Revert) {
        If (!(Test-Path "$PathToCUGameConfigStore")) { New-Item -Path "$PathToCUGameConfigStore" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$PathToCUGameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2
        Set-ItemPropertyVerified -Path "$PathToCUGameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 1
        Set-ItemPropertyVerified -Path "$PathToCUGameConfigStore" -Name "GameDVR_FSEBehavior" -Type DWord -Value 2
        Set-ItemPropertyVerified -Path "$PathToCUGameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type DWord -Value 1
    } Else {
        Remove-ItemPropertyVerified -Path "$PathToCUGameConfigStore" -Name "GameDVR_FSEBehaviorMode"
        Remove-ItemPropertyVerified -Path "$PathToCUGameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode"
        Remove-ItemPropertyVerified -Path "$PathToCUGameConfigStore" -Name "GameDVR_FSEBehavior"
        Remove-ItemPropertyVerified -Path "$PathToCUGameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible"
    }

    Write-Status -Types $EnableStatus[0].Symbol, $TweakType -Status "$($EnableStatus[0].Status) Game DVR background recording..."
    If (!$Revert) {
        Set-ItemPropertyVerified -Path "$PathToCUGameDVR" -Name "AppCaptureEnabled" -Type DWord -Value 0
        If (!(Test-Path "$PathToLMPoliciesGameDVR")) { New-Item -Path "$PathToLMPoliciesGameDVR" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$PathToLMPoliciesGameDVR" -Name "AllowGameDVR" -Type DWord -Value 0
    } Else {
        Remove-ItemPropertyVerified -Path "$PathToCUGameDVR" -Name "AppCaptureEnabled"
        Remove-ItemPropertyVerified -Path "$PathToLMPoliciesGameDVR" -Name "AllowGameDVR"
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

    Write-Section "Display & GPU Scheduling"
    Write-Status -Types "-", $TweakType -Status "Disabling Multiplane Overlay (MPO) to reduce stutter..."
    If (!$Revert) {
        Set-ItemPropertyVerified -Path "$PathToLMDwm" -Name "OverlayTestMode" -Type DWord -Value 5
    } Else {
        Remove-ItemPropertyVerified -Path "$PathToLMDwm" -Name "OverlayTestMode"
    }

    Write-Status -Types "-", $TweakType -Status "Disabling GPU task preemption for smoother frame pacing..."
    If (!$Revert) {
        If (!(Test-Path "$PathToLMGraphicsScheduler")) { New-Item -Path "$PathToLMGraphicsScheduler" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$PathToLMGraphicsScheduler" -Name "DisablePreemption" -Type DWord -Value 1
    } Else {
        Remove-ItemPropertyVerified -Path "$PathToLMGraphicsScheduler" -Name "DisablePreemption"
    }

    Write-Section "Network Latency"
    Write-Status -Types "-", $TweakType -Status "Disabling Nagle's algorithm on all network interfaces..."
    $NetworkInterfaces = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
    ForEach ($Interface in $NetworkInterfaces) {
        If (!$Revert) {
            Set-ItemPropertyVerified -Path "$($Interface.PSPath)" -Name "TcpAckFrequency" -Type DWord -Value 1
            Set-ItemPropertyVerified -Path "$($Interface.PSPath)" -Name "TCPNoDelay" -Type DWord -Value 1
        } Else {
            Remove-ItemPropertyVerified -Path "$($Interface.PSPath)" -Name "TcpAckFrequency"
            Remove-ItemPropertyVerified -Path "$($Interface.PSPath)" -Name "TCPNoDelay"
        }
    }

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
                    $UmdPath = Join-Path -Path $_.PSPath -ChildPath "UMD"
                    If (Test-Path "$UmdPath") {
                        Set-ItemPropertyVerified -Path "$UmdPath" -Name "ShaderCacheSize" -Type DWord -Value 10240
                    }
                } Else {
                    Remove-ItemPropertyVerified -Path $_.PSPath -Name "PreferSystemMemoryContiguous"
                    $UmdPath = Join-Path -Path $_.PSPath -ChildPath "UMD"
                    If (Test-Path "$UmdPath") {
                        Remove-ItemPropertyVerified -Path "$UmdPath" -Name "ShaderCacheSize"
                    }
                }
                Write-Status -Types "@", $TweakType -Status "NVIDIA checklist: Low Latency Mode = Ultra, Power Management = Prefer Maximum Performance, Texture Filtering = High Performance, Shader Cache = 10 GB (NVIDIA Control Panel)." -Warning
            } ElseIf ($GpuDescriptor -match 'AMD|Radeon') {
                Write-Caption "AMD GPU detected: $GpuDescriptor"
                If (!$Revert) {
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps" -Type DWord -Value 0
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps_NA" -Type DWord -Value 0
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "PP_DisableULPS" -Type DWord -Value 1
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "DisableAllClockGating" -Type DWord -Value 1
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "PP_Force3DPerformanceMode" -Type DWord -Value 1
                } Else {
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps" -Type DWord -Value 1
                    Remove-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps_NA"
                    Remove-ItemPropertyVerified -Path $_.PSPath -Name "PP_DisableULPS"
                    Remove-ItemPropertyVerified -Path $_.PSPath -Name "DisableAllClockGating"
                    Remove-ItemPropertyVerified -Path $_.PSPath -Name "PP_Force3DPerformanceMode"
                }
                Write-Status -Types "@", $TweakType -Status "AMD checklist: Enable Anti-Lag/Anti-Lag+, Radeon Boost, set Texture Filtering to Performance (AMD Software: Adrenalin)." -Warning
            } ElseIf ($GpuDescriptor -match 'Intel') {
                Write-Caption "Intel GPU detected: $GpuDescriptor"
                Write-Status -Types "@", $TweakType -Status "Intel Arc/iGPU: keep drivers updated; HAGS and Game Mode apply automatically." -Warning
            } Else {
                Write-Status -Types "?", $TweakType -Status "Unknown GPU vendor: $GpuDescriptor" -Warning
            }
        }
    } Else {
        Write-Status -Types "?", $TweakType -Status "GPU class registry path not found, skipping vendor-specific tweaks." -Warning
    }

    Write-Section "Virtualization-Based Security (Optional)"
    Write-Status -Types "@", $TweakType -Status "Memory Integrity (HVCI) and VBS are NOT changed automatically; disable them manually only if you accept the security trade-off." -Warning
}

If (!$Revert) {
    Optimize-Gaming # Apply gaming-focused optimizations
} Else {
    Optimize-Gaming -Revert
}
