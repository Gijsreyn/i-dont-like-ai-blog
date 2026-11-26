---
title: "Exercise: Rewrite AppEnvironment as a class"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:07:20.000Z"
custom_template: "custom-lesson"
---

<p>Port the script-based <code>AppEnvironment</code> resource to a class-based one, prove the PowerShell 7+ adapter can see it, and switch the Path A document over by changing a single property.</p>
<h2 id="step-1-create-the-v2-module-in-a-powershell-7-module-path">Step 1: Create the v2 module in a PowerShell 7 module path</h2>
<p>The class-based module must live where <strong>PowerShell 7</strong> looks, not where Windows PowerShell 5.1 looks. Keeping them separate is what lets both versions coexist during the migration.</p>
<pre><code class="language-powershell"># Run in PowerShell 7
$root = "$env:ProgramFiles\PowerShell\Modules\BinderyOps\2.0.0"
New-Item -Path $root -ItemType Directory -Force
</code></pre>
<p>Create <code>BinderyOps.psm1</code> in that folder with the class from unit 6:</p>
<pre><code class="language-powershell">enum Ensure {
    Present
    Absent
}&#10;
[DscResource()]
class AppEnvironment {
    [DscProperty(Key)]
    [string]$Name&#10;
    [DscProperty()]
    [string]$Value&#10;
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present&#10;
    [AppEnvironment] Get() {
        $actual = [Environment]::GetEnvironmentVariable($this.Name, 'Machine')&#10;
        $current = [AppEnvironment]::new()
        $current.Name = $this.Name
        $current.Value = $actual
        $current.Ensure = if ($null -ne $actual) {
            [Ensure]::Present
        } else {
            [Ensure]::Absent
        }
        return $current
    }&#10;
    [bool] Test() {
        $current = $this.Get()&#10;
        if ($this.Ensure -eq [Ensure]::Absent) {
            return ($current.Ensure -eq [Ensure]::Absent)
        }&#10;
        return ($current.Ensure -eq [Ensure]::Present -and $current.Value -eq $this.Value)
    }&#10;
    [void] Set() {
        if ($this.Ensure -eq [Ensure]::Present) {
            [Environment]::SetEnvironmentVariable($this.Name, $this.Value, 'Machine')
        } else {
            [Environment]::SetEnvironmentVariable($this.Name, [NullString]::Value, 'Machine')
        }
    }
}
</code></pre>
<p>Type <code>$actual</code> and <code>[NullString]::Value</code> exactly as shown. Unit 6 explains why a plain <code>$null</code> goes wrong in both places.</p>
<p>And <code>BinderyOps.psd1</code> beside it. Use the same <code>GUID</code> you generated with <code>New-Guid</code> for the 1.0.0 manifest in Module 1:</p>
<pre><code class="language-powershell">@{
    RootModule           = 'BinderyOps.psm1'
    ModuleVersion        = '2.0.0'
    GUID                 = 'b3d4f7a1-6c2e-4e8a-9f31-8d5a2c7e4b90'
    Author               = 'Bindery Operations'
    Description          = 'Bindery operational resources for Microsoft DSC.'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @('AppEnvironment')
}
</code></pre>
<p>Confirm PowerShell 7 can load it before involving DSC at all:</p>
<pre><code class="language-powershell">Import-Module BinderyOps -Force
[AppEnvironment]::new().GetType().Name
</code></pre>
<blockquote>
<p>[!TIP]<br>
Class definitions are loaded at parse time, which is why a class-based resource that "doesn't exist" usually has a syntax error further down the file. Importing the module by hand is the fastest way to see the real error.</p>
</blockquote>
<h2 id="step-2-confirm-the-adapter-can-discover-it">Step 2: Confirm the adapter can discover it</h2>
<pre><code class="language-powershell">dsc resource list --adapter Microsoft.Adapter/PowerShell | Select-String 'BinderyOps'
</code></pre>
<p>Back in Module 1, this command returned nothing. Now it returns a row. That single line is the entire payoff of Path C: the resource no longer needs Windows PowerShell.</p>
<p>If it returns nothing:</p>
<pre><code class="language-powershell">dsc -l debug resource list --adapter Microsoft.Adapter/PowerShell
</code></pre>
<p>and look for <code>BinderyOps</code> in the module scan trace.</p>
<h2 id="step-3-test-the-resource-directly">Step 3: Test the resource directly</h2>
<p>Before touching any document, verify the resource in isolation:</p>
<pre><code class="language-powershell">$instance = @{
    Name  = 'BINDERY_API_URL'
    Value = 'https://api.bindery.example'
} | ConvertTo-Json -Compress&#10;
dsc resource test --resource BinderyOps/AppEnvironment --input $instance
</code></pre>
<p>Expect <code>inDesiredState: true</code> — the machine still holds the value the LCM set in Module 1, and your rewritten <code>Test()</code> should agree with the original <code>Test-TargetResource</code>.</p>
<p>Now test the negative case, because a <code>Test()</code> that always returns <code>true</code> also passes the check above:</p>
<pre><code class="language-powershell">$wrong = @{
    Name  = 'BINDERY_API_URL'
    Value = 'https://not-the-value.example'
} | ConvertTo-Json -Compress&#10;
dsc resource test --resource BinderyOps/AppEnvironment --input $wrong
</code></pre>
<p>Expect <code>inDesiredState: false</code> with <code>Value</code> in <code>differingProperties</code>.</p>
<p>And the <code>Absent</code> branch:</p>
<pre><code class="language-powershell">$absent = @{
    Name   = 'BINDERY_DOES_NOT_EXIST'
    Ensure = 'Absent'
} | ConvertTo-Json -Compress&#10;
dsc resource test --resource BinderyOps/AppEnvironment --input $absent
</code></pre>
<p>Expect <code>inDesiredState: true</code>. Three cases, three correct answers — that's a ported resource, not just a compiling one.</p>
<h2 id="step-4-switch-the-document-to-the-new-adapter">Step 4: Switch the document to the new adapter</h2>
<p>Copy your Path A document to <code>webserver-ps7.dsc.config.yaml</code> and change exactly one line:</p>
<pre><code class="language-yaml">  - name: ApiUrl
    type: BinderyOps/AppEnvironment
    directives:
      requireAdapter: Microsoft.Adapter/PowerShell   # was Microsoft.Adapter/WindowsPowerShell
    properties:
      Name: BINDERY_API_URL
      Value: https://api.bindery.example
      Ensure: Present
