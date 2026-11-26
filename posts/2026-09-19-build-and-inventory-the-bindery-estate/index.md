---
title: "Exercise: Build and inventory the Bindery estate"
status: published
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-19T04:11:05.000Z"
custom_template: "custom-lesson"
---

<p>In this exercise you'll create the legacy estate that the rest of the course migrates. Building it yourself takes ten minutes and pays for itself three times over: you'll recognize every construct when you translate it, and you'll have a safe target to break.</p>
<blockquote>
<p>[!NOTE]<br>
The Bindery estate is the same running example used in <em>The Microsoft DSC Handbook</em>, Chapter 11. You don't need the book: every file you need is written out in full in the steps below.</p>
</blockquote>
<h2 id="prerequisites">Prerequisites</h2>
<ul>
<li>Windows with <strong>Windows PowerShell 5.1</strong> and <strong>PowerShell 7+</strong></li>
<li>The <code>dsc</code> CLI on your path (<code>dsc --version</code> should respond)</li>
<li>An elevated shell — <code>AppEnvironment</code> writes machine-level environment variables</li>
</ul>
<p>Create a working folder for the lab and use it for the rest of the course. Everything you create here is reused in Modules 2 and 3.</p>
<pre><code class="language-powershell">New-Item -Path C:\BinderyLab -ItemType Directory -Force
Set-Location C:\BinderyLab
</code></pre>
<blockquote>
<p>[!WARNING]<br>
Do this on a lab machine or a VM, not on a workstation you care about. You'll compile MOF files, register a module in a PowerShell module path, and set machine-level environment variables.</p>
</blockquote>
<h2 id="step-1-create-the-script-based-resource">Step 1: Create the script-based resource</h2>
<p>Create the module folder structure:</p>
<pre><code class="language-powershell">$module = 'C:\Program Files\WindowsPowerShell\Modules\BinderyOps'
New-Item -Path "$module\DSCResources\AppEnvironment" -ItemType Directory -Force
</code></pre>
<p>Create <code>AppEnvironment.psm1</code> in <code>$module\DSCResources\AppEnvironment</code>. This is the pattern you'll recognize from every script resource ever written — three functions, and the same parameters declared in all three:</p>
<pre><code class="language-powershell">function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)]
        [string]$Name
    )&#10;
    $value = [Environment]::GetEnvironmentVariable($Name, 'Machine')&#10;
    return @{
        Name   = $Name
        Value  = $value
        Ensure = if ($null -ne $value) { 'Present' } else { 'Absent' }
    }
}&#10;
function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string]$Name,&#10;
        [string]$Value,&#10;
        [ValidateSet('Present', 'Absent')]
        [string]$Ensure = 'Present'
    )&#10;
    $current = Get-TargetResource -Name $Name&#10;
    if ($Ensure -eq 'Absent') {
        return ($current.Ensure -eq 'Absent')
    }&#10;
    return ($current.Ensure -eq 'Present' -and $current.Value -eq $Value)
}&#10;
function Set-TargetResource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,&#10;
        [string]$Value,&#10;
        [ValidateSet('Present', 'Absent')]
        [string]$Ensure = 'Present'
    )&#10;
    if ($Ensure -eq 'Present') {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'Machine')
    } else {
        [Environment]::SetEnvironmentVariable($Name, $null, 'Machine')
    }
}&#10;
Export-ModuleMember -Function Get-TargetResource, Test-TargetResource, Set-TargetResource
</code></pre>
<p>A script-based resource is nothing without its schema. Create <code>AppEnvironment.schema.mof</code> next to the <code>.psm1</code>:</p>
<pre><code class="language-text">[ClassVersion("1.0.0"), FriendlyName("AppEnvironment")]
class AppEnvironment : OMI_BaseResource
{
    [Key, Description("The name of the environment variable.")] String Name;
    [Write, Description("The value of the environment variable.")] String Value;
    [Write, Description("Whether the variable should exist."), ValueMap{"Present","Absent"}, Values{"Present","Absent"}] String Ensure;
};
</code></pre>
<blockquote>
<p>[!NOTE]<br>
The schema MOF is what makes the resource discoverable and what declares which property is the key. When you rewrite this resource as a class in Module 2, this file disappears because its information moves into <code>[DscProperty()]</code> attributes.</p>
</blockquote>
<p>Finally, the module manifest at the root of <code>$module</code>, as <code>BinderyOps.psd1</code>:</p>
<pre><code class="language-powershell">@{
    RootModule           = ''
    ModuleVersion        = '1.0.0'
    GUID                 = 'b3d4f7a1-6c2e-4e8a-9f31-8d5a2c7e4b90'
    Author               = 'Bindery Operations'
    Description          = 'Bindery operational resources.'
    PowerShellVersion    = '5.1'
}
</code></pre>
<p>Replace the <code>GUID</code> value with one of your own. Every module needs a unique identifier, and <code>New-Guid</code> generates one:</p>
<pre><code class="language-powershell">(New-Guid).Guid
</code></pre>
<p>Keep a note of it. When you write the version 2.0.0 manifest in Module 2, you reuse the same GUID, because both versions are the same module.</p>
<h2 id="step-2-write-the-legacy-configuration">Step 2: Write the legacy configuration</h2>
<p>In your working folder, create <code>LegacyWebServer.ps1</code>:</p>
<pre><code class="language-powershell"># LegacyWebServer.ps1 - the "before" state: classic PowerShell DSC
Configuration LegacyWebServer {
    param (
        [Parameter(Mandatory)]
        [string]$AppRoot
    )&#10;
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName BinderyOps&#10;
    Node 'localhost' {
        File AppDirectory {
            DestinationPath = $AppRoot
            Type            = 'Directory'
            Ensure          = 'Present'
        }&#10;
        AppEnvironment ApiUrl {
            Name      = 'BINDERY_API_URL'
            Value     = 'https://api.bindery.example'
            Ensure    = 'Present'
            DependsOn = '[File]AppDirectory'
        }
    }
}&#10;
LegacyWebServer -AppRoot 'C:\BinderyApp' -OutputPath .\output
</code></pre>
<p>Keep this picture in your head, because each migration path transforms a different part of it: the <code>Configuration</code> keyword, the <code>Node</code> block, <code>Import-DscResource</code>, <code>Ensure</code> strings, and a compile step that produces <code>output\localhost.mof</code>.</p>
<h2 id="step-3-compile-and-apply">Step 3: Compile and apply</h2>
<p>In <strong>Windows PowerShell 5.1</strong> (not PowerShell 7):</p>
<pre><code class="language-powershell">powershell.exe -NoProfile -Command ".\LegacyWebServer.ps1"
</code></pre>
<p>You should now have <code>output\localhost.mof</code>. Apply it the classic way:</p>
<pre><code class="language-powershell">Start-DscConfiguration -Path .\output -Wait -Verbose -Force
</code></pre>
<p>Confirm the machine reached the desired state:</p>
<pre><code class="language-powershell">Test-DscConfiguration -Detailed
[Environment]::GetEnvironmentVariable('BINDERY_API_URL', 'Machine')
</code></pre>
<p>You now have a machine in a known-good state under the LCM. <strong>That state is your baseline.</strong> Every migration path in this course has to reproduce it exactly.</p>
<h2 id="step-4-build-the-inventory">Step 4: Build the inventory</h2>
<p>Save the inventory script from unit 3 as <code>Get-DscMigrationInventory.ps1</code> and run it from <strong>Windows PowerShell 5.1</strong>:</p>
<pre><code class="language-powershell">.\Get-DscMigrationInventory.ps1 | Format-Table -AutoSize
</code></pre>
<p>Look for the <code>BinderyOps/AppEnvironment</code> row and check three columns:</p>
<table>
<thead>
<tr>
<th>Column</th>
<th>Expected value</th>
<th>Why</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>Implementation</code></td>
<td><code>ScriptBased</code></td>
<td>It's a <code>Get</code>/<code>Set</code>/<code>Test-TargetResource</code> trio with a schema MOF</td>
</tr>
<tr>
<td><code>VisibleTo51</code></td>
<td><code>True</code></td>
<td>The Windows PowerShell adapter discovers script-based resources</td>
</tr>
<tr>
<td><code>VisibleToPs7</code></td>
<td><code>False</code></td>
<td>The PowerShell 7+ adapter supports class-based resources only</td>
</tr>
<tr>
<td><code>SuggestedPath</code></td>
<td><code>Adapt (5.1), consider class-based rewrite</code></td>
<td>Derived from the two visibility columns</td>
</tr>
</tbody>
</table>
<h2 id="step-5-confirm-the-adapter-views-by-hand">Step 5: Confirm the adapter views by hand</h2>
<p>Don't take the script's word for it. Ask each adapter directly:</p>
<pre><code class="language-powershell">dsc resource list --adapter Microsoft.Adapter/WindowsPowerShell | Select-String 'BinderyOps'
dsc resource list --adapter Microsoft.Adapter/PowerShell | Select-String 'BinderyOps'
</code></pre>
<p>The first returns a row. The second returns nothing. That asymmetry is the whole reason Path C exists.</p>
<h2 id="troubleshooting">Troubleshooting</h2>
<table>
<thead>
<tr>
<th>Symptom</th>
<th>Cause</th>
<th>Fix</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>Get-DscResource</code> doesn't list <code>AppEnvironment</code></td>
<td>The module isn't on 5.1's <code>$env:PSModulePath</code></td>
<td>Print <code>$env:PSModulePath</code> in Windows PowerShell and confirm the parent folder is listed</td>
</tr>
<tr>
<td><code>dsc resource list</code> returns nothing for either adapter</td>
<td>The adapters aren't installed, or <code>dsc</code> can't find them</td>
<td>Run <code>dsc resource list --adapter Microsoft.Adapter/WindowsPowerShell -l debug</code> and read the discovery trace</td>
</tr>
<tr>
<td>The schema MOF is rejected at compile time</td>
<td>File name or class name mismatch</td>
<td>The file must be <code>&lt;ResourceName&gt;.schema.mof</code> and the class name must match the folder name</td>
</tr>
<tr>
<td><code>Start-DscConfiguration</code> fails with an access error</td>
<td>Not elevated</td>
<td>Machine-level environment variables require administrator rights</td>
</tr>
</tbody>
</table>
<h2 id="check-your-work">Check your work</h2>
<p>You're ready for the next unit when all four statements are true:</p>
<ul>
<li>[ ] <code>output\localhost.mof</code> exists and was produced by your own compile step</li>
<li>[ ] <code>Test-DscConfiguration</code> reports <code>True</code></li>
<li>[ ] <code>BINDERY_API_URL</code> resolves to <code>https://api.bindery.example</code> at machine scope</li>
<li>[ ] Your inventory shows <code>BinderyOps/AppEnvironment</code> as visible to the 5.1 adapter only</li>
</ul>
<blockquote>
<p>[!TIP]<br>
Snapshot the VM here if you can. Every path in Module 2 starts from this exact state, and re-running the paths from a clean baseline is the fastest way to compare their results honestly.</p>
</blockquote>
