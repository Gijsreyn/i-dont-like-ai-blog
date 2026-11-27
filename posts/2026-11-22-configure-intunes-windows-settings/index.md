---
title: "Test Windows policies from Intune custom profiles with Microsoft DSC"
status: published
tags: ["Microsoft Desired State Configuration v3", "Azure"]
custom_excerpt: "Test and apply two device-scoped Windows policies from YAML."
feature_image: images/cover.jpg
feature_image_alt: ''
---

I used to set up Microsoft Intune and System Center Configuration Manager (SCCM) to implement Mobile Device Management (MDM). While that's in the past for me, it allowed me to understand OMA-URI better.

Years later, while looking through the Microsoft DSC repository, I found `adapters/csp` which had some very interesting classes. These classes, as described in the [reference adapter][14], allowed users to write DSC resources to implement some aspects of Windows MDM. Was this really Mobile Device Management, inside DSC?

It was. Some of the same settings Intune delivers to Windows can be tested and set from a DSC configuration document, even on a machine Intune has never seen.

If you are already familiar with setting up Intune custom profiles, then this lab will show you how to set up Windows Update and Windows Defender settings on a temporary Windows 11 Enterprise virtual machine, using the Microsoft DSC adapter. No inbound SSH or RDP connection is required to the VM by Azure Run Command to execute the DSC configurations.

## Prerequisites

To follow along, you need:

- To use the [Azure Run Command][06] feature, you first must log on to the Azure CLI using `az login`.
- If you are going to deploy the demo VM, you must also have permissions to create the resource group and other related resources.
- On your computer you must have PowerShell 7 and some understanding of Microsoft DSC configuration files.

## Understanding the CSP adapter

When Intune is used to configure Windows settings, it actually communicates with CSPs (Configuration Service Providers). These are interfaces that Windows provides to MDM servers. If you have previously created a custom profile using an OMA-URI like `./Device/Vendor/MSFT/Policy/Config/Update/ActiveHoursStart` then you have communicated with a CSP.

Some CSP settings can be accessed locally by the MDM Bridge on Windows. The MDM Bridge is available starting with [DSC 3.4.0-preview.2][02]. The script to install it is shown below and can be run with previews 3. The MDM Bridge exposes some of the `MDM_*` classes installed on the machine. An example of this is the class `Microsoft.Windows.CSP/MDM_Policy_Config01_Update02` which contains the property `ActiveHoursStart`.

Using the adapter, settings can be configured using LocalSystem privilege, as described in the [documentation][14]. My first idea was to use the [SSH prototype][03] to send the document to the virtual machine. However, the SSH process runs using the user's credentials that connects to it, even if that user has escalated privileges. Therefore, to use this adapter, you must run PowerShell on the virtual machine [using PsExec][04] with the `-s` switch.

I then remembered that Azure Run Command allows execution of commands as system on Windows virtual machines.

## Setting up the virtual machine

