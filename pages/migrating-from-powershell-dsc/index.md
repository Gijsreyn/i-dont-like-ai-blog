---
title: "Migrating from PowerShell DSC to Microsoft DSC"
status: published
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-18T10:28:08.000Z"
custom_excerpt: "Learn how to migrate your PowerShell DSC estate to Microsoft DSC without breaking production"
feature_image: "https://storage.ghost.io/c/dd/64/dd64ba9d-7bdd-441e-bb5f-13f8be709814/content/images/2026/09/X7F8emKzV5Od8Uyo.png"
---

<!--kg-card-begin: html-->
<!--
  Course outline markup for: Migrate from PowerShell DSC to Microsoft DSC
  Course slug: migrating-from-powershell-dsc
  Lesson URLs follow https://idontlikeai.dev/courses/<course-slug>/<lesson-slug>/
-->

<details>
  <summary>
    <span class="section-title">Plan your migration
      Inventory your PowerShell DSC estate and choose a path for every artifact</span>
    <span class="section-lesson-count">7 Lessons</span>
  </summary>
  <ul>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/introduction-to-migrating-from-powershell-dsc/">Introduction to migrating from PowerShell DSC</a>
        </span>
        <span class="lesson-item-duration">4 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/why-migrate-and-when-not-to/">Why migrate, and when not to</a>
        </span>
        <span class="lesson-item-duration">8 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/inventory-what-you-have-psdsc/">Inventory what you have</a>
        </span>
        <span class="lesson-item-duration">12 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/build-and-inventory-the-bindery-estate/">Build and inventory the Bindery estate</a>
        </span>
        <span class="lesson-item-duration">20 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/choose-a-migration-path/">Choose a migration path</a>
        </span>
        <span class="lesson-item-duration">10 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/knowledge-check-plan-your-migration/">Knowledge check</a>
        </span>
        <span class="lesson-item-duration">5 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/summary-plan-your-migration/">Summary</a>
        </span>
        <span class="lesson-item-duration">3 min</span>
      </div>
    </li>
  </ul>
</details>

<details>
  <summary>
    <span class="section-title">Migrate configurations and resources
      Walk all four migration paths against one legacy estate</span>
    <span class="section-lesson-count">10 Lessons</span>
  </summary>
  <ul>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/introduction-to-migrating-configurations-and-resources/">Introduction to migrating configurations and resources</a>
        </span>
        <span class="lesson-item-duration">3 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/path-a-adapt-in-place/">Path A: Adapt in place</a>
        </span>
        <span class="lesson-item-duration">12 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/adapt-the-legacy-configuration/">Adapt the legacy configuration</a>
        </span>
        <span class="lesson-item-duration">15 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/path-b-import-your-compiled-mofs/">Path B: Import your compiled MOFs</a>
        </span>
        <span class="lesson-item-duration">12 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/convert-a-mof-file/">Convert a MOF file</a>
        </span>
        <span class="lesson-item-duration">15 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/path-c-from-script-based-to-class-based/">Path C: From script-based to class-based</a>
        </span>
        <span class="lesson-item-duration">15 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/rewrite-appenvironment-as-a-class/">Rewrite AppEnvironment as a class</a>
        </span>
        <span class="lesson-item-duration">20 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/path-d-going-native/">Path D: Going native</a>
        </span>
        <span class="lesson-item-duration">8 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/knowledge-check-migrate-configurations-and-resources/">Knowledge check</a>
        </span>
        <span class="lesson-item-duration">5 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/summary-migrate-configurations-and-resources/">Summary</a>
        </span>
        <span class="lesson-item-duration">3 min</span>
      </div>
    </li>
  </ul>
</details>

<details>
  <summary>
    <span class="section-title">Replace the LCM
      Own the enforcement schedule, handle reboots, and migrate credentials</span>
    <span class="section-lesson-count">9 Lessons</span>
  </summary>
  <ul>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/introduction-to-replacing-the-lcm/">Introduction to replacing the LCM</a>
        </span>
        <span class="lesson-item-duration">3 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/map-lcm-features-to-microsoft-dsc/">Map LCM features to Microsoft DSC</a>
        </span>
        <span class="lesson-item-duration">12 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/own-the-enforcement-schedule/">Own the enforcement schedule</a>
        </span>
        <span class="lesson-item-duration">10 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/reboots-and-cross-node-coordination/">Reboots and cross-node coordination</a>
        </span>
        <span class="lesson-item-duration">10 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/migrate-credentials/">Migrate credentials</a>
        </span>
        <span class="lesson-item-duration">10 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/prove-equivalence-end-to-end/">Prove equivalence end to end</a>
        </span>
        <span class="lesson-item-duration">20 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/pitfalls-from-the-field/">Pitfalls from the field</a>
        </span>
        <span class="lesson-item-duration">8 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/knowledge-check-replace-the-lcm/">Knowledge check</a>
        </span>
        <span class="lesson-item-duration">5 min</span>
      </div>
    </li>
    <li>
      <div class="lesson-item-content">
        <span class="lesson-item-title">
          <a href="https://idontlikeai.dev/courses/migrating-from-powershell-dsc/summary-and-next-steps/">Summary and next steps</a>
        </span>
        <span class="lesson-item-duration">5 min</span>
      </div>
    </li>
  </ul>
</details>

