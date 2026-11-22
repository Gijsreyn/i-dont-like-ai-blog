---
title: "Configure Intune's Windows settings with Microsoft DSC"
status: draft
tags: ["Microsoft Desired State Configuration v3", "Azure"]
custom_excerpt: "The settings Intune pushes to Windows, applied from a YAML file with Microsoft DSC."
---

Back in the days, I was responsible for configuring Mobile Device Management (MDM) together with Microsoft Intune and System Center Configuration Manager (SCCM). Those days are gone, but it learned me to work with OMA-URI.

Fast forward a couple of years and I was reading through the Microsoft DSC repository. I stopped and saw a folder i hadn't seen before. It was called `adapters/csp`, and its manifest said it "Adapts installed Windows MDM Bridge WMI classes into DSC resources." I had to ask what the MDM part was about. Was this really Mobile Device Management, inside DSC?

It was. The settings that Intune delivers to a Windows machine can now be tested and set from a DSC configuration document, on a machine Intune has never seen.

In this tutorial, you'll build a Windows 11 VM in Azure, install the DSC preview that ships the adapter, and apply a Windows Update policy and a Defender policy to it. You'll do all of it without opening a single port on the VM.

## Prerequisites

To follow along, you need:

- An Azure subscription that may run Windows 11 VMs. That takes [a license that allows it][01], such as a Visual Studio subscription for testing.
- The Azure CLI with Bicep, signed in with `az login`.
- PowerShell 7 on your own machine.
- Basic familiarity with Microsoft DSC configuration documents

## Understanding the CSP adapter

Intune doesn't change Windows settings itself. It sends them to Configuration Service Providers, or CSPs, which are the interface Windows offers to any MDM server. If you have ever typed an OMA-URI like `./Device/Vendor/MSFT/Policy/Config/Update/ActiveHoursStart` into a custom profile, you have addressed a CSP directly.

Windows also exposes those CSPs locally, through a WMI provider called the MDM Bridge. Every CSP area is a WMI class with a name that starts with `MDM_`. The new adapter arrived in [DSC 3.4.0-preview.3][02]. It lists those classes and turns each one into a DSC resource. The Update policies become `Microsoft.Windows.CSP/MDM_Policy_Config01_Update02`, and `ActiveHoursStart` is a property on it.

There's a catch here, which shaped the whole tutorial. Device settings only work when the caller is _LocalSystem_. My first plan was to push the document over the [SSH prototype][03] I've been working on. But when reading through the adapter's code, it stopped me. An SSH session runs as the account you sign in with, and the adapter's error message leaves no room: "An elevated administrator is not sufficient." Microsoft's own [guidance for the bridge][04] tells you to start PowerShell with `psexec -s`.

Then I remembered that Azure already has something that runs as SYSTEM on every VM, and that is Run Command.

## Setting up the virtual machine

I had a Bicep template left from an SSH demo, built on Azure Verified Modules. For this tutorial I removed almost everything from it. The storage account, the managed identity, the custom script extension and the inbound SSH rule are gone. What remains is a virtual network and a VM with no inbound rules at all.

The one change is the image. The Policy CSP lists client editions, and the reference for the bridge classes says no server version is supported. So this VM runs Windows 11 Enterprise.

```bicep
imageReference: {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'windows-11'
  sku: 'win11-24h2-ent'
  version: 'latest'
}
```

> [!NOTE]
> You can find the full template in my [GitHub repository][05].

Create a resource group and deploy the template. The deployment asks for an administrator password that you won't need again.

```powershell
az group create --name rg-dsc-csp-demo --location westeurope
az deployment group create --resource-group rg-dsc-csp-demo --template-file infra/main.bicep
```

### Installing DSC with Run Command

[Run Command][06] uses the VM agent to run a script inside the VM. It runs as SYSTEM and it needs no open port, which is exactly what the adapter asks for. Save the following script as `install-dsc.ps1`. It downloads the release from GitHub, unpacks it and adds it to the machine path.

```powershell
$ProgressPreference = 'SilentlyContinue'
$url = 'https://github.com/PowerShell/DSC/releases/download/v3.4.0-preview.3/DSC-3.4.0-preview.3-x86_64-pc-windows-msvc.zip'
$zip = Join-Path $env:TEMP 'dsc.zip'
$path = Join-Path $env:ProgramFiles 'dsc'

Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $path -Force
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
[Environment]::SetEnvironmentVariable('Path', "$machinePath;$path", 'Machine')

& "$path\dsc.exe" --version
whoami
```

Now send the script to the VM.

```powershell
az vm run-command invoke --resource-group rg-dsc-csp-demo --name vm-dscdemo `
    --command-id RunPowerShellScript --scripts '@install-dsc.ps1' `
    --query 'value[0].message' --output tsv
```

![Figure 1: Install Microsoft DSC in Azure VM][09]

> [!INFO]
> The `whoami` line is your proof. If it doesn't answer `nt authority\system`, the adapter will refuse every device setting later on.

## Building the configuration document

With DSC on the VM, you can start writing the document. It takes three small steps:

1. Find the available CSP resources through the adapter
1. Describe the Windows Update settings
1. Describe the Defender settings

Let's start with finding the CSP resources first.

### Finding the CSP resources

The adapter can tell you which resources this Windows build offers. Run Command returns only the last 4,096 bytes of output and the full list is much longer than that, so filter on the VM and bring back only the two areas you need. Save this as `list-csp.ps1` and send it the same way as the install script.

```powershell
& "$env:ProgramFiles\dsc\dsc.exe" resource list --adapter Microsoft.Windows.Adapter/ConfigurationServiceProvider |
    ForEach-Object { ($_ | ConvertFrom-Json).type } |
    Where-Object { $_ -match 'Update|Defender' }
```

