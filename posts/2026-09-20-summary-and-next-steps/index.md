---
title: "Summary and next steps"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:14:44.000Z"
custom_template: "custom-lesson"
---

<p>You've migrated an estate end to end: inventory, four paths, LCM replacement, and a verification loop that proves it.</p>
<h2 id="what-you-did-in-this-module">What you did in this module</h2>
<ul>
<li><strong>Mapped every LCM feature</strong> to its Microsoft DSC equivalent, or to the explicit statement that no equivalent exists, and audited your own meta-configuration to find out what your estate actually relied on.</li>
<li><strong>Took ownership of the schedule</strong>, replacing <code>ConfigurationMode</code> and <code>ConfigurationModeFrequencyMins</code> with a scheduled task or systemd timer that you author, version, and can manage with DSC itself.</li>
<li><strong>Made reboots a caller decision</strong> using <code>restartRequired()</code>, and moved cross-node coordination up to the orchestration layer where it can see more than one node.</li>
<li><strong>Migrated credentials</strong> from plaintext and certificate-encrypted MOFs to <code>secureString</code> parameters, with secret extensions supplying values at runtime.</li>
<li><strong>Proved equivalence</strong> across all four routes against one machine, then retired the LCM on that node in the right order.</li>
</ul>
<h2 id="the-whole-course-in-five-sentences">The whole course in five sentences</h2>
<ol>
<li>Build an inventory that joins the classic <code>Get-DscResource</code> view with both adapter views, because the gap between them is your migration backlog.</li>
<li>Assign each artifact to one of four paths (adapt, import, class-based rewrite, native rewrite) and justify each choice with cost and payoff.</li>
<li>Move the orchestration layer first (Paths A and B), which leaves resource code untouched and makes the deeper rewrites safe to do one at a time.</li>
<li>Replace the LCM's background behaviors with explicit, scheduled, reviewable equivalents that you own.</li>
<li>Verify everything with <code>dsc config test</code> against live machines, because a table beats an argument.</li>
</ol>
<h2 id="key-takeaways">Key takeaways</h2>
<blockquote>
<p>If nothing invokes the engine, nothing happens. That's the whole operational change, and everything else in Module 3 follows from it.</p>
</blockquote>
<ul>
<li>Every LCM setting was a policy decision implemented inside the enforcement engine. Microsoft DSC moves those decisions out to where you can see and review them, which means you have to actually make them.</li>
<li>Two engines enforcing one setting is invisible until it isn't. Ownership of a node is binary, and the handover is a single step.</li>
<li><code>secureString</code> redacts. It doesn't encrypt. Describe it accurately, and rotate anything that ever lived in a plaintext MOF.</li>
<li>Structured results are the feature that makes everything else possible: drift detection, pipeline gates, run history, and the equivalence check you built in unit 6.</li>
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
<td><code>Get-DscLocalConfigurationManager</code></td>
<td>Audit what the LCM was configured to do</td>
</tr>
<tr>
<td><code>Remove-DscConfigurationDocument -Stage Current, Pending, Previous -Force</code></td>
<td>Stop the LCM from enforcing on a node</td>
</tr>
<tr>
<td><code>Register-ScheduledTask</code> / <code>systemctl enable --now &lt;timer&gt;</code></td>
<td>Own the enforcement schedule</td>
</tr>
<tr>
<td><code>dsc config set --file &lt;doc&gt; --output-format json</code></td>
<td>Enforce and capture structured results</td>
</tr>
<tr>
<td><code>[restartRequired('system')]</code></td>
<td>Surface restart requirements to the caller</td>
</tr>
<tr>
<td><code>[secret('&lt;name&gt;', '&lt;vault&gt;')]</code></td>
<td>Resolve a secret at runtime, via a <code>secureString</code> parameter</td>
</tr>
<tr>
<td><code>dsc config test --file &lt;doc&gt; --output-format json</code></td>
<td>The verification loop, and the basis of every gate</td>
</tr>
</tbody>
</table>
<h2 id="where-to-go-next">Where to go next</h2>
<p><strong>Automate the verification loop.</strong> Every check in this course was run by hand. The natural next step is a pipeline where <code>dsc config test</code> is a gate on every commit, and <code>dsc config set</code> is a deployment step with approval. <em>The Microsoft DSC Handbook</em> covers this in its DevOps pipelines chapter.</p>
<p><strong>Decide your pull-mode story.</strong> If you retired a pull server, something has to take over registration, distribution, and reporting. Evaluate <a href="https://github.com/OpenDSC">OpenDSC</a> against your support requirements, or design the orchestration layer you'll build instead.</p>
<p><strong>Harden what you migrated.</strong> The security chapter of the handbook goes deeper than unit 5 could: secret extensions, trace surfaces, and the failure modes of secure types.</p>
<p><strong>Run the drill on something real.</strong> This course used an estate small enough to follow in one sitting. Pick one service in your production estate, run the same sequence (inventory, path, translate, verify, cut over, capture), and you'll have both a migrated service and a runbook for the next one.</p>
<h2 id="learn-more">Learn more</h2>
<ul>
<li><em>The Microsoft DSC Handbook</em>, Chapter 11: the written source for this course</li>
<li><em>The Microsoft DSC Handbook</em>, Chapter 9: higher-order tools and OpenDSC</li>
<li><em>The Microsoft DSC Handbook</em>, Chapter 12: DSC in DevOps pipelines</li>
<li><em>The Microsoft DSC Handbook</em>, Chapter 13: security, secrets, and trace surfaces</li>
<li><a href="https://github.com/PowerShell/DSC/issues/450">DSC issue #450</a>: the generic restart resources proposal</li>
</ul>
