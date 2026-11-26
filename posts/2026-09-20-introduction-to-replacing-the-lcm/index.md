---
title: "Introduction to replacing the LCM"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:11:18.000Z"
custom_template: "custom-lesson"
---

<p>Modules 1 and 2 migrated <em>files</em>: configuration scripts, MOFs, resource modules. This module migrates something that was never a file.</p>
<p>The <a href="https://learn.microsoft.com/en-us/powershell/dsc/managing-nodes/metaconfig?view=dsc-1.1">Local Configuration Manager</a> is what made PowerShell DSC feel like a management system rather than a set of scripts. It ran a consistency check every 15 minutes whether or not anyone thought about it. It pulled configurations from a server. It rebooted nodes when a resource asked. It waited for other nodes to reach a state before continuing. It reported status to a central endpoint.</p>
<p>Microsoft DSC has none of that, deliberately. The engine is stateless: a document goes in, a result comes out, nothing is scheduled and nothing is remembered.</p>
<p>That sounds like a loss until you notice what it buys. Every LCM behavior was a <em>policy</em> decision: how often to converge, whether to auto-correct, when to reboot. Each one was implemented inside the enforcement engine and configurable only through a meta-configuration. Microsoft DSC moves those decisions out to the caller, where you can see them, version them, and review them.</p>
<p>The catch is that "you can see them" also means "you have to make them." This module makes each one explicit.</p>
<p><img src="https://storage.ghost.io/c/dd/64/dd64ba9d-7bdd-441e-bb5f-13f8be709814/content/images/2026/10/lcm-responsibilities-redistributed.png" alt="Figure 1: Nothing disappeared. Each responsibility moved to a layer where you own it explicitly." loading="lazy"></p>
<h2 id="learning-objectives">Learning objectives</h2>
<p>By the end of this module, you'll be able to:</p>
<ul>
<li>Map every LCM feature your estate depends on to its Microsoft DSC equivalent, or to the explicit statement that no equivalent exists.</li>
<li>Replace scheduled enforcement with a scheduler you own, on Windows or Linux.</li>
<li>Handle reboot requirements and cross-node coordination outside the enforcement engine.</li>
<li>Migrate credentials from plaintext or certificate-encrypted MOFs to <code>secureString</code> parameters and secret extensions.</li>
<li>Run an end-to-end equivalence check proving every migration route converges on the same state.</li>
</ul>
<h2 id="before-you-start">Before you start</h2>
<p>You need everything from Module 2:</p>
<ul>
<li><code>webserver-adapted.dsc.config.yaml</code>: the Path A document on the 5.1 adapter</li>
<li><code>webserver-imported.dsc.config.json</code>: the Path B document converted from MOF</li>
<li><code>webserver-ps7.dsc.config.yaml</code>: the Path C document on the PowerShell 7 adapter</li>
<li>A converged machine, and the LCM still running on its old cadence</li>
</ul>
<p>That last item is not an oversight. Unit 3 covers switching it off, and the order matters more than most teams expect.</p>
