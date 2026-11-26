---
title: "Exercise: Prove equivalence end to end"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:13:42.000Z"
custom_template: "custom-lesson"
---

<p>In this exercise, you'll run all three migration routes against the same machine, prove they agree, hand enforcement to a schedule you own, and retire the LCM.</p>
<h2 id="what-you-should-have">What you should have</h2>
<p>From Modules 1 and 2:</p>
<table>
<thead>
<tr>
<th>Artifact</th>
<th>Route</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>output\localhost.mof</code></td>
<td>Legacy, translated live by the import extension (Path B)</td>
</tr>
<tr>
<td><code>webserver-imported.dsc.config.json</code></td>
<td>Persisted conversion (Path B)</td>
</tr>
<tr>
<td><code>webserver-adapted.dsc.config.yaml</code></td>
<td>Hand-written document, 5.1 adapter (Path A)</td>
</tr>
<tr>
<td><code>webserver-ps7.dsc.config.yaml</code></td>
<td>Same document, PowerShell 7 adapter (Path C)</td>
</tr>
</tbody>
</table>
<p>And a machine converged by the LCM, with <code>BINDERY_API_URL</code> set at machine scope.</p>
<h2 id="step-1-the-four-way-equivalence-check">Step 1: The four-way equivalence check</h2>
<p>Run every route against the same machine:</p>
<pre><code class="language-powershell">$routes = @(
    @{ Name = 'MOF (live import)';  File = '.\output\localhost.mof' }
    @{ Name = 'MOF (persisted)';    File = '.\webserver-imported.dsc.config.json' }
    @{ Name = 'Adapted (5.1)';      File = '.\webserver-adapted.dsc.config.yaml' }
    @{ Name = 'Adapted (PS7)';      File = '.\webserver-ps7.dsc.config.yaml' }
)&#10;
foreach ($route in $routes) {
    $result = dsc config test --file $route.File --output-format json | ConvertFrom-Json&#10;
    foreach ($resource in $result.results) {
        [PSCustomObject]@{
            Route          = $route.Name
            Resource       = $resource.name
            InDesiredState = $resource.result.inDesiredState
            Differing      = ($resource.result.differingProperties -join ', ')
        }
    }
}
</code></pre>
<p>Format it as a table:</p>
<pre><code class="language-text">Route              Resource     InDesiredState Differing
-----              --------     -------------- ---------
MOF (live import)  AppDirectory True
MOF (live import)  ApiUrl       True
MOF (persisted)    AppDirectory True
MOF (persisted)    ApiUrl       True
Adapted (5.1)      AppDirectory True
Adapted (5.1)      ApiUrl       True
Adapted (PS7)      AppDirectory True
Adapted (PS7)      ApiUrl       True
</code></pre>
<p><strong>Every route agrees with the machine, and therefore with each other.</strong> That's the proof that the migration preserved behavior.</p>
<p>If any row disagrees, you've found exactly the kind of translation drift this exercise exists to catch. Diagnose it with <code>differingProperties</code>, which names the offending property directly.</p>
<blockquote>
<p>[!TIP]<br>
Keep this script. Run it after every batch of documents you migrate in your real estate. It's ten lines and it's the difference between "we think the migration is faithful" and "here is the table."</p>
</blockquote>
<h2 id="step-2-prove-the-check-can-fail">Step 2: Prove the check can fail</h2>
<p>A test that always passes proves nothing. Break the state and re-run:</p>
<pre><code class="language-powershell">[Environment]::SetEnvironmentVariable('BINDERY_API_URL', 'https://drifted.example', 'Machine')
</code></pre>
<p>Re-run the loop from step 1. Every route should now report <code>ApiUrl</code> as <code>False</code> with <code>Value</code> in <code>Differing</code>. Four independent implementations detecting the same drift is a stronger signal than any one of them passing.</p>
<p>Converge with the route you intend to keep:</p>
<pre><code class="language-powershell">dsc config set --file .\webserver-ps7.dsc.config.yaml
</code></pre>
<p>Re-run the loop. All four routes report <code>True</code> again.</p>
<h2 id="step-3-capture-a-baseline-of-the-lcms-settings">Step 3: Capture a baseline of the LCM's settings</h2>
<p>Before disabling anything, record what the old system was doing:</p>
<pre><code class="language-powershell">Get-DscLocalConfigurationManager |
    Select-Object ConfigurationMode, ConfigurationModeFrequencyMins,
                  RefreshMode, RebootNodeIfNeeded, CertificateID |
    Export-Csv -Path .\lcm-baseline.csv -NoTypeInformation