![Figure 2: List CSP adapter resources in Azure VM][10]

> [!INFO]
> Each entry in the list also has a `capabilities` field. A resource without `set` in it is read only, because its class has no writable properties.

### Writing the Windows Update resource

Create a file named `csp.dsc.yaml`. A resource is one CSP area. `ParentID` and `InstanceID` are the two halves of the path you know from the OMA-URI, and the other properties are the policies.

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
- name: Windows Update
  type: Microsoft.Windows.CSP/MDM_Policy_Config01_Update02
  properties:
    ParentID: ./Vendor/MSFT/Policy/Config
    InstanceID: Update
    ActiveHoursStart: 8
    ActiveHoursEnd: 18
    DeferQualityUpdatesPeriodInDays: 7
```

### Adding the Defender resource

Defender works the same way with a different class. Add this resource below the first one.

```yaml
- name: Defender
  type: Microsoft.Windows.CSP/MDM_Policy_Config01_Defender02
  properties:
    ParentID: ./Vendor/MSFT/Policy/Config
    InstanceID: Defender
    AllowCloudProtection: 1
    PUAProtection: 1
```

> [!TIP]
> List only the policies you care about. The adapter tests and sets the properties in your document and leaves every other policy in that area alone.

## Applying and verifying the configuration

The document is on your machine and `dsc` is on the VM. Run Command connects the two.

### Sending the document through Run Command

I didn't want to copy files to the VM, so the document travels as a parameter. Save this as `run-dsc.ps1`. It decodes the document, hands it to `dsc` and prints one line per resource.

```powershell
param([string]$Operation, [string]$Document)

$yaml = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Document))
$result = $yaml | & "$env:ProgramFiles\dsc\dsc.exe" config $Operation --file - | ConvertFrom-Json
foreach ($resource in $result.results) {
    if ($Operation -eq 'test') {
        '{0} in desired state: {1}' -f $resource.name, $resource.result.inDesiredState
    } else {
        '{0} changed: {1}' -f $resource.name, ($resource.result.changedProperties -join ', ')
    }
}
```

### Running test, set and test

Start with a test, which changes nothing.

```powershell
$documentPath = Join-Path -Path (Get-Location).Path -ChildPath 'csp.dsc.yaml'
$document = [Convert]::ToBase64String([IO.File]::ReadAllBytes($documentPath))

az vm run-command invoke --resource-group rg-dsc-csp-demo --name vm-dscdemo `
    --command-id RunPowerShellScript --scripts '@run-dsc.ps1' `
    --parameters "Operation=set" "Document=$document" `
    --query 'value[0].message' --output tsv
```

On this newly created VM, the test is going to say that neither resource is in it's desired state.

![Figure 3: Run `test` operation against Azure VM][11]

Change `Operation=test` to `Operation=set` and run it again. Now the output lists the properties that changed. A second test confirms that both resources are where the document wants them.

![Figure 4: Run `set` operation against Azure VM][12]

If you look at the registry settings on the Azure VM, you'll notice the values have been set:

![Figure 5: Machine is in the desired state][13]

Undoing it is the same motion. Add `_exist: false` to a resource, run `set` once more, and the adapter removes the policy instance.

## Knowing the limits

A few things are worth knowing before this goes anywhere near production.

The SYSTEM requirement doesn't go away. Run Command solved it here. On machines outside Azure you need another way to start `dsc` as SYSTEM, and a scheduled task is the obvious one.

Group Policy can get in the way. When Group Policy and the Policy CSP set the same policy, Group Policy wins by default. The [MDMWinsOverGP][07] policy turns that around, but it only covers the Policy CSP.

The same goes for Intune. If a device is enrolled, Intune writes to the same CSPs, so pick one owner for each setting.

The adapter is part of a preview release. It reads and writes settings, and it can't trigger the actions some CSPs have.

## Conclusion

You built a Windows 11 VM, installed a DSC preview on it and applied Windows Update and Defender policies from a YAML file. The machine has no MDM enrollment and no open ports. When you're done, one command removes everything.

```powershell
az group delete --name rg-dsc-csp-demo --yes
```

I started with a question about three letters in a folder name. Next I want to try the AssignedAccess CSP and build a kiosk this way. Microsoft's [kiosk documentation][08] solves that today with a PowerShell script and `psexec`, and a configuration document you can test seems like the better deal.

Which Intune setting would you move into a configuration document first?

<!-- Link reference definitions -->
[01]: https://learn.microsoft.com/azure/virtual-machines/windows/windows-desktop-multitenant-hosting-deployment
[02]: https://github.com/PowerShell/DSC/releases/tag/v3.4.0-preview.3
[03]: https://github.com/PowerShell/DSC/pull/1810
[04]: https://learn.microsoft.com/windows/client-management/using-powershell-scripting-with-the-wmi-bridge-provider
[05]: https://github.com/Gijsreyn/i-dont-like-ai-blog/tree/main/posts/2026-11-22-configure-intunes-windows-settings/infra
[06]: https://learn.microsoft.com/azure/virtual-machines/windows/run-command
[07]: https://learn.microsoft.com/windows/client-management/mdm/policy-csp-controlpolicyconflict
[08]: https://learn.microsoft.com/windows/configuration/assigned-access/quickstart-kiosk
[09]: images/show-dsc-system-azure-vm.png
[10]: images/list-csp-adapter-resources.png
[11]: images/run-test-operation.png
[12]: images/run-set-operation.png
[13]: images/show-dsc-system-azure-vm.png