<!--kg-card-end: html-->
<h2 id="course-content">Course content</h2>
<p>This course takes you from a working PowerShell DSC estate to a Microsoft DSC estate, without a rewrite weekend and without breaking production. The planning module starts where every real migration starts: with an honest look at what you already own. You'll learn why the trajectory points to Microsoft DSC, build an inventory that classifies every resource on a machine, and use that inventory to assign each artifact to one of four migration paths.</p>
<p>Next, you'll walk all four paths against the same small legacy estate. You'll adapt a <code>Configuration</code> script into a configuration document with the resource code untouched, rescue a compiled MOF file whose source script is long gone, rewrite a script-based resource as a class-based one that runs on PowerShell 7, and learn the signals that justify a full native rewrite.</p>
<p>The final module deals with the part of PowerShell DSC that isn't a file: the Local Configuration Manager. You'll map every LCM behavior your estate might depend on to its Microsoft DSC equivalent, replace scheduled enforcement with something you own, move credentials out of MOF files, and run an end-to-end equivalence check that proves all three migration routes converge on the same machine state.</p>
<h2 id="prerequisites">Prerequisites</h2>
<p>Before starting this course, you should have:</p>
<ul>
<li><strong>PowerShell DSC experience:</strong> You've written <code>Configuration</code> blocks, compiled MOF files, and run <code>Start-DscConfiguration</code> at least a few times.</li>
<li><strong>Microsoft DSC fundamentals:</strong> You can read a configuration document, and you've run <code>dsc config get</code>, <code>dsc config test</code>, and <code>dsc config set</code> against one.</li>
<li><strong>PowerShell scripting:</strong> Functions, modules, module manifests, and enough class syntax to read a <code>[DscResource()]</code> class.</li>
<li><strong>A Windows machine:</strong> With both Windows PowerShell 5.1 and PowerShell 7+ installed, plus the <code>dsc</code> CLI on your path. Administrator rights are needed for the machine-level environment variable used in the exercises.</li>
</ul>
<p>Don't worry if you're rusty on the Microsoft DSC side. Each unit explains the construct before using it, and every command in the exercises is shown in full. The PowerShell DSC knowledge is the part that's hard to substitute, because this course is about translating something you already own.</p>
<blockquote>
<p>[!TIP]<br>
If you've never applied a configuration document with Microsoft DSC, work through the getting-started chapters of <a href="https://leanpub.com/themicrosoftdschandbook">The Microsoft DSC Handbook</a> or <a href="https://www.idontlikeai.dev/courses/the-fundamentals-of-microsoft-dsc/">The Fundamentals of Microsoft DSC</a> first. This course assumes the mechanics and focuses entirely on the translation.</p>
</blockquote>
<h2 id="what-youll-learn">What you'll learn</h2>
<ul>
<li><strong>Inventory a PowerShell DSC estate:</strong> Classify configurations, compiled MOFs, script-based resources, and class-based resources, and check what each Microsoft DSC adapter can already see.</li>
<li><strong>Choose a migration path per artifact:</strong> Apply a four-path decision framework — adapt in place, import MOFs, rewrite as class-based, rewrite as native — and defend the choice with cost and payoff, not preference.</li>
<li><strong>Execute each path hands-on:</strong> Translate <code>Configuration</code> scripts into configuration documents, convert MOF files with an import extension, and port <code>Get</code>/<code>Set</code>/<code>Test-TargetResource</code> trios into class-based resources.</li>
<li><strong>Replace the LCM:</strong> Map enforcement modes, refresh intervals, reboot policy, partial configurations, and cross-node coordination to explicit Microsoft DSC replacements that you schedule and own.</li>
<li><strong>Migrate credentials safely:</strong> Retire <code>PSDscAllowPlainTextPassword</code> and MOF encryption certificates in favor of <code>secureString</code> parameters and secret extensions.</li>
</ul>
<p>By the end of this course, you'll have migrated a complete (if small) estate end to end, including:</p>
<ul>
<li>A migration inventory report you can run against any machine</li>
<li>A configuration document that replaces a <code>Configuration</code> script</li>
<li>A class-based resource ported from a script-based one</li>
<li>A scheduled enforcement replacement for the LCM</li>
<li>An equivalence check that proves the migration didn't change behavior</li>
</ul>
<p>You'll understand the full lifecycle from "we have hundreds of MOFs and nobody remembers who wrote them" to a reviewed, tested, version-controlled Microsoft DSC estate.</p>
<h2 id="the-running-example">The running example</h2>
<p>Every unit uses the same fictional estate, owned by a company called <strong>Bindery</strong>. A bindery is a workshop where loose sheets are fastened together into books, which is a fair description of what a migration does: fasten an old estate to a new engine without tearing any pages.</p>
<p>Bindery's operations team owns:</p>
<ul>
<li><code>BinderyOps</code>, a PowerShell module containing a <strong>script-based</strong> resource named <code>AppEnvironment</code> that manages a machine-level environment variable.</li>
<li><code>LegacyWebServer.ps1</code>, a <strong><code>Configuration</code> script</strong> that uses <code>AppEnvironment</code> alongside the built-in <code>File</code> resource.</li>
<li><code>output\localhost.mof</code>, the <strong>compiled artifact</strong> that the LCM actually applies.</li>
</ul>
<p>It's small enough to follow in a single sitting and structurally identical to the thousand-line resources in your production estate.</p>
