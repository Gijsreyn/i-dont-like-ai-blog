---
title: "No agent, no pull server, no problem? The pieces that make Microsoft DSC enterprise-ready"
status: published
tags: ["Microsoft Desired State Configuration v3"]
published_at: "2026-11-17T03:44:40.000Z"
custom_excerpt: "Not yet, but the missing pieces now have issue numbers and pull requests"
feature_image: "images/2026-11-JERH6piXHwXD5lxp.png"
---

<p>In August 2024 I left <a href="https://github.com/PowerShell/DSC/issues/92#issuecomment-2282719425">a comment</a> on a proposal in the Microsoft DSC repository and called it a "brain dump". The proposal was a year old by then. It described a place to publish and fetch configurations and resources, which PowerShell DSC had from the start and Microsoft DSC still doesn't.</p>
<p>The question behind that proposal keeps coming back in the issue tracker: where did the LCM go? One contributor answered it by starting <a href="https://github.com/opendsc/opendsc">OpenDSC</a>, which began as <a href="https://github.com/PowerShell/DSC/issues/210#issuecomment-1738388410">a thought experiment</a> "of bringing back the LCM and pull server".</p>
<p>Better yet, the question doesn't stay on GitHub. Speaking to people at PSConfEU earlier this year, I got asked the same thing in person. These were people who run PowerShell DSC today and want to know what replaces the part that did the work for them.</p>
<p>So the title of this post is a real question, and today the answer is no. No agent and no pull server is a problem once you have more than one machine to manage. Since that comment, I've written two RFCs and four pull requests that each go after a part of the gap. All of them are drafts. This post is a status report from inside them: what each piece does, how far along it is, and what you can do in the meantime.</p>
<p>If you need to enforce configuration across a fleet this quarter, I'll save you the read: <a href="https://github.com/opendsc/opendsc">OpenDSC</a> is available today and gives you an LCM and a pull server on top of Microsoft DSC. It's a community project, not a Microsoft product, and I come back to it near the end. The rest of this post is for deciding whether Microsoft DSC itself is worth planning around.</p>
<h2 id="what-the-lcm-did-in-one-paragraph">What the LCM did, in one paragraph</h2>
<p>You ran one, so I'll keep it short. The <a href="https://learn.microsoft.com/powershell/dsc/managing-nodes/metaconfig?view=dsc-1.1">Local Configuration Manager</a> took configurations by push or pulled them from a server. The same server handed out the modules a configuration needed, and a report server collected status. By default the LCM checked the machine every 15 minutes, and depending on the mode it reported drift or corrected it. It could reboot the node when a resource asked for it.</p>
<p>All of that lived in one component. That made it convenient, and it also tied you to Windows, MOF, and a pull server that somebody had to keep running. The hosted alternative is ending too: <a href="https://learn.microsoft.com/azure/automation/automation-dsc-overview">Azure Automation State Configuration retires on September 30, 2027</a>.</p>
<p>Microsoft moved that hosted role to <a href="https://learn.microsoft.com/azure/governance/machine-configuration/overview">Azure Machine Configuration</a>, and it manages Linux as well as Windows. But it isn't the old LCM in a new place. It brings its own agent, which runs your configurations in PowerShell 7 with <a href="https://learn.microsoft.com/azure/governance/machine-configuration/whats-new/psdsc-in-machine-configuration">PSDesiredStateConfiguration v2</a>, or a 3.0 prerelease on Linux. A configuration still compiles to MOF, and it ships with its modules as one package that the machine downloads over HTTPS. There is no pull server and no LCM meta-configuration, and whether a configuration only audits or also corrects is set in the package. It works for Azure virtual machines and Arc-enabled servers, so it needs Azure, and underneath it's still PowerShell DSC.</p>
<h2 id="what-microsoft-dsc-chose-instead">What Microsoft DSC chose instead</h2>
<p>Microsoft DSC is one command. You give it a document in JSON or YAML, it calls resources written in any language, it returns JSON, and it exits. It runs on Windows, Linux and macOS. There is no service, no schedule and nothing listening.</p>
<p>One participant in the signing discussion <a href="https://github.com/PowerShell/DSC/issues/210#issuecomment-3349114314">said it</a> in a sentence: "<code>dsc.exe</code> does not run as a service, something has to invoke it."</p>
<p>That something is meant to be a higher-level tool. <a href="https://learn.microsoft.com/windows/package-manager/configuration/create-v3">WinGet Configuration</a> is one: its v3 files are processed by Microsoft DSC. A CI pipeline or a scheduled task is another. But until now, "bring your own orchestration" has also meant bringing your own way to get a document onto a machine, your own way to get resources there, and your own way to know you can trust either.</p>
<p>That is the part that's changing. Here are the LCM's jobs, and what is lined up for each.</p>
<table>
<thead>
<tr>
<th style="text-align:left">The LCM's job</th>
<th style="text-align:left">In Microsoft DSC</th>
<th style="text-align:left">Where it stands</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left">Deliver a configuration to a machine</td>
<td style="text-align:left">DSC over SSH</td>
<td style="text-align:left">Draft pull request, experimental</td>
</tr>
<tr>
<td style="text-align:left">Fetch configurations and resources</td>
<td style="text-align:left">An OCI registry</td>
<td style="text-align:left">Proposal, no code yet</td>
</tr>
<tr>
<td style="text-align:left">Validate what was fetched</td>
<td style="text-align:left">Signing</td>
<td style="text-align:left">Open issue, design debated</td>
</tr>
<tr>
<td style="text-align:left">Add your own checks and tooling</td>
<td style="text-align:left">Command plug-ins</td>
<td style="text-align:left">Draft pull requests</td>
</tr>
<tr>
<td style="text-align:left">Enforce on a schedule and report</td>
<td style="text-align:left">Outside DSC, on purpose: OpenDSC or your own</td>
<td style="text-align:left">Available today, from the community</td>
</tr>
</tbody>
</table>
<p>None of the first four is in the stable release, which is 3.3, or in the 3.4 previews.</p>
<p>For when to expect them, look at the milestone on each issue. The <a href="https://github.com/PowerShell/DSC/milestones">milestones</a> are named after a release and say how firm the plan is, like <code>3.4-Approved</code> or <code>3.5-Consider</code>. As I write this, SSH, the registry and signing are on <code>3.4-Approved</code>, and plug-ins are on <code>3.5-Consider</code>. The milestones have no due dates, so read them as intent.</p>
<h2 id="deliver-with-ssh">Deliver with SSH</h2>
<p>The LCM's push mode needed WinRM. Microsoft DSC is cross-platform, so its equivalent has to use something every platform has.</p>
<p><a href="https://github.com/PowerShell/DSC/issues/1495">Issue #1495</a> asks for <code>dsc</code> as an SSH subsystem, the mechanism SFTP uses. I wrote the <a href="https://github.com/PowerShell/DSC/pull/1803">RFC</a> and an <a href="https://github.com/PowerShell/DSC/pull/1810">experimental implementation</a>. DSC already has a server mode that talks over standard input and output, so <code>sshd</code> can start it. On your side, it's one option:</p>
<pre><code class="language-sh">dsc --target ssh://admin@web01 config test --file baseline.dsc.yaml
</code></pre>
<p>The document is read on your machine, sent over the connection and run on the target. The result comes back as it would from a local run, with the same output and the same exit code. Nothing is copied to the target, which only needs <code>dsc</code> and the subsystem entry. Registering that entry is itself a DSC configuration.</p>
<p>For a security review, the useful part is what the feature leaves alone. It starts the <code>ssh</code> client that's already on your system, so keys, jump hosts and <code>~/.ssh/config</code> behave as they already do, and DSC never handles a credential.</p>
<p>The limits today are one target per run, and only <code>config get</code>, <code>set</code>, <code>test</code> and <code>export</code>.</p>
<h2 id="fetch-from-a-registry-instead-of-a-pull-server">Fetch from a registry instead of a pull server</h2>
<p>The pull server handed out configurations and modules. In Microsoft DSC a resource can be a Rust binary, a Python script or a PowerShell module, so "install the module" no longer covers it.</p>
<p>In 2023, Mikey Lombardi proposed an answer in <a href="https://github.com/PowerShell/DSC/issues/92">issue #92</a>: publish resource manifests and configuration documents as artifacts to an OCI registry, using <a href="https://oras.land/">ORAS</a>. That's the kind of registry your container images already live in.</p>
<p>PowerShell has already made this move, which is why I don't think it's a leap. PSResourceGet can <a href="https://learn.microsoft.com/powershell/gallery/powershellget/how-to/use-acr-repository">publish modules to an Azure Container Registry and install them from it</a>. This works today:</p>
<pre><code class="language-powershell">Register-PSResourceRepository -Name Contoso -Uri 'https://contoso.azurecr.io'
Publish-PSResource -Path ./MyDscModule -Repository Contoso
Install-PSResource -Name MyDscModule -Repository Contoso
</code></pre>
<p>Microsoft's own registry is a <a href="https://learn.microsoft.com/powershell/gallery/powershellget/supported-repositories">default repository</a> next to the PowerShell Gallery from PSResourceGet 1.3.0-preview1. So a PowerShell-based DSC resource can already live in the kind of registry the proposal describes.</p>
<p>The same documentation lists a limitation that makes the case for the proposal. Against a container registry, <code>Find-PSResource -DscResourceName</code> isn't supported. The module is there, but you can't ask the registry which DSC resources it holds. A registry that stores resource manifests answers exactly that: you find a resource and read its contract first, and pull the implementation second.</p>
<p>What I like for larger organizations is that there's no new server in this design. You already run a registry, with access control and mirroring. In <a href="https://github.com/PowerShell/DSC/issues/92#issuecomment-6130786208">a recent reply</a>, Mikey wrote that keeping your own registry, one that pulls from upstream and adds your internal resources, should be the preferred setup.</p>
<p>My comment from 2024 builds on that, and I still stand by it. If documents live in a registry, <code>Microsoft.DSC/Include</code> could point at a versioned artifact, the way Azure Verified Modules are referenced. A security baseline becomes something you reference by name and version, instead of a file that gets copied from repository to repository.</p>
<p>Status: the issue carries the <code>3.4-Approved</code> milestone. That is not a release date, and there is no <code>dsc registry</code> command to run.</p>
<h2 id="validate-with-signing">Validate with signing</h2>
<p>The pull server paired every configuration with <a href="https://learn.microsoft.com/powershell/dsc/pull-server/pullserver?view=dsc-1.1">a checksum file</a> so the LCM could validate what it downloaded. A checksum tells you the file arrived intact. It doesn't tell you who published it, and a registry that many teams pull from needs that second answer.</p>
<p><a href="https://github.com/PowerShell/DSC/issues/210">Issue #210</a> asks for a way to run only signed, trusted configurations. In that thread, Mikey <a href="https://github.com/PowerShell/DSC/issues/210#issuecomment-1738374301">pointed out</a> that tools like cosign can sign artifacts in an OCI registry, which would let one mechanism cover manifests and documents on every platform.</p>
<p>The thread hasn't settled who does the checking. One position is that DSC runs the resources, so DSC should verify them. The other is that DSC is a low-level tool, and whoever invokes it should verify what it hands over. Today there's <a href="https://github.com/PowerShell/DSC/pull/1130">a draft</a> that warns on Windows when files aren't Authenticode-signed, and a request in the thread for an RFC that covers all platforms.</p>
<p>I think the registry changes this debate. If artifacts are signed when they're published, the natural place to verify is wherever they're pulled, and that can be <code>dsc</code> or the tool calling it. So I'd design signing together with the registry, and for all three platforms at once, even if that takes a release longer than a Windows-only check.</p>
<h2 id="extend-with-plug-ins">Extend with plug-ins</h2>
<p>This row has no LCM counterpart. The LCM was closed: checks and tooling of your own lived in scripts around it. Microsoft DSC can do better, because tools like <code>git</code> have long shown how. Put an executable in the right place and it becomes a subcommand.</p>
<p><a href="https://github.com/PowerShell/DSC/issues/461">Issue #461</a> asks for that in DSC. I wrote the <a href="https://github.com/PowerShell/DSC/pull/1805">RFC</a> and the <a href="https://github.com/PowerShell/DSC/pull/1808">implementation</a>. An executable plus a small manifest, in a directory DSC already searches, becomes <code>dsc &lt;command&gt;</code>.</p>
<p>Two plug-ins exist as drafts. <a href="https://github.com/PowerShell/DSC/pull/1809"><code>dsc lint</code></a> checks a configuration document before it goes near a machine. <a href="https://github.com/PowerShell/DSC/pull/1815"><code>dsc graph</code></a> is a sample for the authoring guide that draws the dependencies in a document:</p>
<pre><code class="language-sh">dsc graph --file app.dsc.yaml
</code></pre>
<!-- Render this block as an image if your blog platform doesn't draw Mermaid. -->
<pre><code class="language-mermaid">flowchart TD
    n0["os&lt;br/&gt;Microsoft/OSInfo"]
    n1["Echo&lt;br/&gt;Microsoft.DSC.Debug/Echo"]
    n0 --&gt; n1
