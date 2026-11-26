---
title: "Path C: From script-based to class-based"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:06:47.000Z"
custom_template: "custom-lesson"
---

<p>Paths A and B leave you with a dependency on Windows PowerShell 5.1, because script-based resources run only through the 5.1 adapter.</p>
<p>That's fine as a waypoint. It's less fine as a ten-year plan, given where PowerShell 5.1 sits on the support lifecycle. The next step up is rewriting script-based resources as class-based ones, which <code>Microsoft.Adapter/PowerShell</code> runs in PowerShell 7+.</p>
<p>The good news: a script resource's three functions map onto a class's three methods so directly that most of the work is mechanical.</p>
<h2 id="the-rewrite">The rewrite</h2>
<p>Here's <code>AppEnvironment</code> reborn as a class (<code>BinderyOps.psm1</code>)</p>
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
<blockquote>
<p>[!NOTE]<br>
Two lines differ from the script-based version on purpose, and both are about <code>$null</code>:</p>
<ul>
<li><code>Get()</code> checks <code>$actual</code> and not <code>$current.Value</code>. Assigning <code>$null</code> to a <code>[string]</code> class property stores an empty string, so a check on the property would report every variable as <code>Present</code>.</li>
<li><code>Set()</code> passes <code>[NullString]::Value</code> to remove the variable. PowerShell hands a plain <code>$null</code> to .NET as an empty string, and on .NET 9 and later that creates an empty variable where older versions deleted it.</li>
</ul>
</blockquote>
<p>With a module manifest that declares it (<code>BinderyOps.psd1</code>):</p>
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
<p>Three details in that manifest matter:</p>
<ul>
<li><strong><code>RootModule</code></strong> now points at the <code>.psm1</code>, because the adapter needs the class loaded to find it.</li>
<li><strong><code>PowerShellVersion = '7.2'</code></strong> states the dependency explicitly, so a 5.1 host fails loudly instead of subtly.</li>
<li><strong><code>DscResourcesToExport</code></strong> is what the adapter reads during discovery. Omit it and your resource is invisible.</li>
</ul>
<h2 id="the-translation-rules">The translation rules</h2>
<table>
<thead>
<tr>
<th>Script-based construct</th>
<th>Class-based equivalent</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>Get-TargetResource</code> function</td>
<td><code>Get()</code> method returning the class type</td>
</tr>
<tr>
<td><code>Test-TargetResource</code> function</td>
<td><code>Test()</code> method returning <code>[bool]</code></td>
</tr>
<tr>
<td><code>Set-TargetResource</code> function</td>
<td><code>Set()</code> method returning <code>[void]</code></td>
</tr>
<tr>
<td>Schema MOF (<code>.schema.mof</code>) file</td>
<td><code>[DscProperty()]</code> attributes on class properties</td>
</tr>
<tr>
<td>Key property in schema MOF</td>
<td><code>[DscProperty(Key)]</code></td>
</tr>
<tr>
<td><code>ValidateSet</code> on the <code>Ensure</code> parameter</td>
<td>An <code>enum</code> type on the property</td>
</tr>
<tr>
<td>Parameters repeated across three functions</td>
<td>Declared once as class properties</td>
</tr>
</tbody>
</table>
<p>That last row is the quiet quality-of-life win. Script resources forced you to declare every parameter three times and keep them synchronized by hand. When you didn't, the failure mode was a resource that silently ignored a property. The class declares state once, and all three methods read <code>$this</code>.</p>
<p><img src="https://storage.ghost.io/c/dd/64/dd64ba9d-7bdd-441e-bb5f-13f8be709814/content/images/2026/10/script-vs-class-resource.png" alt="Figure 1: The same resource, expressed twice. The class removes the synchronization burden." loading="lazy"></p>
<h2 id="two-design-decisions-worth-making-now">Two design decisions worth making now</h2>
<p>This is your one chance to make these cheaply. After the rewrite ships, both become breaking changes.</p>
<h3 id="keep-ensure-and-accept-exist-beside-it">Keep <code>Ensure</code>, and accept <code>_exist</code> beside it</h3>
<p>Your legacy configurations say <code>Ensure = 'Present'</code>. Microsoft DSC's native convention is the <code>_exist</code> property.</p>
<p>For a class-based resource consumed through the adapter, <strong>keep <code>Ensure</code></strong>. It preserves compatibility with every existing document, and that compatibility is usually worth more than convention purity. That matters most during a migration, where the whole point is that documents don't need to change when the resource underneath does.</p>
<p>Keeping <code>Ensure</code> doesn't rule out <code>_exist</code>, though. The class can accept both, so existing documents keep working while new ones use the canonical property. Add <code>_exist</code> as a second optional property and let one helper decide what the caller asked for:</p>
<pre><code class="language-powershell">    [DscProperty()]
    [bool]$_exist = $true&#10;
    hidden [bool] ShouldExist() {
        return ($this.Ensure -eq [Ensure]::Present -and $this._exist)
    }&#10;
    [void] SetHandlesExist() { }
