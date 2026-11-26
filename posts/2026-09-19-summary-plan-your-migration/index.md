---
title: "Summary"
status: published
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-19T11:33:46.000Z"
custom_template: "custom-lesson"
---

<p>You started this module with an estate and a vague intention. You're ending it with a classified inventory and a path assigned to every row.</p>
<h2 id="what-you-did">What you did</h2>
<ul>
<li><strong>Justified the migration</strong> in operational terms: Windows PowerShell 5.1 is in maintenance mode, the LCM isn't coming to PowerShell 7, new investment lands in Microsoft DSC, and cross-platform is table stakes. You also named the situations where waiting is the right call.</li>
<li><strong>Classified the four artifact types</strong> — configuration scripts, compiled MOFs, script-based resources, class-based resources — and learned that each migrates differently.</li>
<li><strong>Built a migration inventory</strong> by joining the classic <code>Get-DscResource</code> view with both adapter views, so that the gap between them becomes a concrete list rather than a suspicion.</li>
<li><strong>Created the Bindery legacy estate</strong> and applied it under the LCM, establishing the baseline that every migration path must reproduce.</li>
<li><strong>Assigned a path</strong> to each artifact using a decision flow that starts with "is it still used?" and ends with the four signals that justify a native rewrite.</li>
</ul>
<h2 id="key-takeaways">Key takeaways</h2>
<blockquote>
<p>The inventory is the deliverable. A migration without one is a series of surprises.</p>
</blockquote>
<ul>
<li>The <strong>5.1 adapter</strong> discovers script-based <em>and</em> class-based resources. The <strong>PowerShell 7+ adapter</strong> discovers class-based only. That single asymmetry drives most migration decisions.</li>
<li><code>SuggestedPath</code> from an inventory script is a starting point, not a verdict. Ownership, usage, and platform plans override it.</li>
<li>Path A and Path B move the orchestration layer without touching resource code. That decoupling is what makes the deeper rewrites safe to do incrementally.</li>
<li>Module path confusion between hosts causes more false "broken resource" reports than any other single issue. Check <code>$env:PSModulePath</code> in both hosts first.</li>
</ul>
<h2 id="command-reference">Command reference</h2>
<table>
<thead>
<tr>
<th>Command</th>
<th>Purpose</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>Get-DscResource | Select-Object Name, ModuleName, ImplementationDetail</code></td>
<td>Classic enumeration; run in Windows PowerShell 5.1</td>
</tr>
<tr>
<td><code>dsc resource list --adapter Microsoft.Adapter/WindowsPowerShell</code></td>
<td>What the 5.1 adapter can discover</td>
</tr>
<tr>
<td><code>dsc resource list --adapter Microsoft.Adapter/PowerShell</code></td>
<td>What the PowerShell 7+ adapter can discover</td>
</tr>
<tr>
<td><code>dsc resource list --adapter &lt;name&gt; --output-format json</code></td>
<td>Machine-readable form for inventory scripts</td>
</tr>
<tr>
<td><code>Test-DscConfiguration -Detailed</code></td>
<td>Confirm the LCM baseline before migrating</td>
</tr>
</tbody>
</table>
<h2 id="learn-more">Learn more</h2>
<ul>
<li><em>The Microsoft DSC Handbook</em>, Chapter 11 — the full written treatment of this material</li>
<li><em>The Microsoft DSC Handbook</em>, Chapter 6 — how the PowerShell adapters work internally</li>
<li><a href="https://learn.microsoft.com/powershell/dsc/">Microsoft DSC documentation</a></li>
</ul>
<h2 id="next-module">Next module</h2>
<p>You know what you own and where each piece is going. Module 2 walks all four paths against the Bindery estate, starting with the least invasive one: translating a <code>Configuration</code> script into a configuration document while the resource code underneath stays byte-for-byte identical.</p>