</code></pre>
<p>Leave <code>AppDirectory</code> on the Windows PowerShell adapter — <code>PSDesiredStateConfiguration/File</code> isn't yours to rewrite, and a document that mixes adapters is completely normal during a migration.</p>
<pre><code class="language-powershell">dsc config test --file .\webserver-ps7.dsc.config.yaml
</code></pre>
<p>Both resources should report <code>inDesiredState: true</code>. The document, the dependency, the property names, and the desired state all survived a resource rewrite — because the contract never changed.</p>
<h2 id="step-5-add-an-export-method">Step 5: Add an Export method</h2>
<p>Add this static method inside the class, then reload the module:</p>
<pre><code class="language-powershell">    static [AppEnvironment[]] Export() {
        $variables = [Environment]::GetEnvironmentVariables('Machine')&#10;
        return @(
            foreach ($key in $variables.Keys) {
                $instance = [AppEnvironment]::new()
                $instance.Name = $key
                $instance.Value = $variables[$key]
                $instance.Ensure = [Ensure]::Present
                $instance
            }
        )
    }
</code></pre>
<pre><code class="language-powershell">dsc resource export --resource BinderyOps/AppEnvironment
</code></pre>
<p>You get a configuration document describing every machine-level environment variable on the box — state that nobody ever wrote down, now expressed as something you can commit, diff, and review. The script-based version could never do this.</p>
<h2 id="step-6-accept-exist-beside-ensure">Step 6: Accept <code>_exist</code> beside <code>Ensure</code></h2>
<p>Existing documents say <code>Ensure</code>. New Microsoft DSC documents say <code>_exist</code>. Teach the class to accept both.</p>
<p>Add the property below <code>Ensure</code>:</p>
<pre><code class="language-powershell">    [DscProperty()]
    [bool]$_exist = $true
