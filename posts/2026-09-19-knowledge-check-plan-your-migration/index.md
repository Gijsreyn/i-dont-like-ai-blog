---
title: "Knowledge check"
status: published
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-19T11:22:03.000Z"
custom_template: "custom-lesson"
---

<p>Answer the questions, then expand each answer to check yourself.</p>
<p><strong>1. A resource appears in the output of <code>dsc resource list --adapter Microsoft.Adapter/WindowsPowerShell</code> but not in <code>dsc resource list --adapter Microsoft.Adapter/PowerShell</code>. What does that most likely mean?</strong></p>
<ul>
<li>A. The resource is broken and needs to be reinstalled.</li>
<li>B. The resource is script-based, and the PowerShell 7+ adapter supports only class-based resources.</li>
<li>C. The PowerShell 7+ adapter isn't installed.</li>
<li>D. The module needs to be signed before PowerShell 7 will load it.</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> The Windows PowerShell 5.1 adapter maintains backwards compatibility with script-based resources, while the PowerShell 7+ adapter deliberately supports class-based resources only. A resource visible to the first but not the second is a Path C candidate.</p>
<p>Answer C is worth ruling out properly: if the PowerShell 7+ adapter were missing, the command would fail or return nothing at all rather than returning an incomplete list.</p>
</details>
<p><strong>2. Your team has 180 compiled MOF files on a pull server. For about 40 of them, the original <code>Configuration</code> script no longer exists in source control. Which path applies to those 40?</strong></p>
<ul>
<li>A. Path A — adapt in place</li>
<li>B. Path B — import compiled MOFs</li>
<li>C. Path C — rewrite as class-based</li>
<li>D. They can't be migrated and must be rewritten from scratch</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> The import extension translates MOF files into configuration documents, which is exactly the rescue case for MOFs whose source is gone. After conversion you're back on Path A: a document that references legacy resources through an adapter.</p>
</details>
<p><strong>3. Which statement about <code>ImplementationDetail</code> is correct?</strong></p>
<ul>
<li>A. <code>ScriptBased</code> means the resource is written as a PowerShell class.</li>
<li>B. <code>ClassBased</code> means the resource implements <code>Get-TargetResource</code>, <code>Set-TargetResource</code>, and <code>Test-TargetResource</code>.</li>
<li>C. <code>ScriptBased</code> means the resource implements the <code>Get</code>/<code>Set</code>/<code>Test-TargetResource</code> trio alongside a schema MOF file.</li>
<li>D. <code>ImplementationDetail</code> describes how often the LCM runs the resource.</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>C.</strong> <code>ScriptBased</code> is the function trio plus a <code>.schema.mof</code>. <code>ClassBased</code> is a PowerShell class decorated with <code>[DscResource()]</code>.</p>
</details>
<p><strong>4. <code>Get-DscResource</code> lists a resource, but <code>dsc resource list</code> doesn't. What should you check first?</strong></p>
<ul>
<li>A. Whether the resource has a valid digital signature</li>
<li>B. Which module paths each host resolves — print <code>$env:PSModulePath</code> in both</li>
<li>C. Whether the LCM is in <code>ApplyAndAutoCorrect</code> mode</li>
<li>D. Whether the MOF file has been recompiled recently</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> <code>Get-DscResource</code> in Windows PowerShell enumerates from <code>$env:PSModulePath</code> as 5.1 sees it, while <code>dsc resource list</code> uses the adapter's own discovery. Disagreement between the two is almost always a module path difference, not a broken resource.</p>
</details>
<p><strong>5. Which of these is <em>not</em> a good reason to choose Path D (native rewrite) for a resource?</strong></p>
<ul>
<li>A. The resource is invoked hundreds of times per hour by a scheduler, and PowerShell host startup dominates the runtime.</li>
<li>B. The resource must run on Linux and macOS without deploying PowerShell 7 first.</li>
<li>C. The resource needs <code>whatIfArg</code> and fine-grained capability declarations.</li>
<li>D. The team would prefer to work in a compiled language.</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>D.</strong> Language preference isn't a payoff. Path D costs weeks; it needs a justification that survives a budget conversation — startup cost, platform reach, capability surface, or distribution as a product.</p>
</details>
<p><strong>6. True or false: adapting resources in place (Path A) is a temporary state that every estate must eventually leave.</strong></p>
<details>
<summary>Show answer</summary>
<p><strong>False</strong> — with a caveat. A class-based resource running on PowerShell 7 through <code>Microsoft.Adapter/PowerShell</code> is a fully supported, long-term-viable end state, and many organizations run hybrid estates for years.</p>
<p>The caveat applies to <em>script-based</em> resources specifically: they depend on Windows PowerShell 5.1, which is in maintenance mode, and there are rumblings the 5.1 adapter may eventually be dropped. That's a reason to schedule Path C deliberately, not a reason to treat all adaptation as temporary.</p>
</details>
