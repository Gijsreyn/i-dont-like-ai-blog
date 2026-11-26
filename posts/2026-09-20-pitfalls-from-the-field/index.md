---
title: "Pitfalls from the field"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:13:59.000Z"
custom_template: "custom-lesson"
---

<p>A few failure modes come up in nearly every migration. Naming them is cheaper than discovering them.</p>
<h2 id="module-path-confusion-between-hosts">Module path confusion between hosts</h2>
<p><strong>What it looks like:</strong> A resource works perfectly in PowerShell, and <code>dsc resource list</code> insists it doesn't exist. Or worse, DSC finds it but applies properties that seem to be ignored.</p>
<p><strong>What's actually happening:</strong> Windows PowerShell, PowerShell 7, and the adapters each resolve module paths independently. A module installed for one host is invisible to another, and two versions of the same module in two paths produce the "properties ignored" variant, because you're testing one version and running another.</p>
<p><strong>The fix:</strong> When discovery misbehaves, print <code>$env:PSModulePath</code> from <em>both</em> hosts before doing anything else.</p>
<pre><code class="language-powershell"># Windows PowerShell 5.1
powershell.exe -NoProfile -Command '$env:PSModulePath -split ";"'&#10;
# PowerShell 7
pwsh -NoProfile -Command '$env:PSModulePath -split [IO.Path]::PathSeparator'
</code></pre>
<p>Then confirm which copy is actually being loaded:</p>
<pre><code class="language-powershell">Get-Module BinderyOps -ListAvailable | Select-Object Name, Version, ModuleBase
</code></pre>
<p>This is the single most common source of "it works in PowerShell but DSC can't find it" reports, and it costs teams hours because the symptom points at DSC while the cause is a path.</p>
<h2 id="testing-only-the-happy-path">Testing only the happy path</h2>
<p><strong>What it looks like:</strong> A rewritten resource passes its tests, ships, and fails three weeks later on a node that's slightly different.</p>
<p><strong>What's actually happening:</strong> Legacy resources often encode years of edge-case handling in <code>Set-TargetResource</code>: a retry around a flaky API, a guard for a path that only exists on domain controllers, a workaround for a bug fixed in 2019. The mechanical translation from functions to methods moves the structure. It doesn't tell you which branches still matter.</p>
<p><strong>The fix:</strong> When rewriting to class-based, <strong>port the tests before the code</strong>, or write the tests that never existed. The <code>dsc resource test --resource &lt;type&gt; --input &lt;json&gt;</code> invocation makes per-resource verification cheap:</p>
<pre><code class="language-powershell">$cases = @(
    @{ Name = 'BINDERY_API_URL'; Value = 'https://api.bindery.example'; Expect = $true }
    @{ Name = 'BINDERY_API_URL'; Value = 'https://wrong.example';       Expect = $false }
    @{ Name = 'BINDERY_MISSING'; Ensure = 'Absent';                     Expect = $true }
)&#10;
foreach ($case in $cases) {
    $expect = $case['Expect']
    $case.Remove('Expect')&#10;
    $json = $case | ConvertTo-Json -Compress
    $actual = (dsc resource test --resource BinderyOps/AppEnvironment --input $json |
        ConvertFrom-Json).inDesiredState&#10;
    [PSCustomObject]@{
        Case   = $json
        Expect = $expect
        Actual = $actual
        Pass   = ($expect -eq $actual)
    }
}
</code></pre>
<h2 id="migrating-the-schedule-last">Migrating the schedule last</h2>
<p><strong>What it looks like:</strong> Documents migrated, resources migrated, victory declared. Then a setting flaps between two values, and every run of both engines reports success.</p>
<p><strong>What's actually happening:</strong> The LCM is still running on the old cadence, fighting the new tooling for ownership of the same settings. Both engines converge the machine to their own desired state, and each one correctly reports that it succeeded.</p>
<p><strong>The fix:</strong> Disable the LCM's configuration, or set it to <code>ApplyOnly</code> with an empty configuration, <strong>the moment</strong> Microsoft DSC takes over enforcement on a node. Not the same sprint. The same change.</p>
<pre><code class="language-powershell">Remove-DscConfigurationDocument -Stage Current, Pending, Previous -Force
</code></pre>
<p>Treat "which engine owns this node" as a binary with no overlap, and make the transition a single step in a runbook.</p>
<h2 id="big-bang-conversions">Big-bang conversions</h2>
<p><strong>What it looks like:</strong> A weekend spent converting four hundred MOFs, followed by a Monday spent discovering that nobody can review four hundred unreviewed documents.</p>
<p><strong>What's actually happening:</strong> Mechanical conversion scales beautifully and review doesn't. The four blind spots (credentials, node names, composites, implicit ordering) each need a human decision, and four hundred pending decisions is not a backlog, it's a wall.</p>
<p><strong>The fix:</strong> Convert <strong>per service</strong>. Verify with <code>dsc config test</code> against live systems. Let each converted document earn its way into the repository by proving it agrees with a running machine.</p>
<p>Progress feels slower and is faster, because nothing has to be revisited.</p>
<h2 id="three-more-worth-knowing">Three more worth knowing</h2>
<p><strong>Assuming <code>LastTaskResult = 0</code> means converged.</strong> A scheduled task's exit code tells you the process ran, not that the configuration succeeded. Capture the JSON output, or you've replaced the LCM's reporting with nothing.</p>
<p><strong>Forgetting that the 5.1 adapter runs .NET Framework.</strong> A script resource under <code>Microsoft.Adapter/WindowsPowerShell</code> still sees .NET Framework, not .NET. If it works in both hosts today, that's luck. Script-based resources are supported only through the Windows PowerShell adapter.</p>
<p><strong>Carrying secrets across.</strong> Any password that lived in a plaintext MOF is burned. The migration touches every configuration anyway, which makes it the cheapest rotation opportunity you'll ever get. Take it.</p>
<blockquote>
<p>[!TIP]<br>
Turn this unit into a pre-cutover checklist for your own runbook. Every item here has cost someone a day. Most of them cost nothing to check.</p>
</blockquote>
