---
title: "Migrate credentials"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:13:04.000Z"
custom_template: "custom-lesson"
---

<p>Credentials deserve their own unit because they're the one place where "translate it mechanically" is the wrong answer.</p>
<h2 id="what-youre-migrating-away-from">What you're migrating away from</h2>
<p>In PowerShell DSC, a <code>PSCredential</code> property left you two options, both bad:</p>
<p><strong>Option 1: plaintext.</strong> Set <code>PSDscAllowPlainTextPassword = $true</code> in the configuration data, and the password is written into the MOF file in the clear. That MOF then sat on a pull server, in a build artifact, in a backup, and in whatever folder someone copied it to while troubleshooting.</p>
<p><strong>Option 2: certificate encryption.</strong> Generate a certificate per node, distribute the public key to the build machine, encrypt the credential at compile time, and make sure the private key is on the target node before the MOF arrives. It works. It also means certificate lifecycle management, renewal, and a class of failures where a MOF can't be decrypted and nobody remembers why.</p>
<p>Both options share one flaw: the secret's <em>value</em> was baked into the artifact at compile time. The artifact was the secret.</p>
<h2 id="what-youre-migrating-to">What you're migrating to</h2>
<p>Microsoft DSC separates the <strong>shape</strong> from the <strong>source</strong>.</p>
<p>The document declares that a value is sensitive using a <code>secureString</code> parameter:</p>
<pre><code class="language-yaml">parameters:
  servicePassword:
    type: secureString
resources:
  - name: AppService
    type: BinderyOps/ManagedService
    directives:
      requireAdapter: Microsoft.Adapter/PowerShell
    properties:
      Name: BinderySync
      Credential:
        UserName: svc-bindery
        Password: "[parameters('servicePassword')]"
</code></pre>
<p>The document contains no secret. It contains the <em>statement</em> that a secret goes here.</p>
<p>Where the value comes from is a separate decision made at invocation time:</p>
<table>
<thead>
<tr>
<th>Source</th>
<th>How</th>
<th>Fits</th>
</tr>
</thead>
<tbody>
<tr>
<td>A parameters file that exists only inside a pipeline run</td>
<td><code>--parameters-file secrets.json</code>, generated from the pipeline's secret store</td>
<td>CI/CD-driven estates</td>
</tr>
<tr>
<td>A DevOps secret store, injected as an environment variable</td>
<td>Build the parameters JSON at runtime</td>
<td>Teams already using pipeline secrets</td>
</tr>
<tr>
<td>A secret extension</td>
<td><code>secret()</code> resolving from Azure Key Vault or Windows Credential Manager</td>
<td>Node-local enforcement, scheduled runs</td>
</tr>
</tbody>
</table>
<p><img src="images/2026-10-credential-sources.png" alt="Figure 1: One document, three legitimate sources. The document doesn't change when the source does." loading="lazy"></p>
<h2 id="what-secure-types-do-and-dont-do">What secure types do and don't do</h2>
<p>When a value is typed secure, DSC redacts it wherever the engine controls the output: results show <code>&lt;secureValue&gt;</code> instead of the value, and trace messages redact it the same way.</p>
<blockquote>
<p>[!WARNING]<br>
Secure types <strong>redact; they don't encrypt</strong>. A <code>secureString</code> travels to the resource as JSON over the process boundary. The protection is against casual and systemic exposure in outputs, logs, and artifacts — not against an attacker who can already read the memory or stderr of your elevated DSC process.</p>
</blockquote>
<p>That's still a improvement over a plaintext MOF on a file share, but state it accurately when someone asks whether the migration "encrypts credentials." It doesn't. It stops writing them down.</p>
<h2 id="resolving-from-a-vault">Resolving from a vault</h2>
<p>Secret extensions let the document resolve values at runtime rather than receiving them:</p>
<pre><code class="language-yaml">parameters:
  servicePassword:
    type: secureString
    defaultValue: "[secret('BinderyServicePassword', 'ProdVault')]"
</code></pre>
<p>Two details matter here, and both catch people:</p>
<p><strong>Always name the vault.</strong> <code>secret('Name')</code> queries <em>every</em> registered extension with the secret capability, on every use. <code>secret('Name', 'ProdVault')</code> queries only that one. On any machine with more than one secret extension installed, treat the two-argument form as mandatory style — it avoids ambiguity errors, and it documents the secret's origin in the configuration where a reviewer can see it.</p>
<p><strong><code>secret()</code> returns a plain string, not a <code>secureString</code>.</strong> Use it directly in a resource property and the resolved value flows through results unredacted:</p>
<pre><code class="language-yaml"># Wrong: the resolved value appears in results and traces
properties:
  Password: "[secret('BinderyServicePassword', 'ProdVault')]"
</code></pre>
<pre><code class="language-yaml"># Right: the secret is routed through a secure-typed parameter
parameters:
  servicePassword:
    type: secureString
    defaultValue: "[secret('BinderyServicePassword', 'ProdVault')]"
resources:
  - name: AppService
    properties:
      Password: "[parameters('servicePassword')]"
</code></pre>
<p>The parameter is what makes the value secure. The function is only what fetches it.</p>
<h2 id="the-migration-rule-of-thumb">The migration rule of thumb</h2>
<p>Two mechanical rules cover most of an estate:</p>
<ol>
<li>
<p><strong>Every <code>PSDscAllowPlainTextPassword</code> you find becomes a <code>secureString</code> parameter.</strong> Search for it and treat each hit as a required change, not a candidate:</p>
<pre><code class="language-powershell">Get-ChildItem -Path .\ -Filter *.ps1 -Recurse |
    Select-String -Pattern 'PSDscAllowPlainTextPassword'
</code></pre>
</li>
<li>
<p><strong>Every certificate-encryption setup becomes a conversation about which secret source replaces it.</strong> Nodes with a <code>CertificateID</code> in their meta-configuration (unit 2) are the list to work through.</p>
</li>
</ol>
<p>And one rule that isn't mechanical at all:</p>
<ol start="3">
<li><strong>Assume every secret in a legacy MOF is burned.</strong> A password that sat in a plaintext MOF on a pull server, or in a build artifact, or in a repository, should be rotated during migration rather than carried across. The migration is the cheapest opportunity you'll ever have to rotate them, because you're touching every configuration anyway.</li>
</ol>
<blockquote>
<p>[!IMPORTANT]<br>
Path B drops credentials on purpose when it converts a MOF. The importer can't translate them, and it shouldn't try. If a converted document is missing a credential property, the conversion didn't fail. It left you the one decision a person has to make: where that secret comes from now.</p>
</blockquote>
<h2 id="review-a-migrated-document-for-leaks">Review a migrated document for leaks</h2>
<p>Before committing any migrated document, check three things:</p>
<ul>
<li>[ ] No <code>defaultValue</code> in the repository holds a real secret. If it does, that secret is burned the moment the file is committed.</li>
<li>[ ] No <code>Microsoft.DSC/Echo</code> resource reflects a credential property.</li>
<li>[ ] Running with <code>--trace-level debug --trace-format json</code> shows <code>&lt;secureValue&gt;</code> where the secret should be, not the value.</li>
</ul>
<p>That third check takes thirty seconds and is the only one that tests what actually happens rather than what you intended.</p>
