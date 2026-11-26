---
title: "Exercise: Adapt the legacy configuration"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:05:13.000Z"
custom_template: "custom-lesson"
---

<p>Translate <code>LegacyWebServer.ps1</code> into a configuration document by hand, then prove it behaves identically to the MOF the LCM applied.</p>
<p>Writing it by hand matters. Unit 5 converts a MOF automatically, and you'll review that output far better having done the translation yourself once.</p>
<h2 id="step-1-write-the-document">Step 1: Write the document</h2>
<p>In your <code>C:\BinderyLab</code> folder, create <code>webserver-adapted.dsc.config.yaml</code>:</p>
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
<p>Before running anything, check the translation against the source script line by line:</p>
<ul>
<li>[ ] The <code>$AppRoot</code> parameter became the <code>appRoot</code> parameter, with the default value the script was invoked with</li>
<li>[ ] Both <code>Import-DscResource</code> module names appear as <code>type</code> prefixes</li>
<li>[ ] The <code>Node 'localhost'</code> block has no equivalent</li>
<li>[ ] <code>DependsOn = '[File]AppDirectory'</code> became a <code>resourceId()</code> reference to the <em>type and name</em> of the target resource</li>
<li>[ ] Every property name and value is character-for-character identical to the script</li>
</ul>
<h2 id="step-2-test-against-the-converged-machine">Step 2: Test against the converged machine</h2>
<p>The machine is already in its desired state, applied by the LCM in Module 1. So the first thing your document should do is <strong>agree</strong>:</p>
<pre><code class="language-powershell">dsc config test --file .\webserver-adapted.dsc.config.yaml
</code></pre>
<p>Read the output for both resources:</p>
<pre><code class="language-yaml">results:
- name: AppDirectory
  type: PSDesiredStateConfiguration/File
  result:
    inDesiredState: true
- name: ApiUrl
  type: BinderyOps/AppEnvironment
  result:
    inDesiredState: true
messages: []
hadErrors: false
</code></pre>
<p>Two <code>true</code> values mean your translation is faithful. Anything else means a property translated wrong. Read <code>differingProperties</code> and compare that property against the source script.</p>
<h2 id="step-3-introduce-drift-then-converge-with-microsoft-dsc">Step 3: Introduce drift, then converge with Microsoft DSC</h2>
<p>A passing test on an already-converged machine proves the <em>read</em> path. Now prove the <em>write</em> path.</p>
<p>Break the state deliberately:</p>
<pre><code class="language-powershell">[Environment]::SetEnvironmentVariable('BINDERY_API_URL', 'https://wrong.example', 'Machine')
</code></pre>
<p>Confirm the document notices:</p>
<pre><code class="language-powershell">dsc config test --file .\webserver-adapted.dsc.config.yaml
</code></pre>
<p><code>ApiUrl</code> should now report <code>inDesiredState: false</code> with <code>Value</code> in <code>differingProperties</code>. Converge it:</p>
<pre><code class="language-powershell">dsc config set --file .\webserver-adapted.dsc.config.yaml
</code></pre>
<p>And verify:</p>
<pre><code class="language-powershell">[Environment]::GetEnvironmentVariable('BINDERY_API_URL', 'Machine')
dsc config test --file .\webserver-adapted.dsc.config.yaml
</code></pre>
<p>You just enforced desired state through the Microsoft DSC engine, using a resource whose code hasn't changed since 2016.</p>
<h2 id="step-4-override-the-parameter">Step 4: Override the parameter</h2>
<p>Parameters are the replacement for per-node MOF variations, so exercise one:</p>
<pre><code class="language-powershell">dsc config test --file .\webserver-adapted.dsc.config.yaml --parameters '{"appRoot":"C:\\BinderyApp-Test"}'
</code></pre>
<p><code>AppDirectory</code> should now report <code>inDesiredState: false</code>, because <code>C:\BinderyApp-Test</code> doesn't exist. The document stays the same while the target changes, which is exactly how one document replaces a folder full of per-node MOFs.</p>
<blockquote>
<p>[!NOTE]<br>
Parameters can also come from a file with <code>--parameters-file</code>. That's the pattern you'll want in a pipeline, where the values differ per environment and shouldn't live in the command line or in shell history.</p>
</blockquote>
<h2 id="step-5-compare-against-the-lcm-one-last-time">Step 5: Compare against the LCM one last time</h2>
<p>With the machine converged by Microsoft DSC, ask the old engine what it thinks:</p>
<pre><code class="language-powershell">Test-DscConfiguration -Detailed
</code></pre>
<p>The LCM should also report the machine in desired state, because it's checking the same environment variable and the same directory. Both engines agree about reality. Only the instructions moved.</p>
<blockquote>
<p>[!WARNING]<br>
Both engines agreeing is comfortable but temporary. Leaving the LCM enforcing the same settings that Microsoft DSC now enforces means two schedulers fighting over one setting the first time the desired values diverge. Module 3 covers disabling the LCM at the right moment.</p>
</blockquote>
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
<td><code>Resource type 'BinderyOps/AppEnvironment' not found</code></td>
<td><code>requireAdapter</code> missing or misspelled</td>
<td>The directive must be <code>requireAdapter: Microsoft.Adapter/WindowsPowerShell</code></td>
</tr>
<tr>
<td>Test reports the resource in desired state but the value is clearly wrong</td>
<td>The adapter found a different module version</td>
<td>Print <code>$env:PSModulePath</code> in Windows PowerShell and remove duplicate <code>BinderyOps</code> copies</td>
</tr>
<tr>
<td><code>dependsOn</code> reports an unresolved reference</td>
<td><code>resourceId()</code> arguments reversed</td>
<td>The signature is <code>resourceId('&lt;type&gt;', '&lt;name&gt;')</code>, with type first</td>
</tr>
<tr>
<td>YAML parse error on the <code>[parameters(...)]</code> line</td>
<td>Missing quotes</td>
<td>Expressions starting with <code>[</code> must be quoted in YAML, or the parser reads them as a list</td>
</tr>
</tbody>
</table>
<h2 id="check-your-work">Check your work</h2>
<ul>
<li>[ ] <code>dsc config test</code> reports <code>inDesiredState: true</code> for both resources on the converged machine</li>
<li>[ ] Deliberate drift is detected, with the right property named in <code>differingProperties</code></li>
<li>[ ] <code>dsc config set</code> converges the machine</li>
<li>[ ] Overriding <code>appRoot</code> changes the result, proving the parameter is wired through</li>
<li>[ ] You can explain, without looking, what happened to <code>Node</code>, <code>DependsOn</code>, and the compile step</li>
</ul>