</code></pre>
<p>Add two methods inside the class. The first decides what the caller asked for, whichever property they used. The second is an empty marker that tells the adapter to advertise the <code>setHandlesExist</code> capability:</p>
<pre><code class="language-powershell">    hidden [bool] ShouldExist() {
        return ($this.Ensure -eq [Ensure]::Present -and $this._exist)
    }&#10;
    [void] SetHandlesExist() { }
</code></pre>
<p>Then replace <code>Get()</code>, <code>Test()</code>, and <code>Set()</code> so they report and honor <code>_exist</code>:</p>
<pre><code class="language-powershell">    [AppEnvironment] Get() {
        $actual = [Environment]::GetEnvironmentVariable($this.Name, 'Machine')&#10;
        $current = [AppEnvironment]::new()
        $current.Name = $this.Name
        $current.Value = $actual
        $current._exist = $null -ne $actual
        $current.Ensure = if ($current._exist) {
            [Ensure]::Present
        } else {
            [Ensure]::Absent
        }
        return $current
    }&#10;
    [bool] Test() {
        $current = $this.Get()&#10;
        if (-not $this.ShouldExist()) {
            return (-not $current._exist)
        }&#10;
        return ($current._exist -and $current.Value -eq $this.Value)
    }&#10;
    [void] Set() {
        if ($this.ShouldExist()) {
            [Environment]::SetEnvironmentVariable($this.Name, $this.Value, 'Machine')
        } else {
            [Environment]::SetEnvironmentVariable($this.Name, [NullString]::Value, 'Machine')
        }
    }
</code></pre>
<p>Confirm the adapter picked up the new capability:</p>
<pre><code class="language-powershell">dsc resource list --adapter Microsoft.Adapter/PowerShell | Select-String 'BinderyOps'
</code></pre>
<p>The capabilities for <code>BinderyOps/AppEnvironment</code> should now include <code>setHandlesExist</code>.</p>
<p>Now use the new property on a variable you can afford to lose. Create <code>scratch-variable.dsc.config.yaml</code>:</p>
<pre><code class="language-yaml"># yaml-language-server: $schema=https://aka.ms/dsc/schemas/v3/bundled/config/document.json
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: ScratchVariable
    type: BinderyOps/AppEnvironment
    directives:
      requireAdapter: Microsoft.Adapter/PowerShell
    properties:
      Name: BINDERY_SCRATCH
      Value: temporary
</code></pre>
<p>Create the variable:</p>
<pre><code class="language-powershell">dsc config set --file .\scratch-variable.dsc.config.yaml
[Environment]::GetEnvironmentVariable('BINDERY_SCRATCH', 'Machine')
</code></pre>
<p>Then edit the document to ask for its removal. Replace the <code>Value</code> line so the properties read:</p>
<pre><code class="language-yaml">    properties:
      Name: BINDERY_SCRATCH
      _exist: false
