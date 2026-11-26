---
title: "Knowledge check"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:14:25.000Z"
custom_template: "custom-lesson"
---

<p><strong>1. Your nodes run the LCM in <code>ApplyAndAutoCorrect</code> mode with a 15-minute frequency. What's the faithful Microsoft DSC replacement?</strong></p>
<ul>
<li>A. A scheduled task or systemd timer running <code>dsc config set</code> every 15 minutes</li>
<li>B. A scheduled task running <code>dsc config test</code> every 15 minutes</li>
<li>C. Setting <code>autoCorrect: true</code> in the configuration document</li>
<li>D. Nothing. Microsoft DSC auto-corrects by default</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>A.</strong> <code>ApplyAndAutoCorrect</code> means "converge on every check," which is <code>dsc config set</code> on a schedule. Answer B is the replacement for <code>ApplyAndMonitor</code>, which detects drift without correcting it.</p>
<p>Answers C and D describe behavior the engine doesn't have: Microsoft DSC is stateless and does nothing unless something invokes it.</p>
</details>
<hr>
<p><strong>2. Which LCM feature has <em>no</em> equivalent in Microsoft DSC, by design?</strong></p>
<ul>
<li>A. <code>PartialConfigurations</code></li>
<li>B. <code>RebootNodeIfNeeded</code></li>
<li>C. Cross-node <code>WaitFor*</code> resources</li>
<li>D. <code>ConfigurationModeFrequencyMins</code></li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>C.</strong> <code>WaitForAll</code> and its siblings let one node's LCM block on another node's state. Nothing replaces this, by design. Cross-node coordination belongs to the orchestration layer.</p>
<p>The others all have replacements: <code>Microsoft.DSC/Include</code>, <code>restartRequired()</code> with a caller decision, and a schedule you define.</p>
</details>
<hr>
<p><strong>3. A resource reports that a restart is required. What does Microsoft DSC do?</strong></p>
<ul>
<li>A. Reboots the node immediately</li>
<li>B. Reboots the node if <code>RebootNodeIfNeeded</code> is set in the document</li>
<li>C. Surfaces the restart requirement in the result and leaves the decision to the caller</li>
<li>D. Fails the configuration run with an error</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>C.</strong> Microsoft DSC never reboots anything on its own. Resources report restart requirements, <code>restartRequired()</code> surfaces that state, and whether the caller reboots now, queues for a maintenance window, or raises a ticket is a policy decision outside the enforcement engine.</p>
</details>
<hr>
<p><strong>4. Which statement about <code>secureString</code> parameters is accurate?</strong></p>
<ul>
<li>A. They encrypt the value in transit to the resource</li>
<li>B. They redact the value in results and traces, but don't encrypt it</li>
<li>C. They require a certificate on the target node</li>
<li>D. They can only be supplied from a secret extension</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> Secure types redact wherever the engine controls the output. The value still travels to the resource as JSON over the process boundary. That's a real improvement over a plaintext MOF on a file share, but describe it accurately: it stops writing secrets down, it doesn't encrypt them.</p>
</details>
<hr>
<p><strong>5. What's wrong with this document fragment?</strong></p>
<pre><code class="language-yaml">resources:
  - name: AppService
    properties:
      Password: "[secret('BinderyServicePassword', 'ProdVault')]"
</code></pre>
<ul>
<li>A. <code>secret()</code> requires exactly one argument</li>
<li>B. <code>secret()</code> returns a plain string, so the resolved value flows through results unredacted</li>
<li>C. Secrets can't be used in resource properties at all</li>
<li>D. Nothing. This is the recommended pattern</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> <code>secret()</code> fetches the value. It doesn't make it secure. Route it through a <code>secureString</code> parameter:</p>
<pre><code class="language-yaml">parameters:
  servicePassword:
    type: secureString
    defaultValue: "[secret('BinderyServicePassword', 'ProdVault')]"
</code></pre>
<p>and reference <code>[parameters('servicePassword')]</code> in the resource. Note also that the two-argument form shown, which names the vault, <em>is</em> correct and should be treated as mandatory style on any machine with more than one secret extension.</p>
</details>
<hr>
<p><strong>6. You've verified a migrated document with <code>dsc config test</code> and registered a scheduled task to run <code>dsc config set</code> every 15 minutes. The LCM on that node is still in <code>ApplyAndAutoCorrect</code>. What happens?</strong></p>
<ul>
<li>A. Nothing. The LCM detects that another engine is managing the node</li>
<li>B. Both engines enforce their own desired state, and each reports success while the setting flaps</li>
<li>C. The LCM takes precedence and the scheduled task fails</li>
<li>D. The scheduled task takes precedence and the LCM stops</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> Two schedulers fighting over one setting, both correctly reporting success. It stays invisible while both agree and surfaces the moment the desired values diverge. Disable the LCM's configuration in the same change in which the new schedule takes over, not in the same sprint.</p>
</details>
<hr>
<p><strong>7. Your scheduled task shows <code>LastTaskResult: 0</code>. What does that prove?</strong></p>
<ul>
<li>A. The configuration converged successfully</li>
<li>B. The process ran and exited cleanly. It proves nothing about whether resources reached desired state</li>
<li>C. No drift was detected</li>
<li>D. The document is syntactically valid</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> An exit code tells you the process ran. To know what happened to the resources, capture the JSON output of <code>dsc config set --output-format json</code> and check <code>hadErrors</code> and each resource's <code>inDesiredState</code>. A schedule that discards its output has replaced the LCM's reporting with nothing.</p>
</details>
<hr>
<p><strong>8. Your team wants to convert 400 MOFs over a weekend. What's the argument against it?</strong></p>
<ul>
<li>A. <code>Convert-MofToDsc</code> can't process that many files</li>
<li>B. Mechanical conversion scales but review doesn't, because each document needs decisions on the four blind spots</li>
<li>C. The import extension rate-limits conversions</li>
<li>D. Converted documents can't be committed to source control</li>
</ul>
<details>
<summary>Show answer</summary>
<p><strong>B.</strong> Credentials, node names, flattened composites, and lost implicit ordering each need a human decision. Four hundred unreviewed documents is worse than four hundred MOFs. Convert per service, verify each against live systems with <code>dsc config test</code>, and let each document earn its way into the repository.</p>
</details>
