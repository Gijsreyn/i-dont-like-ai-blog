---
title: "Inventory what you have"
status: published
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-19T04:01:51.000Z"
custom_template: "custom-lesson"
---

<p>You can't plan a migration without knowing what you're migrating. "We should move to Microsoft DSC someday" is not a plan. But a spreadsheet with so many rows and a decision in each one is.</p>
<p>A PowerShell DSC estate typically contains four kinds of artifacts, and each one migrates differently.</p>
<h2 id="the-four-artifact-types">The four artifact types</h2>
<table>
<thead>
<tr>
<th>Artifact</th>
<th>What it looks like</th>
<th>Migration concern</th>
</tr>
</thead>
<tbody>
<tr>
<td>Configuration scripts</td>
<td><code>.ps1</code> files using the <code>Configuration</code> keyword</td>
<td>Rewrite as configuration documents (or import MOF)</td>
</tr>
<tr>
<td>Compiled MOF files</td>
<td><code>localhost.mof</code>, <code>webserver01.mof</code> on pull servers</td>
<td>Import extension translates them</td>
</tr>
<tr>
<td>Script-based resources</td>
<td>Modules with <code>Get</code>/<code>Set</code>/<code>Test-TargetResource</code> functions</td>
<td>Run via the 5.1 adapter, or rewrite as class-based</td>
</tr>
<tr>
<td>Class-based resources</td>
<td>PowerShell classes with <code>Get()</code>, <code>Set()</code>, <code>Test()</code></td>
<td>Run via either adapter, mostly as-is</td>
</tr>
</tbody>
</table>
<p>Start with the <strong>resources</strong>, because everything else depends on them. A configuration you can't run is a configuration whose resources didn't migrate.</p>
<h2 id="enumerate-what-powershell-dsc-sees">Enumerate what PowerShell DSC sees</h2>
<p>On a machine with your modules installed, the classic enumeration is:</p>
<pre><code class="language-powershell">Get-DscResource | Select-Object Name, ModuleName, Version, ImplementationDetail
</code></pre>
<p>The <code>ImplementationDetail</code> property is the important one:</p>
<ul>
<li><strong><code>ScriptBased</code></strong> — the module implements the <code>Get-TargetResource</code>, <code>Set-TargetResource</code>, and <code>Test-TargetResource</code> function trio alongside a schema MOF file.</li>
<li><strong><code>ClassBased</code></strong> — it's a PowerShell class decorated with <code>[DscResource()]</code>.</li>
<li><strong>Composite resources</strong> — configurations packaged as resources. They show up too, and they need special handling covered in Module 2.</li>
</ul>
<blockquote>
<p>[!NOTE]<br>
Run this in <strong>Windows PowerShell 5.1</strong>, not PowerShell 7. <code>Get-DscResource</code> in PowerShell 7 comes from a different module version and enumerates a different set. For inventory purposes you want the 5.1 view, because that's the view the LCM has been using.</p>
</blockquote>
<h2 id="ask-the-same-question-from-the-other-side">Ask the same question from the other side</h2>
<p>Now find out what Microsoft DSC can already see. The adapters perform this discovery for you:</p>
<pre><code class="language-powershell">dsc resource list --adapter Microsoft.Adapter/WindowsPowerShell
dsc resource list --adapter Microsoft.Adapter/PowerShell
</code></pre>
<p>The first command lists everything the Windows PowerShell 5.1 adapter can find — script-based <em>and</em> class-based resources. The second lists what the PowerShell 7+ adapter can find, which is <strong>class-based resources only</strong>.</p>
<p>That difference is the entire inventory in one line:</p>
<ul>
<li>The 5.1 adapter maintains full backwards compatibility with script-based resources.</li>
<li>The PowerShell 7+ adapter deliberately supports only class-based resources.</li>
</ul>
<p><strong>If a resource shows up in the first list but not the second, you've found a migration decision point.</strong></p>
<p><img src="https://storage.ghost.io/c/dd/64/dd64ba9d-7bdd-441e-bb5f-13f8be709814/content/images/2026/09/adapter-visibility-venn.png" alt="Figure 1: The gap between the two adapter views is your Path C backlog." loading="lazy"></p>
<h2 id="make-the-inventory-systematic">Make the inventory systematic</h2>
<p>Comparing two console outputs by eye works for ten resources and fails for a hundred. The following script joins both views into a single migration-oriented report. Save it as <code>Get-DscMigrationInventory.ps1</code>.</p>
<pre><code class="language-powershell"># Get-DscMigrationInventory.ps1
[CmdletBinding()]
param()&#10;
$legacy = Get-DscResource -ErrorAction SilentlyContinue&#10;
$adapted = dsc resource list --adapter Microsoft.Adapter/WindowsPowerShell --output-format json |
    ConvertFrom-Json&#10;
$adaptedPs7 = dsc resource list --adapter Microsoft.Adapter/PowerShell --output-format json |
    ConvertFrom-Json&#10;
