---
title: "Exercise: Convert a MOF file"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:06:20.000Z"
custom_template: "custom-lesson"
---

<p>Feed the MOF you compiled in Module 1 straight into the Microsoft DSC engine, then persist the conversion and review it against the four blind spots.</p>
<h2 id="prerequisites">Prerequisites</h2>
<ul>
<li><code>output\localhost.mof</code> from <a href="/courses/migrating-from-powershell-dsc/build-and-inventory-the-bindery-estate/">Module 1, unit 4</a></li>
<li>PowerShell 7.5+ (the <code>DSCSchemaBuilder</code> module requires it)</li>
<li>The <code>DSCSchemaBuilder</code> module installed</li>
</ul>
<pre><code class="language-powershell">Install-PSResource -Name DSCSchemaBuilder
Get-Command Convert-MofToDsc
</code></pre>
<h2 id="step-1-install-the-import-extension">Step 1: Install the import extension</h2>
<p>Create <code>moftodsc.dsc.extension.json</code>:</p>
<pre><code class="language-json">{
  "$schema": "https://aka.ms/dsc/schemas/v3/bundled/extension/manifest.json",
  "type": "DSC.Transitional/MofToDsc",
  "version": "0.1.0",
  "description": "Converts MOF configuration files to valid DSC configuration documents.",
  "import": {
    "fileExtensions": ["mof"],
    "executable": "pwsh",
    "args": [
      "-NoLogo",
      "-NonInteractive",
      "-NoProfile",
      "-Command",
      "./convert-mof.ps1",
      {
        "fileArg": "-Path"
      }
    ]
  }
}
</code></pre>
<p>And <code>convert-mof.ps1</code> beside it:</p>
<pre><code class="language-powershell"># convert-mof.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path
)&#10;
$ErrorActionPreference = 'Stop'&#10;
Convert-MofToDsc -Path $Path
</code></pre>
<p>Copy both next to the <code>dsc</code> executable, which is where DSC discovers extensions:</p>
<pre><code class="language-powershell">$installPath = Split-Path (Get-Command dsc).Path&#10;
Copy-Item -Path .\moftodsc.dsc.extension.json -Destination $installPath -Force
Copy-Item -Path .\convert-mof.ps1 -Destination $installPath -Force
</code></pre>
<p>Verify discovery:</p>
<pre><code class="language-powershell">dsc extension list |
    ConvertFrom-Json |
    Where-Object -Property type -eq 'DSC.Transitional/MofToDsc'
</code></pre>
<p>You should get one object back. If you get nothing, the manifest isn't where DSC is looking.</p>
<h2 id="step-2-translate-on-the-fly">Step 2: Translate on the fly</h2>
<p>Point the engine at a MOF file as though it were a configuration document:</p>
<pre><code class="language-powershell">dsc config test --file .\output\localhost.mof
</code></pre>
<p>The engine reports on <code>File</code> and <code>AppEnvironment</code>. Both should be in desired state, since the LCM converged this machine in Module 1.</p>
<p>Now watch the machinery:</p>
<pre><code class="language-powershell">dsc -l debug config test --file .\output\localhost.mof
</code></pre>
<p>In the debug trace, find three things:</p>
<ul>
<li>[ ] The <code>.mof</code> file extension being matched to <code>DSC.Transitional/MofToDsc</code></li>
<li>[ ] The <code>pwsh</code> process being launched with <code>-Path</code> and the absolute MOF path</li>
<li>[ ] The JSON document coming back on stdout, before any resource is invoked</li>
</ul>
<p>That third one is the point of the exercise. By the time the engine starts working, the MOF is gone and what remains is a document like any other.</p>
<h2 id="step-3-persist-the-conversion">Step 3: Persist the conversion</h2>
<p>On-the-fly translation is a diagnostic. Now produce something you'd commit:</p>
<pre><code class="language-powershell">Convert-MofToDsc -Path .\output\localhost.mof |
    Out-File .\webserver-imported.dsc.config.json
