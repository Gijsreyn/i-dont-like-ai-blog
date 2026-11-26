---
title: "Introduction to migrating from PowerShell DSC"
status: published
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-19T03:20:00.000Z"
custom_template: "custom-lesson"
---

<p>Everything most DSC tutorials teach you assume that you're starting from a fresh clean machine, a new configuration document, and the latest resources. That's rarely the reality.</p>
<p>If you've been working with PowerShell DSC for years, you have an <em>estate</em>. Folders full of <code>Configuration</code> scripts. Compiled MOF files sitting on pull servers. A custom script resource written in 2016 that nobody dares to touch. Scheduled Local Configuration Manager (LCM) runs that keep production servers in shape while everyone's attention is elsewhere.</p>
<p>That estate doesn't disappear because a new engine shipped. And here's the good news: it doesn't have to. Microsoft built a migration story into DSC from the start. The PowerShell adapters run your existing modules. You can write your own import extension translating MOF files on the fly. Modern resource patterns show you what a rewrite looks like when you decide one is worth it.</p>
<p>What's missing is the <em>connection</em> between those pieces: a structured way to look at what you have, decide per resource and per configuration what to do with it, and execute that decision without breaking production. That's what this module gives you.</p>
<p><img src="https://storage.ghost.io/c/dd/64/dd64ba9d-7bdd-441e-bb5f-13f8be709814/content/images/2026/09/0GrzWVCr2DkB0M9-.png" alt="Figure 1: Illustration from old to new." loading="lazy"></p>
<h2 id="scenario">Scenario</h2>
<p>You're the platform engineer at <strong>Bindery</strong>, a company that manufactures and ships books. Bindery's operations team has run PowerShell DSC since 2017. Their estate is modest by enterprise standards, and typical:</p>
<ul>
<li>A module called <code>BinderyOps</code> with a script-based resource, <code>AppEnvironment</code>, that manages machine-level environment variables.</li>
<li>A <code>Configuration</code> script, <code>LegacyWebServer.ps1</code>, that combines <code>AppEnvironment</code> with the built-in <code>File</code> resource.</li>
<li>Compiled MOF files on a pull server, some of which no longer have a matching source script anywhere in source control.</li>
<li>LCM settings that run a consistency check every 15 minutes in <code>ApplyAndAutoCorrect</code> mode.</li>
</ul>
<p>Leadership has asked for a migration plan. A <em>plan</em>, not a migration. They want to know what moves, what stays, what it costs, and what breaks. Your first job is to find out what you actually own.</p>
<h2 id="learning-objectives">Learning objectives</h2>
<p>By the end of this module, you'll be able to:</p>
<ul>
<li>Explain the reasons to migrate from PowerShell DSC, and the equally reasons to delay.</li>
<li>Classify the four artifact types in a PowerShell DSC estate and describe how each one migrates.</li>
<li>Build a migration inventory that shows which resources each Microsoft DSC adapter can already discover.</li>
<li>Assign every resource and configuration to one of four migration paths, with a defensible rationale.</li>
</ul>
<h2 id="prerequisites">Prerequisites</h2>
<ul>
<li>Practical experience authoring and compiling PowerShell DSC configurations</li>
<li>Familiarity with Microsoft DSC configuration documents and the <code>dsc</code> CLI</li>
<li>A Windows machine with Windows PowerShell 5.1, PowerShell 7+, and the <code>dsc</code> CLI installed</li>
</ul>