</code></pre>
<pre><code class="language-powershell">dsc config test --file .\scratch-variable.dsc.config.yaml
dsc config set --file .\scratch-variable.dsc.config.yaml
dsc config test --file .\scratch-variable.dsc.config.yaml
</code></pre>
<p>The first test reports <code>inDesiredState: false</code> with <code>_exist</code> in <code>differingProperties</code>. The set removes the variable, and the second test reports <code>inDesiredState: true</code>.</p>
<p>Finally, prove you didn't break the documents that still say <code>Ensure</code>:</p>
<pre><code class="language-powershell">dsc config test --file .\webserver-ps7.dsc.config.yaml
</code></pre>
<p>Both resources should still report <code>inDesiredState: true</code>.</p>
<blockquote>
<p>[!WARNING]<br>
Don't add a <code>Delete()</code> method to get the same result. The adapter advertises the <code>delete</code> capability when it sees one, but it has no delete operation, so every <code>_exist: false</code> request then fails. Unit 6 has the details.</p>
</blockquote>
<h2 id="step-7-prove-the-two-implementations-agree">Step 7: Prove the two implementations agree</h2>
<p>You now have both versions installed: script-based under Windows PowerShell, class-based under PowerShell 7. Ask them the same question:</p>
<pre><code class="language-powershell">$instance = @{
    Name  = 'BINDERY_API_URL'
    Value = 'https://api.bindery.example'
} | ConvertTo-Json -Compress&#10;
dsc config test --file .\webserver-adapted.dsc.config.yaml   # 5.1 adapter, script-based
dsc config test --file .\webserver-ps7.dsc.config.yaml       # PowerShell 7 adapter, class-based
</code></pre>
<p>Identical results mean the rewrite is faithful. Different results mean you found translation drift — and finding it here, with both implementations side by side on a lab machine, is the entire reason to migrate incrementally.</p>
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
<td>Resource not listed by the PowerShell 7+ adapter</td>
<td><code>DscResourcesToExport</code> missing from the manifest</td>
<td>Add it; the adapter reads it during discovery</td>
</tr>
<tr>
<td><code>Import-Module</code> succeeds but <code>[AppEnvironment]</code> is unknown</td>
<td>Class scoping — classes aren't exported like functions</td>
<td>Use <code>using module BinderyOps</code> for interactive testing, or test via <code>dsc resource test</code></td>
</tr>
<tr>
<td><code>Get()</code> returns null values for everything</td>
<td><code>Get()</code> returned <code>$this</code> instead of a new instance populated from the system</td>
<td>Build a fresh instance and populate it from actual state</td>
</tr>
<tr>
<td>The adapter picks the 1.0.0 script-based module</td>
<td>Both versions visible to the same host</td>
<td>Keep 5.1 and PowerShell 7 module paths separate; check <code>$env:PSModulePath</code> in each</td>
</tr>
<tr>
<td><code>dsc config set</code> fails with "does not handle <code>_exist</code> as false"</td>
<td>The <code>SetHandlesExist()</code> marker method is missing</td>
<td>Add the empty method from step 6 and confirm <code>setHandlesExist</code> appears in <code>dsc resource list</code></td>
</tr>
<tr>
<td><code>dsc config set</code> fails with "does not support delete operation"</td>
<td>The class has a <code>Delete()</code> method</td>
<td>Remove it and handle removal in <code>Set()</code></td>
</tr>
<tr>
<td>A removed variable still tests as <code>Present</code></td>
<td><code>Get()</code> checks <code>$current.Value</code>, or <code>Set()</code> passes a plain <code>$null</code></td>
<td>Use <code>$actual</code> and <code>[NullString]::Value</code> as shown in step 1</td>
</tr>
<tr>
<td><code>Ensure</code> rejects <code>'Present'</code> as a string</td>
<td>Enum conversion at the adapter boundary</td>
<td>Confirm the enum member names match the strings the documents use exactly</td>
</tr>
</tbody>
</table>
<h2 id="check-your-work">Check your work</h2>
<ul>
<li>[ ] <code>dsc resource list --adapter Microsoft.Adapter/PowerShell</code> shows <code>BinderyOps/AppEnvironment</code></li>
<li>[ ] Positive, negative, and <code>Absent</code> test cases all return the correct result</li>
<li>[ ] <code>webserver-ps7.dsc.config.yaml</code> passes with only the <code>requireAdapter</code> value changed</li>
<li>[ ] <code>dsc resource export</code> produces a document listing machine environment variables</li>
<li>[ ] A document with <code>_exist: false</code> removes <code>BINDERY_SCRATCH</code>, and documents that say <code>Ensure</code> still pass</li>
<li>[ ] Both adapter routes report identical results against the same machine</li>
</ul>