</code></pre>
<p>For the Bindery lab, <code>ConfigurationMode</code> is likely <code>ApplyAndMonitor</code> (the default) unless you set otherwise. Note the value — it determines whether your replacement schedules <code>test</code> or <code>set</code>.</p>
<h2 id="step-4-retire-the-lcm-on-this-node">Step 4: Retire the LCM on this node</h2>
<p>Verify one more time, then stop the old engine from enforcing:</p>
<pre><code class="language-powershell"># 1. Verify
dsc config test --file .\webserver-ps7.dsc.config.yaml&#10;
# 2. Remove the LCM's configuration documents
Remove-DscConfigurationDocument -Stage Current, Pending, Previous -Force&#10;
# 3. Confirm nothing is left to enforce
Get-DscConfigurationStatus -ErrorAction SilentlyContinue
</code></pre>
<p>Step 3 should report that no configuration status is available because there's nothing for the LCM to do.</p>
<blockquote>
<p>[!WARNING]<br>
Order matters. Verifying <em>before</em> removing means that if the new route turns out to be wrong, the old engine is still there. Removing first and discovering a problem afterward means an unmanaged node and an awkward hour.</p>
</blockquote>
<h2 id="step-5-hand-enforcement-to-your-own-schedule">Step 5: Hand enforcement to your own schedule</h2>
<p>Register the replacement:</p>
<pre><code class="language-powershell">$action = New-ScheduledTaskAction `
    -Execute 'dsc.exe' `
    -Argument "config set --file $PWD\webserver-ps7.dsc.config.yaml"&#10;
$trigger = New-ScheduledTaskTrigger `
    -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 15)&#10;
Register-ScheduledTask `
    -TaskName 'BinderyDscEnforcement' `
    -TaskPath '\DSC\' `
    -Action $action `
    -Trigger $trigger `
    -User 'SYSTEM' `
    -RunLevel Highest
</code></pre>
<p>Force a run rather than waiting, and read the result:</p>
<pre><code class="language-powershell">Start-ScheduledTask -TaskName 'BinderyDscEnforcement' -TaskPath '\DSC\'
Get-ScheduledTaskInfo -TaskName 'BinderyDscEnforcement' -TaskPath '\DSC\' |
    Select-Object LastRunTime, LastTaskResult
</code></pre>
<p><code>LastTaskResult</code> of <code>0</code> means the task ran. It does <strong>not</strong> mean the configuration converged. For that, you need the captured output.</p>
<h2 id="step-6-capture-the-results">Step 6: Capture the results</h2>
<p>Replace the task's command with a wrapper that records what happened. Create <code>Invoke-BinderyEnforcement.ps1</code>:</p>
<pre><code class="language-powershell">[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigurationFile,&#10;
    [string]$LogFolder = 'C:\BinderyOps\logs'
)&#10;
$ErrorActionPreference = 'Stop'
New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null&#10;
$result = dsc config set --file $ConfigurationFile --output-format json | ConvertFrom-Json&#10;
$stamp = Get-Date -Format 'yyyy-MM-ddTHH-mm-ss'
$result | ConvertTo-Json -Depth 20 | Out-File (Join-Path $LogFolder "run-$stamp.json")&#10;
$drifted = $result.results |
    Where-Object { $_.result.afterState -and -not $_.result.inDesiredState } |
    Select-Object -ExpandProperty name&#10;
if ($result.hadErrors) {
    Write-Error "DSC enforcement reported errors. See run-$stamp.json"
} elseif ($drifted) {
    Write-Warning "Corrected drift on: $($drifted -join ', ')"
}
</code></pre>
<p>Point the task at it, run it twice, and compare the two JSON files. The first shows resources being corrected if anything drifted. The second shows a converged machine. That folder of timestamped results is your replacement for <code>Get-DscConfigurationStatus</code>. It's also more useful, because you can ship it anywhere and read it without a CIM session.</p>
<h2 id="step-7-confirm-the-end-state">Step 7: Confirm the end state</h2>
<p>Leave the lab in a state you can describe in one sentence:</p>
<pre><code class="language-powershell"># The LCM has nothing to enforce
Get-DscConfigurationStatus -ErrorAction SilentlyContinue&#10;
# A schedule you own is enforcing the migrated document
Get-ScheduledTaskInfo -TaskName 'BinderyDscEnforcement' -TaskPath '\DSC\'&#10;
# The migrated document agrees with the machine
dsc config test --file .\webserver-ps7.dsc.config.yaml&#10;
# And the results are being recorded
Get-ChildItem C:\BinderyOps\logs
</code></pre>
<h2 id="check-your-work">Check your work</h2>
<ul>
<li>[ ] All four routes reported the machine in desired state</li>
<li>[ ] Deliberate drift was detected by all four routes, with the same property named</li>
<li>[ ] The LCM baseline is recorded in <code>lcm-baseline.csv</code></li>
<li>[ ] <code>Remove-DscConfigurationDocument</code> ran, and the LCM has nothing left to enforce</li>
<li>[ ] A scheduled task runs <code>dsc config set</code> on an interval you chose</li>
<li>[ ] Each run writes a timestamped JSON result you can read</li>
</ul>
<p>You've now migrated an estate end to end: inventory, four paths, LCM replacement, and verification. The estate was small on purpose. The drill is the same at four hundred nodes. Only the loop gets longer.</p>
