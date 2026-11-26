---
title: "Map LCM features to Microsoft DSC"
status: published
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:11:47.000Z"
custom_template: "custom-lesson"
---

<p>During migration planning, someone will ask about every single LCM setting. Here's the complete mapping in one place, so the answer is a row in a table rather than a research task.</p>
<table>
<thead>
<tr>
<th>LCM feature</th>
<th>Microsoft DSC equivalent</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>ApplyOnly</code> mode</td>
<td>Run <code>dsc config set</code> once (from a pipeline, script, or by hand)</td>
</tr>
<tr>
<td><code>ApplyAndMonitor</code> mode</td>
<td>Schedule <code>dsc config test</code> and alert on drift; nothing auto-corrects</td>
</tr>
<tr>
<td><code>ApplyAndAutoCorrect</code> mode</td>
<td>Schedule <code>dsc config set</code>; each run converges the machine</td>
</tr>
<tr>
<td><code>ConfigurationModeFrequencyMins</code></td>
<td>The schedule you define in Task Scheduler, cron, or your orchestrator</td>
</tr>
<tr>
<td><code>RefreshMode = 'Pull'</code> + pull server</td>
<td>A higher-order tool such as OpenDSC</td>
</tr>
<tr>
<td><code>RebootNodeIfNeeded</code></td>
<td>The <code>restartRequired()</code> function and restart metadata; the <em>caller</em> decides to reboot</td>
</tr>
<tr>
<td><code>PartialConfigurations</code></td>
<td><code>Microsoft.DSC/Include</code> composing multiple documents</td>
</tr>
<tr>
<td>Cross-node <code>WaitFor*</code> resources</td>
<td>No equivalent by design; cross-node coordination belongs to your orchestration layer</td>
</tr>
<tr>
<td><code>PSDscAllowPlainTextPassword</code></td>
<td>Gone, and good riddance: <code>secureString</code> parameters and the <code>secret()</code> function</td>
</tr>
<tr>
<td>MOF encryption certificates</td>
<td>Not needed; documents hold no secrets when parameterized correctly</td>
</tr>
<tr>
<td><code>DscLocalConfigurationManager</code> state</td>
<td>Nothing; the engine is stateless, results are returned to the caller</td>
</tr>
</tbody>
</table>
<h2 id="read-the-table-as-three-groups">Read the table as three groups</h2>
<p>The rows aren't equivalent in kind. They fall into three groups, and conflating them is what makes migration planning meetings run long.</p>
<h3 id="group-1-direct-substitutions">Group 1: Direct substitutions</h3>
<p><code>ApplyOnly</code>, <code>ApplyAndMonitor</code>, <code>ApplyAndAutoCorrect</code>, and <code>ConfigurationModeFrequencyMins</code> all reduce to "which command, how often." There's no conceptual gap here — only a decision about where the schedule lives, which unit 3 covers.</p>
<p><code>PartialConfigurations</code> is also a direct substitution. What the LCM assembled from multiple sources, <code>Microsoft.DSC/Include</code> composes explicitly in a document:</p>
<pre><code class="language-yaml">resources:
  - name: Baseline
    type: Microsoft.DSC/Include
    properties:
      configurationFile: ./baseline.dsc.config.yaml
  - name: WebRole
    type: Microsoft.DSC/Include
    properties:
      configurationFile: ./webserver-adapted.dsc.config.yaml