foreach ($resource in $legacy) {
    $moduleName = if ($resource.ModuleName) { $resource.ModuleName } else { '(binary)' }
    $adaptedType = '{0}/{1}' -f $moduleName, $resource.Name&#10;
    [PSCustomObject]@{
        Resource        = $adaptedType
        Implementation  = $resource.ImplementationDetail
        VisibleTo51     = ($adapted.type -contains $adaptedType)
        VisibleToPs7    = ($adaptedPs7.type -contains $adaptedType)
        SuggestedPath   = if ($adaptedPs7.type -contains $adaptedType) {
            'Adapt (PowerShell 7+)'
        } elseif ($adapted.type -contains $adaptedType) {
            'Adapt (5.1), consider class-based rewrite'
        } else {
            'Investigate: not discovered by any adapter'
        }
    }
}
</code></pre>
<blockquote>
<p>[!NOTE]<br>
This is the same inventory script used in <em>The Microsoft DSC Handbook</em>, Chapter 11. If you own the book, you'll recognize it; if you don't, the script above is complete and you don't need anything else.</p>
</blockquote>
<p>Read the script in three parts:</p>
<ol>
<li><strong><code>$legacy</code></strong> is the classic view with every resource Windows PowerShell can find on <code>$env:PSModulePath</code>.</li>
<li><strong><code>$adapted</code> and <code>$adaptedPs7</code></strong> are the two adapter views, requested as JSON so they can be queried rather than read.</li>
<li><strong>The loop</strong> builds the <code>Module/Resource</code> type string that a configuration document would use, then checks it against both adapter views.</li>
</ol>
<p>Run it and you get a table that classifies every resource on the machine:</p>
<pre><code class="language-text">Resource                                Implementation VisibleTo51 VisibleToPs7 SuggestedPath
--------                                -------------- ----------- ------------ -------------
BinderyOps/AppEnvironment               ScriptBased    True        False        Adapt (5.1), consider class-based rewrite
PSDesiredStateConfiguration/File        Binary         True        False        Adapt (5.1), consider class-based rewrite
BinderyOps/AppRegistration              ClassBased     True        True         Adapt (PowerShell 7+)
</code></pre>
<p>The <code>SuggestedPath</code> column is a <strong>starting point, not a verdict</strong>. A resource that the PowerShell 7+ adapter can see might still deserve a native rewrite; a resource stuck on 5.1 might be scheduled for deletion instead. But the column turns a vague intention into a concrete list you can walk through in a planning meeting.</p>
<blockquote>
<p>[!WARNING]<br>
<code>Get-DscResource</code> in Windows PowerShell enumerates from <code>$env:PSModulePath</code> as seen by 5.1, while <code>dsc resource list</code> goes through the adapter's own discovery. If the two disagree on what exists, check which module paths each host sees <em>before</em> assuming a resource is broken. This is by far the most common source of "it works in PowerShell but DSC can't find it" reports.</p>
</blockquote>
<h2 id="inventory-the-rest-of-the-estate">Inventory the rest of the estate</h2>
<p>Resources are the hard part, but three more sweeps complete the picture:</p>
<p><strong>Configuration scripts.</strong> Search your repositories for the <code>Configuration</code> keyword:</p>
<pre><code class="language-powershell">Get-ChildItem -Path .\ -Filter *.ps1 -Recurse |
    Select-String -Pattern '^\s*Configuration\s+\w+' |
    Select-Object Path, Line
</code></pre>
<p>For each hit, record which resources it imports and whether the script is still the source of truth for a compiled MOF somewhere.</p>
<p><strong>Compiled MOFs.</strong> On a pull server, the configuration store is the authoritative list. Locally, they're wherever your build wrote them:</p>
<pre><code class="language-powershell">Get-ChildItem -Path .\ -Filter *.mof -Recurse |
    Select-Object FullName, LastWriteTime, Length
</code></pre>
<p>The <code>LastWriteTime</code> matters more than you'd expect. A MOF compiled four years ago whose source script no longer exists is a Path B candidate. A MOF regenerated by last night's build is a Path A candidate and plan to migrate the script instead.</p>
<p><strong>Hidden cross-node dependencies.</strong> These bite late, so find them early:</p>
<pre><code class="language-powershell">Get-ChildItem -Path .\ -Filter *.ps1 -Recurse |
    Select-String -Pattern 'WaitFor(All|Any|Some)'
</code></pre>
<p>Every hit is a piece of orchestration logic that has no direct equivalent in Microsoft DSC. Module 3 explains what to do with them. For now, just know they exist.</p>
<h2 id="what-good-looks-like">What good looks like</h2>
<p>A finished inventory answers four questions for every row:</p>
<ol>
<li><strong>What is it?</strong> Artifact type and implementation detail.</li>
<li><strong>Who owns it?</strong> A team name, not "operations."</li>
<li><strong>Is it still used?</strong> Last applied, last compiled, last modified.</li>
<li><strong>Which path?</strong> One of the four you'll meet in unit 5.</li>
</ol>
<p>The fourth column is the one this course exists to fill. The first three are yours, and they're worth more than they look: a surprising share of every real migration is deleting things nobody had the authority to delete before.</p>
