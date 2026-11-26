---
title: "Path D: Going native"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:07:39.000Z"
custom_template: "custom-lesson"
---

<p>The final path is the full rewrite into a <strong>command-based resource</strong> with its own manifest: an executable the engine invokes directly, with no adapter in the chain and usually no PowerShell host either.</p>
<p>Building one is a subject of its own, and <em>The Microsoft DSC Handbook</em> devotes a full chapter to it. What belongs in a migration course is the decision of <em>when</em> Path D is worth it, because rewriting working PowerShell into another language is a real cost that needs a real payoff.</p>
<h2 id="what-changes">What changes</h2>
<table>
<thead>
<tr>
<th></th>
<th>Adapted resource (Paths A to C)</th>
<th>Native command resource (Path D)</th>
</tr>
</thead>
<tbody>
<tr>
<td>Discovery</td>
<td>Adapter scans module paths</td>
<td>Engine reads a <code>.dsc.resource.json</code> manifest</td>
</tr>
<tr>
<td>Invocation</td>
<td>Engine → adapter → PowerShell host → module</td>
<td>Engine → executable</td>
</tr>
<tr>
<td>Contract</td>
<td>PowerShell properties</td>
<td>JSON on stdin/stdout, schema in the manifest</td>
</tr>
<tr>
<td>Startup cost</td>
<td>PowerShell host per invocation</td>
<td>Process start only</td>
</tr>
<tr>
<td>Capability declarations</td>
<td>Limited by the adapter</td>
<td>Full: <code>whatIfArg</code>, <code>implementsPretest</code>, <code>handlesExist</code>, and more</td>
</tr>
<tr>
<td>Distribution</td>
<td>Module on a gallery or a share</td>
<td>A binary, or a script with a manifest</td>
</tr>
</tbody>
</table>
<p>The manifest is the heart of it. Instead of the adapter inferring a contract from attributes, you declare it:</p>
<pre><code class="language-json">{
  "$schema": "https://aka.ms/dsc/schemas/v3/bundled/resource/manifest.json",
  "type": "BinderyOps/AppEnvironment",
  "version": "3.0.0",
  "get": {
    "executable": "bindery-appenv",
    "args": ["get", { "jsonInputArg": "--input" }]
  },
  "set": {
    "executable": "bindery-appenv",
    "args": ["set", { "jsonInputArg": "--input" }],
    "implementsPretest": true
  },
  "schema": {
    "command": {
      "executable": "bindery-appenv",
      "args": ["schema"]
    }
  }
}
</code></pre>
<p>Nothing in that file mentions PowerShell. The executable could be Rust, Go, C#, Python, or a shell script. The engine cares only that it reads JSON and writes JSON.</p>
<p><img src="https://storage.ghost.io/c/dd/64/dd64ba9d-7bdd-441e-bb5f-13f8be709814/content/images/2026/10/adapted-vs-native-invocation.png" alt="Figure 1: What Path D removes from the invocation chain." loading="lazy"></p>
<h2 id="native-doesnt-have-to-mean-another-language">Native doesn't have to mean another language</h2>
<p>A command-based resource needs an executable, and <code>pwsh</code> is an executable. Nothing stops you from writing a manifest that calls PowerShell directly and keeping the resource logic in a script you already know how to maintain.</p>
<p>The <code>Microsoft.PowerShell.PSResourceGet/PSResourceList</code> resource in the PSResourceGet repository works this way. Its <a href="https://github.com/PowerShell/PSResourceGet/blob/master/src/dsc/psresourcelist.dsc.resource.json">manifest</a> declares <code>pwsh</code> as the executable for every operation and pipes the JSON input into one script. The same pattern for <code>AppEnvironment</code> looks like this:</p>
<pre><code class="language-json">{
  "$schema": "https://aka.ms/dsc/schemas/v3/bundled/resource/manifest.json",
  "type": "BinderyOps/AppEnvironment",
  "version": "3.0.0",
  "get": {
    "executable": "pwsh",
    "args": [
      "-NoLogo",
      "-NonInteractive",
      "-NoProfile",
      "-Command",
      "$Input | ./appenvironment.resource.ps1 -Operation get; exit $LASTEXITCODE"
    ],
    "input": "stdin"
  },
  "set": {
    "executable": "pwsh",
    "args": [
      "-NoLogo",
      "-NonInteractive",
      "-NoProfile",
      "-Command",
      "$Input | ./appenvironment.resource.ps1 -Operation set; exit $LASTEXITCODE"
    ],
    "input": "stdin"
  },
  "delete": {
    "executable": "pwsh",
    "args": [
      "-NoLogo",
      "-NonInteractive",
      "-NoProfile",
      "-Command",
      "$Input | ./appenvironment.resource.ps1 -Operation delete; exit $LASTEXITCODE"
    ],
    "input": "stdin"
  }
}
</code></pre>
<p>The script reads JSON from the pipeline, does the work, and writes JSON to stdout. That's the whole contract, and it's the same one a compiled binary would follow.</p>
<p>This middle road gets you part of what Path D offers:</p>
<table>
<thead>
<tr>
<th></th>
<th>PowerShell script behind a manifest</th>
<th>Compiled executable</th>
</tr>
</thead>
<tbody>
<tr>
<td>Adapter in the chain</td>
<td>No</td>
<td>No</td>
</tr>
<tr>
<td>Manifest-declared contract, schema, and exit codes</td>
<td>Yes</td>
<td>Yes</td>
</tr>
<tr>
<td><code>delete</code>, <code>whatIf</code>, <code>export</code>, and <code>_exist</code> handled by the resource</td>
<td>Yes</td>
<td>Yes</td>
</tr>
<tr>
<td>PowerShell host startup per invocation</td>
<td>Still paid</td>
<td>Gone</td>
</tr>
<tr>
<td>PowerShell 7 required on the target</td>
<td>Yes</td>
<td>No</td>
</tr>
<tr>
<td>Language your team rewrites into</td>
<td>None</td>
<td>A new one</td>
</tr>
</tbody>
</table>
<p>Read that against the four signals below. A <code>pwsh</code> manifest answers the capability signal in full, because the delete operation the adapter couldn't give you in unit 6 is now yours to declare. It helps with the product signal, since consumers get a manifest and a documented contract. It does nothing for startup cost or for platforms without PowerShell, because the host is still in the chain.</p>
<blockquote>
<p>[!TIP]<br>
If the capability surface is the reason you're considering Path D, try the <code>pwsh</code> manifest first. You keep the PowerShell code and its edge cases, and a later port to a compiled language can reuse the same manifest shape and the same tests.</p>
</blockquote>
<h2 id="the-four-signals">The four signals</h2>
<p>Reach for Path D when a resource shows one of these. If none apply, stop at Path C with a clear conscience.</p>
<h3 id="startup-cost-dominates">Startup cost dominates</h3>
<p>Every adapted invocation pays for a PowerShell host. For a single <code>dsc config set</code> on a maintenance window, that cost is invisible. A resource invoked constantly is a different story. When a scheduler calls it every few minutes, a pipeline calls it on every commit, or an AI agent calls it while exploring state, a native binary's near-instant startup changes the economics entirely.</p>
<p>Measure before you assume:</p>
<pre><code class="language-powershell">Measure-Command {
    dsc resource get --resource BinderyOps/AppEnvironment --input $instance
}
</code></pre>
<p>Run it ten times and look at the median. If host startup is the majority of that number and the resource runs thousands of times a day, you have a business case. If it runs twice a week, you don't.</p>
<h3 id="you-need-platforms-powershell-modules-serve-poorly">You need platforms PowerShell modules serve poorly</h3>
<p>A native resource compiled for Linux and macOS beats "install PowerShell 7 everywhere first" as a deployment story. This matters most for the foundational resources at the bottom of your stack. Those are the ones that have to run before anything else is configured, including, occasionally, PowerShell itself.</p>
<h3 id="you-want-the-full-capability-surface">You want the full capability surface</h3>
<p>Native what-if support via <code>whatIfArg</code>, <code>implementsPretest</code>, <code>handlesExist</code>, and fine-grained capability declarations belong to resource manifests, not to adapted resources.</p>
<p><code>implementsPretest</code> is the one people miss. It tells the engine the resource performs its own idempotency check inside <code>set</code>, which means the engine skips the separate test call. That halves the invocations for a resource that's already correct.</p>
<h3 id="the-resource-is-a-product-not-a-script">The resource is a product, not a script</h3>
<p>If other teams or customers consume your resource, the single-binary distribution model and the language-agnostic contract are worth the rewrite on their own. You stop shipping "a module, plus a supported PowerShell version, plus a module path convention" and start shipping a file.</p>
<h2 id="when-path-d-is-the-wrong-answer">When Path D is the wrong answer</h2>
<p>Be equally clear about this, because Path D is the path people choose for the wrong reasons:</p>
<ul>
<li><strong>"The team prefers Go."</strong> Language preference isn't a payoff and won't survive a budget conversation.</li>
<li><strong>"Native is more modern."</strong> A class-based resource on PowerShell 7 is a fully supported, long-term-viable end state. Modernity is not a requirement.</li>
<li><strong>"We'll do it while we're in there."</strong> Combining a rewrite with a migration means that when behavior changes, you can't tell which change caused it. Migrate first, verify, <em>then</em> rewrite.</li>
<li><strong>"It's only a few hundred lines."</strong> Those few hundred lines contain every edge case the resource learned in production. Porting them to a language with different semantics is where migrations lose days.</li>
</ul>
<blockquote>
<p>[!IMPORTANT]<br>
Path D is the only path that changes the resource's <em>contract</em> as well as its implementation. This is the moment to drop <code>Ensure</code> and keep <code>_exist</code> alone, since you're breaking compatibility anyway. It also means every document that still says <code>Ensure</code> needs updating in the same change. Plan the document updates as part of the rewrite, not after it.</p>
</blockquote>
<h2 id="a-staged-approach-that-works">A staged approach that works</h2>
<p>For the rare resource that genuinely earns Path D:</p>
<ol>
<li><strong>Ship Path C first.</strong> Get the resource onto PowerShell 7 and prove equivalence. You now have a reference implementation with tests.</li>
<li><strong>Write the native resource against those same tests.</strong> Every case you verified in Path C becomes a case the native version must also pass.</li>
<li><strong>Run both side by side.</strong> Different resource types (<code>BinderyOps/AppEnvironment</code> and <code>BinderyOps/AppEnvironmentNative</code>), same machine, compared results. That's the technique from unit 7, step 7.</li>
<li><strong>Cut over per document,</strong> not per estate. The old type keeps working while the new one proves itself.</li>
</ol>
<p>Notice that this is the same incremental pattern as every other path in this module: small steps, a working system between each one, and a test that compares the new thing to the old thing on a real machine.</p>