</code></pre>
<p>The difference is visibility. Partial configurations arrived from wherever the LCM was told to look, and reconstructing what a node actually ran meant querying the node. An <code>Include</code> is a line in a file you can read in a pull request.</p>
<h3 id="group-2-responsibilities-that-moved-to-you">Group 2: Responsibilities that moved to you</h3>
<p><code>RefreshMode = 'Pull'</code> and <code>RebootNodeIfNeeded</code> didn't disappear — they moved out of the engine.</p>
<p>Pull mode needs a higher-order tool. Today, that's <a href="https://github.com/OpenDSC">OpenDSC</a>, a community project that acts as the enforcement and orchestration layer above the engine: nodes register, receive configurations, report results.</p>
<blockquote>
<p>[!IMPORTANT]<br>
OpenDSC is community-driven open source and isn't officially supported by Microsoft. If your organization requires vendor support for the enforcement layer, decide that before decommissioning a pull server.</p>
</blockquote>
<p>Reboot policy moved to the caller, which unit 4 covers in detail.</p>
<h3 id="group-3-things-that-were-cut-not-moved">Group 3: Things that were cut, not moved</h3>
<p>Cross-node <code>WaitFor*</code> resources have <strong>no equivalent, deliberately</strong>. So does LCM state.</p>
<p>This is the group that surprises people, because the honest answer is "that feature is gone and you need to redesign around it." Unit 4 covers what to do instead.</p>
<h2 id="three-rows-that-change-who-is-responsible">Three rows that change <em>who</em> is responsible</h2>
<p>Three of these deserve more than a table row, because they change accountability rather than syntax:</p>
<p><strong>Scheduled enforcement is now yours to own.</strong> The LCM's consistency check ran every 15 minutes whether you thought about it or not. In Microsoft DSC, if nothing invokes the engine, nothing happens. → Unit 3.</p>
<p><strong>Reboots became explicit.</strong> The LCM would reboot a node mid-run when a resource requested it and <code>RebootNodeIfNeeded</code> was set. Microsoft DSC will never reboot anything on its own. → Unit 4.</p>
<p><strong>Cross-node coordination was cut, not misplaced.</strong> <code>WaitForAll</code> and its siblings let one node's LCM block on another node's state. Nothing replaces this. → Unit 4.</p>
<h2 id="audit-your-meta-configuration">Audit your meta-configuration</h2>
<p>Before you decide what to replace, find out what you actually configured. On any managed node:</p>
<pre><code class="language-powershell">Get-DscLocalConfigurationManager
</code></pre>
<p>Record these properties for each node class in your estate:</p>
<table>
<thead>
<tr>
<th>Property</th>
<th>What to record</th>
<th>Why it matters</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>ConfigurationMode</code></td>
<td><code>ApplyOnly</code>, <code>ApplyAndMonitor</code>, or <code>ApplyAndAutoCorrect</code></td>
<td>Determines whether your replacement runs <code>set</code> or <code>test</code></td>
</tr>
<tr>
<td><code>ConfigurationModeFrequencyMins</code></td>
<td>The interval</td>
<td>Your new schedule should start here, then be tuned</td>
</tr>
<tr>
<td><code>RefreshMode</code></td>
<td><code>Push</code> or <code>Pull</code></td>
<td>Pull means you need an orchestration layer before you can migrate</td>
</tr>
<tr>
<td><code>RebootNodeIfNeeded</code></td>
<td><code>$true</code> or <code>$false</code></td>
<td><code>$true</code> means something in your estate expects automatic reboots</td>
</tr>
<tr>
<td><code>PartialConfigurations</code></td>
<td>Names and sources</td>
<td>Each becomes an <code>Include</code> — or reveals a source nobody knew about</td>
</tr>
<tr>
<td><code>CertificateID</code></td>
<td>A thumbprint, or empty</td>
<td>Non-empty means encrypted credentials are in play; see unit 5</td>
</tr>
</tbody>
</table>
<p>A surprising number of estates discover at this point that half their nodes are in <code>ApplyAndMonitor</code> while everyone believed they were auto-correcting. Better to learn that now than during the first incident after cutover.</p>
<blockquote>
<p>[!TIP]<br>
Capture the meta-configuration for every node into a file before you change anything. It's the only record of what the old system was doing, and once the LCM is disabled, reconstructing it means reading old build scripts.</p>
<pre><code class="language-powershell">Get-DscLocalConfigurationManager |
    Select-Object ConfigurationMode, ConfigurationModeFrequencyMins,
                  RefreshMode, RebootNodeIfNeeded, CertificateID |
    Export-Csv -Path .\lcm-baseline.csv -NoTypeInformation -Append
</code></pre>
</blockquote>