</code></pre>
<p>Open the result. You'll see a configuration document with:</p>
<ul>
<li><code>$schema</code> pointing at the DSC config document schema</li>
<li>A <code>resources</code> array with one entry per MOF instance</li>
<li>Types like <code>PSDesiredStateConfiguration/File</code> and <code>BinderyOps/AppEnvironment</code></li>
<li><code>dependsOn</code> expressed with <code>resourceId()</code> instead of <code>DependsOn = '[File]AppDirectory'</code></li>
<li>No <code>SourceInfo</code>, no <code>ConfigurationName</code>, no compilation metadata</li>
</ul>
<p>Test the persisted document to confirm nothing was lost in the round trip:</p>
<pre><code class="language-powershell">dsc config test --file .\webserver-imported.dsc.config.json
</code></pre>
<h2 id="step-4-review-against-the-four-blind-spots">Step 4: Review against the four blind spots</h2>
<p>Work the checklist against your generated document. For the Bindery estate, three of the four are clean and one needs thought:</p>
<table>
<thead>
<tr>
<th>Blind spot</th>
<th>In this document</th>
<th>Action</th>
</tr>
</thead>
<tbody>
<tr>
<td>Credentials dropped</td>
<td>No <code>MSFT_Credential</code> instances in the MOF</td>
<td>Nothing to do, but note <em>where</em> you'd check</td>
</tr>
<tr>
<td>Node names vanished</td>
<td>The MOF was compiled for <code>localhost</code> only</td>
<td>Nothing to do here, but a real estate needs parameters</td>
</tr>
<tr>
<td>Composites flattened</td>
<td>No composites in this configuration</td>
<td>Nothing to do</td>
</tr>
<tr>
<td>Ordering became explicit</td>
<td><code>DependsOn</code> was explicit in the source script, so it survived</td>
<td>Verify the <code>resourceId()</code> reference points at the right type and name</td>
</tr>
</tbody>
</table>
<p>Now create the problem deliberately, because you won't recognize it in production otherwise. Edit <code>LegacyWebServer.ps1</code>, <strong>remove</strong> the <code>DependsOn</code> line from the <code>AppEnvironment</code> block, recompile in Windows PowerShell, and convert again:</p>
<pre><code class="language-powershell">Convert-MofToDsc -Path .\output\localhost.mof |
    Out-File .\webserver-imported-nodeps.dsc.config.json
</code></pre>
<p>Compare the two documents. The second has no <code>dependsOn</code> at all. The ordering the LCM gave you implicitly is simply absent, and nothing warns you. That's blind spot four, and finding it in a lab is much cheaper than finding it on a node where the directory has to exist before the variable is set.</p>
<h2 id="step-5-compare-against-your-hand-written-document">Step 5: Compare against your hand-written document</h2>
<p>You now have two documents describing the same desired state: <code>webserver-adapted.dsc.config.yaml</code> (hand-written in unit 3) and <code>webserver-imported.dsc.config.json</code> (generated here).</p>
<pre><code class="language-powershell">dsc config test --file .\webserver-adapted.dsc.config.yaml
dsc config test --file .\webserver-imported.dsc.config.json
</code></pre>
<p>Both should agree with the machine. Then read them side by side and note what the converter couldn't know:</p>
<ul>
<li>It has no parameters, while the hand-written version has <code>appRoot</code> because you knew that value varied</li>
<li>Resource names come from MOF <code>ResourceID</code> values, which read like <code>[File]AppDirectory</code> rather than something a human chose</li>
<li>There's no schema comment for editor IntelliSense</li>
</ul>
<p>None of that is a defect. It's the line between what a converter can infer and what a person has to decide, and knowing where that line sits is the reason you converted a MOF you didn't need to convert.</p>
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
<td><code>dsc extension list</code> doesn't show the extension</td>
<td>Manifest not next to the <code>dsc</code> executable</td>
<td>Re-run the copy step and confirm with <code>Split-Path (Get-Command dsc).Path</code></td>
</tr>
<tr>
<td>Extension found but conversion fails</td>
<td><code>pwsh</code> can't find <code>convert-mof.ps1</code>, or <code>DSCSchemaBuilder</code> isn't installed for that host</td>
<td>Run <code>pwsh -NoProfile -Command "Get-Command Convert-MofToDsc"</code></td>
</tr>
<tr>
<td>Converted document has no <code>dependsOn</code></td>
<td>The source MOF had no explicit <code>DependsOn</code></td>
<td>Expected. Add ordering by hand (see step 4)</td>
</tr>
<tr>
<td><code>Convert-MofToDsc</code> throws a parse error</td>
<td>The MOF contains credential or encrypted blocks</td>
<td>Re-model those properties as <code>secureString</code> parameters, as described in Module 3, unit 5</td>
</tr>
</tbody>
</table>
<h2 id="check-your-work">Check your work</h2>
<ul>
<li>[ ] <code>dsc config test --file .\output\localhost.mof</code> returns resource results, not a file-type error</li>
<li>[ ] The debug trace shows the extension being selected and <code>pwsh</code> being invoked</li>
<li>[ ] <code>webserver-imported.dsc.config.json</code> exists and passes <code>dsc config test</code></li>
<li>[ ] You've seen a converted document that lost implicit ordering, and you know how to spot it</li>
</ul>
