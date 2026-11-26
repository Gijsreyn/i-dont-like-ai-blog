---
title: "Knowledge check"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:08:29.000Z"
custom_template: "custom-lesson"
---

<p><strong>1. In a configuration document, what replaces <code>Node 'localhost'</code> from a <code>Configuration</code> script?</strong></p>
<ul>
<li>A. A <code>node</code> property on each resource</li>
<li>B. The <code>targetNode</code> section of the document</li>
<li>C. Nothing — the document applies wherever you invoke it</li>
<li>D. A <code>resourceId()</code> reference to the node name</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>C.</strong> A MOF is compiled per node; a configuration document is node-agnostic. Node identity moves up to whatever invokes the engine, and per-node variation becomes parameters.</p>
</details>
<hr>
<p><strong>2. Which directive tells the engine to route a resource type through an adapter?</strong></p>
<ul>
<li>A. <code>adapter</code></li>
<li>B. <code>requireAdapter</code></li>
<li>C. <code>useAdapter</code></li>
<li>D. <code>importModule</code></li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> <code>directives: { requireAdapter: Microsoft.Adapter/WindowsPowerShell }</code>. Without it, the engine looks for a native resource of that type and fails to find one.</p>
</details>
<hr>
<p><strong>3. You convert a MOF file with <code>Convert-MofToDsc</code> and the resulting document has no <code>dependsOn</code> entries, although the resources clearly need to run in order. What happened?</strong></p>
<ul>
<li>A. The converter is broken and the MOF should be converted again.</li>
<li>B. The source configuration relied on implicit LCM ordering, which the converter can't infer.</li>
<li>C. <code>dependsOn</code> is only supported in YAML documents, not JSON.</li>
<li>D. The MOF was compiled with an old version of PowerShell.</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> The importer faithfully preserves <em>explicit</em> <code>DependsOn</code> values. Implicit ordering assumptions were never written down in the MOF, so they're yours to rediscover — and this is one of the four known blind spots of mechanical conversion.</p>
</details>
<hr>
<p><strong>4. Which of these is <em>not</em> one of the four review blind spots for an imported MOF?</strong></p>
<ul>
<li>A. Credentials are dropped deliberately</li>
<li>B. Node names vanish</li>
<li>C. Resource property names are renamed to lowercase</li>
<li>D. Composite resources arrive flattened</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>C.</strong> Property names pass through unchanged — that's what makes an adapted document behaviorally equivalent. The four blind spots are dropped credentials, vanished node names, flattened composites, and lost implicit ordering.</p>
</details>
<hr>
<p><strong>5. When rewriting a script-based resource as class-based, what happens to the <code>.schema.mof</code> file?</strong></p>
<ul>
<li>A. It's still required, next to the <code>.psm1</code></li>
<li>B. Its information moves into <code>[DscProperty()]</code> attributes on the class</li>
<li>C. It's converted automatically by the adapter at runtime</li>
<li>D. It's replaced by a <code>.dsc.resource.json</code> manifest</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> The schema MOF disappears. Property descriptions, write/read flags, and — importantly — the key property become <code>[DscProperty()]</code> and <code>[DscProperty(Key)]</code> attributes.</p>
<p>Answer D describes Path D: a native command resource uses a resource manifest, but a class-based resource doesn't.</p>
</details>
<hr>
<p><strong>6. You've rewritten a resource as class-based. Should you replace <code>Ensure</code> with the native <code>_exist</code> convention at the same time?</strong></p>
<ul>
<li>A. Yes, always — <code>_exist</code> is the Microsoft DSC convention</li>
<li>B. No — keep <code>Ensure</code> so existing documents continue to work, and drop it when you do a native rewrite</li>
<li>C. It makes no difference; the adapter maps them automatically</li>
<li>D. Only if the resource also implements <code>Export()</code></li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> Compatibility with every document that already says <code>Ensure = 'Present'</code> is worth more than convention purity during a migration. Path D breaks the contract anyway, so that's the moment to switch.</p>
</details>
<hr>
<p><strong>7. Which capability does a class-based resource gain that a script-based resource could never have?</strong></p>
<ul>
<li>A. <code>Test()</code></li>
<li>B. Key properties</li>
<li>C. <code>Export()</code>, and therefore <code>dsc resource export</code></li>
<li>D. Running through an adapter</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>C.</strong> Script-based resources couldn't implement export at all. A class-based resource with a static <code>Export()</code> method can enumerate its instances, which turns it into an audit tool as well as an enforcement tool.</p>
</details>
<hr>
<p><strong>8. A resource is invoked twice a week during a maintenance window, runs only on Windows, and is consumed by one team. Its author wants to rewrite it as a native command resource because the team prefers Rust. What's the right call?</strong></p>
<ul>
<li>A. Approve it — native resources are the modern approach</li>
<li>B. Approve it if they also write tests</li>
<li>C. Decline — none of the four Path D signals apply, and language preference isn't a payoff</li>
<li>D. Decline and require a rewrite to C# instead</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>C.</strong> Startup cost doesn't dominate at twice a week, there's no cross-platform need, no capability gap is named, and the resource isn't a product. Path C is the correct end state here.</p>
</details>