</code></pre>
<p>Two rules are there for cautious organizations. Built-in commands always win, so a plug-in can't quietly replace <code>dsc config</code>. And one setting turns plug-ins off entirely, including from a policy file.</p>
<p>A third rule came out of review. My draft let the first plug-in found win when two claimed the same command, and mentioned it in an info message that few people would ever see. Steve Lee <a href="https://github.com/PowerShell/DSC/pull/1805#discussion_r4566454232">asked</a> what should happen in that case and suggested a warning, plus a way to name a plug-in exactly. Both are in the RFC now: <code>dsc lint</code> runs the first one found and warns, and <code>dsc OpenDSC/Lint</code> runs that specific one. That exchange took a day, and it's the best argument I have for designing this in the open.</p>
<h2 id="enforce-and-report-with-opendsc-or-your-own">Enforce and report with OpenDSC or your own</h2>
<p>Nothing above runs on a timer. There is no consistency check in <code>dsc</code>, no drift report and no reboot coordination, and I don't expect that to change. This job is left to whatever sits on top, and there are two ways to fill it today.</p>
<h3 id="opendsc">OpenDSC</h3>
<p><a href="https://github.com/opendsc/opendsc">OpenDSC</a> is the closest thing to the old model, and you can install it now. According to <a href="https://opendsc.dev/">its documentation</a>, it provides:</p>
<ul>
<li>An LCM service that monitors a machine and corrects drift, on Windows, Linux and macOS.</li>
<li>A pull server with configuration versioning, node targeting and compliance tracking.</li>
<li>A reporting dashboard.</li>
</ul>
<p>It is open source under the MIT license, and its latest release is 0.5.1.</p>
<p>There is one thing to weigh before you build on it. OpenDSC is not backed by Microsoft. For many organizations, vendor backing is the first thing they look for in something that runs on every server, and a community project before its 1.0 release doesn't come with a support contract. If that's a requirement for you, the Microsoft-backed option is <a href="https://learn.microsoft.com/azure/governance/machine-configuration/overview">Azure Machine Configuration</a>, with the differences from the LCM I described earlier.</p>
<blockquote>
<p>[!TIP]<br>
I describe how to run OpenDSC on Azure in <a href="https://leanpub.com/themicrosoftdschandbook">The Microsoft DSC Handbook</a>. If you're moving an existing PowerShell DSC estate, my course <a href="/courses/migrating-from-powershell-dsc/">Migrating from PowerShell DSC to Microsoft DSC</a> covers the migration.</p>
</blockquote>
<h3 id="your-own">Your own</h3>
<p>If an agent and a server are more than you need, you can have a basic consistency check on the stable release with what's already there. Schedule this with whatever you schedule things with:</p>
<pre><code class="language-powershell">$result = dsc config test --file baseline.dsc.yaml | ConvertFrom-Json
$result.results | Where-Object { -not $_.result.inDesiredState } | Select-Object name, type
</code></pre>
<p>Every resource in the result has an <code>inDesiredState</code> value. Send the output to wherever your logs go and you have drift reporting. Replace <code>test</code> with <code>set</code> and you have correction.</p>
<p>Any orchestrator that can run a command and read JSON can drive <code>dsc</code> the same way.</p>
<p>The pieces in this post don't replace OpenDSC or a tool of your own. They reduce what such a layer has to bring: if <code>dsc</code> can reach a machine, fetch from a registry you already run and verify what it fetched, the layer on top can be thin.</p>
<h2 id="so-no-problem">So, no problem?</h2>
<p>Not yet. Here is how I'd decide today.</p>
<ul>
<li><strong>You need fleet enforcement and reporting now:</strong> look at OpenDSC, and weigh that it's a community project without Microsoft behind it. The other four pieces aren't in a release.</li>
<li><strong>You're deciding whether Microsoft DSC is a dead end for fleets:</strong> I don't think it is. Each of the LCM's jobs has an open design, for two of them there is code you can build and try, and the milestone on each issue tells you which release it's aimed at.</li>
<li><strong>You want to influence it:</strong> this is the moment. Read <a href="https://github.com/PowerShell/DSC/issues/1495">#1495</a>, <a href="https://github.com/PowerShell/DSC/issues/92">#92</a>, <a href="https://github.com/PowerShell/DSC/issues/210">#210</a> and <a href="https://github.com/PowerShell/DSC/issues/461">#461</a>, and say what your environment needs.</li>
</ul>
<p>The LCM isn't coming back into <code>dsc</code> itself. What's taking shape there is a set of parts built on things you already operate: SSH, a container registry, and commands you write yourself.</p>
<p>My part in this started as a comment under someone else's proposal. If one of these pieces is the one your environment is missing, the issue is open, and a comment is enough to start.</p>