> [!TIP]
> Already have a non-enrolled Windows 11 Enterprise test machine? Skip the Bicep template. Otherwise, first go to [Installing DSC with Run Command](#installing-dsc-with-run-command) on the virtual machine you wish to use and follow the steps in this document, substituting the virtual machine name and resource group with those of the virtual machine you are using. If the machine is located outside of Azure, don't use Run Command. Instead, run `install-dsc.ps1` using PowerShell locally with LocalSystem credentials, following the [instructions on using the WMI Bridge][04]. To find the resources of the configuration service provider, follow the instructions in that document.

I previously created a Bicep template to demonstrate Azure Verified Modules, which I modified to create this template. Here, I removed the storage account and managed identity. I also removed the custom script extension and rule to allow incoming SSH connections. No other changes were made to the template. The virtual machine still has a public IP address to allow outgoing connections. No inbound rules have been modified, so the [default network security group rules][17] still apply.

The second change was to use Windows 11 Enterprise. The [Update][15] and [Defender][16] bridge class references list no supported Windows Server version, so this lab uses Windows 11 Enterprise.

```bicep
imageReference: {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'windows-11'
  sku: 'win11-24h2-ent'
  version: 'latest'
}
```

> [!NOTE]
> Download the [demo files][05] from my GitHub repository and open PowerShell in the demo directory so `infra/main.bicep` resolves.

Once the template has been deployed, input an administrator password when prompted.

```powershell
az group create --name rg-dsc-csp-demo --location westeurope
az deployment group create --resource-group rg-dsc-csp-demo --template-file infra/main.bicep
```

### Installing DSC with Run Command

This password will not be used anywhere else. Use [Run Command][06] to run the install script on the virtual machine. This script will download the release file, unpack it and add it to the virtual machine's path.

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

![Figure 1: Run Command reporting LocalSystem in the original preview.2 lab run][09]

> [!NOTE]
> Once completed, type the command `dsc --version` to verify the installation and `whoami` to verify the execution context of the command. In the screen shot showing the execution of these commands, both were run using version 3.4.0-preview.2.

## Building the configuration document

With DSC on the virtual machine, you can now write your first policy. To determine what resources this version of Windows provides, use Run Command to execute `list-csp.ps1`.

1. Find the available CSP resources through the adapter
1. Describe the Windows Update settings
1. Describe the Defender settings

Let's start with finding the CSP resources first.

### Finding the CSP resources

Because of [Run Command's 4096 character limit][06], filter the result to show only the resource types available on the virtual machine. To find out which resources this version of Windows provides, use Run Command to execute `list-csp.ps1`.

```powershell
& "$env:ProgramFiles\dsc\dsc.exe" resource list --adapter Microsoft.Windows.Adapter/ConfigurationServiceProvider |
    ForEach-Object { ($_ | ConvertFrom-Json).type } |
    Where-Object { $_ -match 'Update|Defender' }
```

![Figure 2: List CSP adapter resources in Azure VM][10]

> [!NOTE]
> Filter the result as above, using `list-csp.ps1` with the `-filter` switch. To find out which methods the class supports, list the class and check the `capabilities` field. The [adapter reference][14] explains how those capabilities are derived.

### Writing the Windows Update resource

Use the included `csp.dsc.yaml` or build it from the next two snippets. `ParentID` and `InstanceID` are the WMI keys for this [Update class][15]: the parent path and the instance identifier under it. The other properties are the settings to manage.

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

Defender can be integrated using [its own class][16]. If you create this file on your own, add the Defender resource below the resource you just created.

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
> Only include the settings you wish to change. The [adapter][14] tests each property of the setting to determine if the property has changed since the last time the configuration was applied.

### Mapping your own OMA-URI

Properties that have not changed will be untouched. To better understand each property, look up the description in the [CSP reference guide][18] of the Windows version you are targeting. Also check the [MDM Bridge reference guide][19] to see if the adapter is available on the target test machine.

For `./Device/Vendor/MSFT/Policy/Config/Update/ActiveHoursStart`, the [Update bridge class][15] gives you this mapping:

| DSC field    | Value                                                |
|--------------|------------------------------------------------------|
| `type`       | `Microsoft.Windows.CSP/MDM_Policy_Config01_Update02` |
| `ParentID`   | `./Vendor/MSFT/Policy/Config`                        |
| `InstanceID` | `Update`                                             |
| Property     | `ActiveHoursStart`                                   |

Do not use positioning in the URI to locate the class you wish to manage. Instead, look up the class in the MDM Bridge reference guide, and use the keys provided there. To inspect the class on the test machine, run:

```powershell
$resource = & "$env:ProgramFiles\dsc\dsc.exe" resource list 'Microsoft.Windows.CSP/MDM_Policy_Config01_Update02' `
    --adapter Microsoft.Windows.Adapter/ConfigurationServiceProvider | ConvertFrom-Json
$resource.capabilities
$resource.schema.properties.ActiveHoursStart | ConvertTo-Json -Depth 10
```

Are there any `set` operations in the capability list of the property you want to use? Also check if the property is set as `readOnly`. If neither of these are the case, use `Get-CimInstance` to view the value of the property, rather than using Run Command. If the class and property are available, manage the setting on that machine using this adapter. To find more details about allowable values for the property use `Test` in combination with `Get` to view the value of the property.

## Applying and verifying the configuration

In the first step, copy `csp.dsc.yaml` to the test machine. To run the commands in the order shown, in a LocalSystem session of PowerShell on the test machine, navigate to the directory containing the yaml file and run each command in sequence.

```powershell
$dsc = "$env:ProgramFiles\dsc\dsc.exe"
& $dsc config test --file .\csp.dsc.yaml
& $dsc config set --file .\csp.dsc.yaml
& $dsc config test --file .\csp.dsc.yaml
```

I've chosen not to transfer files to the virtual machine, so instead I'll pass the document to `run-dsc.ps1`.

### Sending the document through Run Command

This script is included in the source code folder and when executed will print the result of each resource to the screen.

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
    --parameters "Operation=test" "Document=$document" `
    --query 'value[0].message' --output tsv
```

In the baseline state of the resources, `false` was returned for each resource on both of the machines used in the lab. For more information about DSC and MDM on Windows, refer to the following sources.

![Figure 3: Run `test` operation against Azure VM][11]

In this test, change `Operation=test` to `Operation=set`. The output of the original `set` command included more properties than what is listed in the YAML file. Therefore, don't use the output of `set` to determine what settings was modified.

![Figure 4: Run `set` operation against Azure VM][12]

Run the command again with `Operation=test`. If both resources are updated to match the document, the expected output would be:

```text
Windows Update in desired state: True
Defender in desired state: True
```

The output of the previous run of the registry test showed three values associated with Windows Update. Since Defender wasn't tested, use the last DSC test to check both of these values.

![Figure 5: Windows Update policy values in the registry from the original lab run][13]

To remove the instance of the resource, update the YAML file to include `_exist: false` in the `properties` section and run `set` again.

To fully implement this, the CSP associated with the resource [must also support deletion][14].

## Knowing the limits

Some things to consider before implementing this solution in a production environment:

The need for SYSTEM access is not removed. Run Command was used here to gain this access. Other methods to gain SYSTEM access to run `dsc` may be needed, for example, creating a scheduled task.

In cases where Group Policy and settings managed by MDM conflict, as documented by Microsoft [MDMWinsOverGP][07], settings applied by Group Policy will take effect. Therefore, settings written locally by DSC may be overridden by Group Policy settings.

Don't use Intune profiles to manage settings already covered by this DSC configuration. This test doesn't determine what happens if both are used.

The adapter is in preview. During this time it can read and write settings, but [will not invoke CSP actions][14].

## Cleaning up

Only execute this step if you've created the demo resource group specifically for this lab. It will remove everything in that group, including the VM. Don't use this command if you already have the VM created in another resource group.

```powershell
az group delete --name rg-dsc-csp-demo --yes
```

## Conclusion

In the first step of this lab I asked what the letters in the folder name stood for. Now I'm interested in creating a kiosk using the AssignedAccess CSP as shown in Microsoft's [kiosk documentation][08]. To do this you would use PsExec to run the PowerShell script Microsoft provides in their documentation. In theory, building a kiosk with DSC would be easier to use and more reliable than PsExec and PowerShell scripts.

Which Intune setting would you move into a configuration document first?

<!-- Link reference definitions -->
[02]: https://github.com/PowerShell/DSC/releases/tag/v3.4.0-preview.2
[03]: https://github.com/PowerShell/DSC/pull/1810
[04]: https://learn.microsoft.com/windows/client-management/using-powershell-scripting-with-the-wmi-bridge-provider
[05]: https://github.com/Gijsreyn/i-dont-like-ai-blog/tree/main/posts/2026-11-22-configure-intunes-windows-settings
[06]: https://learn.microsoft.com/azure/virtual-machines/windows/run-command
[07]: https://learn.microsoft.com/windows/client-management/mdm/policy-csp-controlpolicyconflict
[08]: https://learn.microsoft.com/windows/configuration/assigned-access/quickstart-kiosk
[09]: images/show-dsc-system-azure-vm.png
[10]: images/list-csp-adapter-resources.png
[11]: images/run-test-operation.png
[12]: images/run-set-operation.png
[13]: images/dsc-settings-set-azure-vm.png
[14]: https://github.com/PowerShell/DSC/blob/v3.4.0-preview.3/docs/reference/resources/Microsoft/Windows/Adapter/ConfigurationServiceProvider/index.md
[15]: https://learn.microsoft.com/windows/win32/dmwmibridgeprov/mdm-policy-config01-update02
[16]: https://learn.microsoft.com/windows/win32/dmwmibridgeprov/mdm-policy-config01-defender02
[17]: https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview#default-security-rules
[18]: https://learn.microsoft.com/windows/client-management/mdm/configuration-service-provider-reference
[19]: https://learn.microsoft.com/windows/win32/dmwmibridgeprov/mdm-bridge-wmi-provider-portal