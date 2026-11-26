---
title: "Summary"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:09:15.000Z"
custom_template: "custom-lesson"
---

<p>You walked all four paths against one estate and verified each one against a machine the LCM had already converged.</p>
<h2 id="what-you-did">What you did</h2>
<ul>
<li><strong>Path A:</strong> Translated <code>LegacyWebServer.ps1</code> into a configuration document, mapping every legacy construct — <code>Configuration</code>, <code>param()</code>, <code>Import-DscResource</code>, <code>Node</code>, <code>DependsOn</code> — to its equivalent, with resource code untouched.</li>
<li><strong>Path B:</strong> Installed an import extension, fed a <code>.mof</code> file straight into the engine, persisted the conversion with <code>Convert-MofToDsc</code>, and reviewed the result against the four blind spots.</li>
<li><strong>Path C:</strong> Rewrote <code>AppEnvironment</code> from a <code>Get</code>/<code>Set</code>/<code>Test-TargetResource</code> trio into a <code>[DscResource()]</code> class, added an <code>Export()</code> method the old resource could never have, and switched the document over by changing one property.</li>
<li><strong>Path D:</strong> Learned the four signals that justify a native rewrite, and the four reasons people attempt one when they shouldn't.</li>
</ul>
<h2 id="key-takeaways">Key takeaways</h2>
<blockquote>
<p>The resource contract is the thing that survives. Every path changes what's on one side of it and leaves the document on the other side almost untouched.</p>
</blockquote>
<ul>
<li><code>requireAdapter</code> is the pivot point of the entire migration. Changing its value is how a document moves from Windows PowerShell 5.1 to PowerShell 7 without any other edit.</li>
<li>Mechanical MOF conversion is faithful about what's written down and silent about what isn't. Credentials, node names, composites, and implicit ordering are the four things to check every time.</li>
<li>The script-to-class translation is structural and largely mechanical. The <em>edge cases</em> inside <code>Set-TargetResource</code> are neither, and they're where rewrites actually fail.</li>
<li><code>dsc config test</code> against an LCM-converged machine is the cheapest validation in the entire migration. It changes nothing and tells you everything.</li>
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
<td><code>dsc config test --file &lt;doc&gt;</code></td>
<td>Verify a migrated document against live state</td>
</tr>
<tr>
<td><code>dsc config set --file &lt;doc&gt;</code></td>
<td>Enforce desired state through the new engine</td>
</tr>
<tr>
<td><code>dsc config test --file &lt;doc&gt; --parameters '&lt;json&gt;'</code></td>
<td>Exercise a parameter without editing the document</td>
</tr>
<tr>
<td><code>dsc config test --file &lt;file&gt;.mof</code></td>
<td>Translate and evaluate a MOF via the import extension</td>
</tr>
<tr>
<td><code>Convert-MofToDsc -Path &lt;file&gt;.mof</code></td>
<td>Persist a MOF as a configuration document</td>
</tr>
<tr>
<td><code>dsc extension list</code></td>
<td>Confirm an import extension is discovered</td>
</tr>
<tr>
<td><code>dsc resource test --resource &lt;type&gt; --input &lt;json&gt;</code></td>
<td>Verify one resource in isolation</td>
</tr>
<tr>
<td><code>dsc resource export --resource &lt;type&gt;</code></td>
<td>Generate a document from actual state (class-based only)</td>
</tr>
<tr>
<td><code>dsc -l debug &lt;command&gt;</code></td>
<td>Trace adapter and extension selection</td>
</tr>
</tbody>
</table>
<h2 id="learn-more">Learn more</h2>
<ul>
<li><em>The Microsoft DSC Handbook</em>, Chapter 6 — how the PowerShell adapters work</li>
<li><em>The Microsoft DSC Handbook</em>, Chapter 7 — extensions, including the import extension you installed</li>
<li><em>The Microsoft DSC Handbook</em>, Chapter 10 — building a native command resource</li>
</ul>
<h2 id="next-module">Next module</h2>
<p>Your resources and documents have migrated. What hasn't migrated is the thing that made PowerShell DSC feel like a <em>management system</em> rather than a set of files: the LCM's background behaviors. Module 3 maps every one of them to an explicit replacement, and makes you the owner of the schedule.</p>