</code></pre>
<p><code>Get()</code> reports <code>_exist</code> next to <code>Ensure</code>, and <code>Test()</code> and <code>Set()</code> call <code>ShouldExist()</code> where they used to compare <code>Ensure</code>. Unit 7 walks through each change.</p>
<p>The empty <code>SetHandlesExist()</code> method is the part that's easy to miss. When a document says <code>_exist: false</code>, the engine only calls <code>Set()</code> on a resource that advertises the <code>setHandlesExist</code> capability. The adapter builds the capability list from the method names it finds in the class, so a method with that name is enough. The adapter never calls it, which is why the body is empty. Leave it out and <code>dsc config set</code> stops with this error:</p>
<pre><code class="language-text">Resource 'BinderyOps/AppEnvironment' does not support `delete` and does not handle `_exist` as false
</code></pre>
<blockquote>
<p>[!NOTE]<br>
The <code>SetHandlesExist()</code> marker comes from the adapter's capability detection and isn't covered in the Microsoft DSC documentation yet. It was verified for this course with <code>dsc</code> 3.3.0. Check <code>dsc resource list</code> after an upgrade to confirm the capability is still reported.</p>
</blockquote>
<p>The same name-based detection has one sharp edge:</p>
<blockquote>
<p>[!WARNING]<br>
Don't add a <code>Delete()</code> method to an adapted class-based resource. The adapter sees the method and advertises the <code>delete</code> capability, so the engine routes <code>_exist: false</code> to a delete operation. The adapter has no delete operation, and every removal then fails with <code>Adapter 'Microsoft.Adapter/PowerShell' does not support delete operation</code>. Handle removal in <code>Set()</code> as shown above, or wait for Path D, where a native resource can implement delete itself.</p>
</blockquote>
<p>Dropping <code>Ensure</code> altogether is the breaking change. Save that for Path D, when you're breaking the interface anyway.</p>
<h3 id="add-an-export-method-while-youre-here">Add an <code>Export()</code> method while you're here</h3>
<p>Script-based resources couldn't implement export at all. Class-based resources can, and a resource that can enumerate its instances gives you <code>dsc resource export</code> for free.</p>
<p>For <code>AppEnvironment</code>, a static <code>Export()</code> returning every machine-level environment variable turns the resource into an audit tool as well as an enforcement tool:</p>
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
<p>Now <code>dsc resource export --resource BinderyOps/AppEnvironment</code> generates a configuration document describing the machine as it actually is. That's a migration tool in its own right: run it against a legacy node and you have a document describing state that nobody ever wrote down.</p>
<blockquote>
<p>[!TIP]<br>
Export is the feature most teams don't realize they wanted until they have it. When someone asks "what's actually set on that box?", the answer stops being a remote session and becomes a document you can diff.</p>
</blockquote>
<h2 id="verify-the-rewrite">Verify the rewrite</h2>
<p>Invoke the resource directly, without a document in the way:</p>
<pre><code class="language-powershell">$instance = @{
    Name  = 'BINDERY_API_URL'
    Value = 'https://api.bindery.example'
} | ConvertTo-Json -Compress&#10;
dsc resource test --resource BinderyOps/AppEnvironment --input $instance
</code></pre>
<p>Then update the Path A document with nothing more than a different adapter:</p>
<pre><code class="language-yaml">  - name: ApiUrl
    type: BinderyOps/AppEnvironment
    directives:
      requireAdapter: Microsoft.Adapter/PowerShell
    properties:
      Name: BINDERY_API_URL
      Value: https://api.bindery.example
      Ensure: Present
</code></pre>
<p>One property changed. The document, the dependencies, and the desired state all survived. <strong>This is what an incremental migration should feel like:</strong> each step small enough to verify, each step leaving the system in a working state.</p>
<blockquote>
<p>[!NOTE]<br>
For faster discovery of class-based resources you control, use adapted resource manifests. A <code>.dsc.adaptedResource.json</code> file lets DSC skip the adapter's module scan entirely, which matters once your migrated resources are invoked by schedulers or pipelines many times per hour.</p>
</blockquote>
<h2 id="port-the-edge-cases-not-just-the-happy-path">Port the edge cases, not just the happy path</h2>
<p>Legacy resources often encode years of edge-case handling in <code>Set-TargetResource</code>: a retry around a flaky API, a guard for a path that only exists on domain controllers, a workaround for a bug fixed in 2019.</p>
<p>The mechanical translation in the table above moves the <em>structure</em>. It does not tell you which of those branches still matter. Before porting the code:</p>
<ol>
<li>Read every branch in the legacy <code>Set-TargetResource</code> and write down what it's defending against.</li>
<li>Write a test for each one with <code>dsc resource test --resource &lt;type&gt; --input &lt;json&gt;</code>, which makes per-case verification cheap.</li>
<li>Then port the code, and run the tests against both implementations.</li>
</ol>
