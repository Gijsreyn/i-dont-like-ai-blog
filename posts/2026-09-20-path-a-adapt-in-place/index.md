---
title: "Path A: Adapt in place"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:04:29.000Z"
custom_template: "custom-lesson"
---

<p>The least nosy move is to stop compiling MOFs and start writing configuration documents, while the resources underneath stay untouched.</p>
<p>Nothing about the resource changes. The same module, the same functions, the same properties. What changes is the envelope: instead of the LCM reading a compiled MOF, the Microsoft DSC engine reads a document and calls the resource through an adapter.</p>
<p>Because you're migrating rather than authoring fresh, the goal is sharper than "write a document that works." The goal is <strong>behavioral equivalence</strong> with the legacy configuration, meaning the same resources, same properties, same order, same result.</p>
<h2 id="the-translation">The translation</h2>
<p>Here's the legacy configuration from Module 1:</p>
<pre><code class="language-powershell">Configuration LegacyWebServer {
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
}
</code></pre>
<p>And here's the same intent as a configuration document for Microsoft DSC's engine:</p>
<pre><code class="language-yaml"># yaml-language-server: $schema=https://aka.ms/dsc/schemas/v3/bundled/config/document.json
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
parameters:
  appRoot:
    type: string
    defaultValue: C:\BinderyApp
resources:
  - name: AppDirectory
    type: PSDesiredStateConfiguration/File
    directives:
      requireAdapter: Microsoft.Adapter/WindowsPowerShell
    properties:
      DestinationPath: "[parameters('appRoot')]"
      Type: Directory
      Ensure: Present
  - name: ApiUrl
    type: BinderyOps/AppEnvironment
    directives:
      requireAdapter: Microsoft.Adapter/WindowsPowerShell
    dependsOn:
      - "[resourceId('PSDesiredStateConfiguration/File', 'AppDirectory')]"
    properties:
      Name: BINDERY_API_URL
      Value: https://api.bindery.example
      Ensure: Present
</code></pre>
<h2 id="what-happened-to-each-construct">What happened to each construct</h2>
<p>Let's look at the following table to see what each construct looks like:</p>
<table>
<thead>
<tr>
<th>Legacy construct</th>
<th>Configuration document equivalent</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>Configuration</code> + compile step</td>
<td>The YAML file itself without the need for compilation</td>
</tr>
<tr>
<td><code>param()</code> block</td>
<td><code>parameters</code> section with typed parameters</td>
</tr>
<tr>
<td><code>Import-DscResource -ModuleName X</code></td>
<td>Resource <code>type</code> prefixed with the module name, plus the <code>requireAdapter</code> directive</td>
</tr>
<tr>
<td><code>Node 'localhost'</code></td>
<td>Nothing</td>
</tr>
<tr>
<td><code>DependsOn = '[File]AppDirectory'</code></td>
<td><code>dependsOn</code> with the <code>resourceId()</code> function</td>
</tr>
<tr>
<td>Implicit LCM invocation</td>
<td><code>dsc config set --file webserver-adapted.dsc.config.yaml</code></td>
</tr>
</tbody>
</table>
<p>Four of these deserve a second look.</p>
<ol>
<li><strong>The compile step is gone.</strong> There's no intermediate artifact. The document you commit is the document the engine reads, which means a code review of the document is a code review of what will actually run</li>
<li><strong><code>Node</code> has no equivalent, deliberately.</strong> A  MOF is compiled <em>per node</em>, whereas a document is node-agnostic. The document applies wherever you invoke it. If you had per-node variations, they become parameters, and the node identity moves up into whatever invokes the engine.</li>
<li><strong><code>requireAdapter</code> is the whole trick.</strong> It tells the engine "this resource type isn't native, but instead, route it through this adapter." Without it, the engine looks for a native resource named <code>BinderyOps/AppEnvironment</code>.</li>
<li><strong>The resource properties pass through unchanged.</strong> <code>DestinationPath</code>, <code>Ensure</code>, <code>Name</code>, and <code>Value</code> are identical, because the same module code receives them. That's the entire point of Path A: the contract between you and the resource is preserved, only the envelope changed.</li>
</ol>
<blockquote>
<p>[!NOTE]<br>
The <code># yaml-language-server:</code> comment on the first line isn't decoration. It gives editors with a YAML language server full IntelliSense and validation against the DSC schema, which catches misspelled keys before you run anything.</p>
</blockquote>
<h2 id="test-the-equivalence-before-trusting-it">Test the equivalence before trusting it</h2>
<pre><code class="language-powershell">dsc config test --file .\webserver-adapted.dsc.config.yaml
</code></pre>
<p>If the machine was in its desired state under the LCM, <code>inDesiredState</code> should report <code>true</code> for both resources.</p>
<p>If it doesn't, the <code>differingProperties</code> array tells you exactly which property translated wrong:</p>
<pre><code class="language-yaml">results:
- name: ApiUrl
  type: BinderyOps/AppEnvironment
  result:
    desiredState:
      Name: BINDERY_API_URL
      Value: https://api.bindery.example
    actualState:
      Name: BINDERY_API_URL
      Value: https://api-staging.bindery.example
    inDesiredState: false
    differingProperties:
    - Value
</code></pre>
<p>Think about it as your safety net for your mirgration. Module 3 turns it into an automated gate.</p>
<blockquote>
<p>[!TIP]<br>
Run <code>dsc config test</code> <strong>before</strong> you ever run <code>dsc config set</code> with a migrated document. On a machine the LCM already converged, a passing test proves your translation is faithful without changing anything. A failing test costs you nothing but the time to read it.</p>
</blockquote>
<h2 id="pinning-versions-during-migration">Pinning versions during migration</h2>
<p>One thing the LCM did implicitly was module version resolution from its own module path. When the adapter discovers multiple versions of a module, be explicit rather than lucky.</p>
<p>The adapted resource <code>type</code> doesn't carry a version. Your options, in order of preference:</p>
<ol>
<li><strong>Control which module versions are installed on the target.</strong> One version on the box is one version discovered.</li>
<li><strong>Clean <code>$env:PSModulePath</code></strong> during the migration window where old and new versions coexist, rather than hoping discovery picks the right one.</li>
<li><strong>Require a version in the properties</strong> passed to class-based resources that support it.</li>
</ol>
<blockquote>
<p>[!WARNING]<br>
The 5.1 adapter runs resources in Windows PowerShell, which means your resource still sees .NET Framework, not .NET. If a script resource happens to work in both hosts today, don't let that tempt you into pointing the PowerShell 7+ adapter at it. Script-based resources are supported only through <code>Microsoft.Adapter/WindowsPowerShell</code>, and behavioral drift between the two runtimes is a real source of subtle bugs.</p>
</blockquote>
<h2 id="when-path-a-is-the-finish-line">When Path A is the finish line</h2>
<p>For a class-based resource on PowerShell 7 through <code>Microsoft.Adapter/PowerShell</code>, Path A <em>is</em> the migration. There's nothing left to do, because the resource already runs on a supported runtime and adapter, driven by a document you review like any other code.</p>
<p>For a script-based resource on the 5.1 adapter, Path A is a waypoint that may last years. It's a legitimate place to stop and breathe, as long as you record it in the inventory as a waypoint. Otherwise it quietly becomes a decision nobody made.</p>
