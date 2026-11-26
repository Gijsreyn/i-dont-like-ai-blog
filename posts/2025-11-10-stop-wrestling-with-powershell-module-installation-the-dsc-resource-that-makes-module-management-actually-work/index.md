---
title: "Stop wrestling with PowerShell module installation: The DSC resource that makes Module Management actually work"
status: published
tags: ["Microsoft Desired State Configuration v3", "PowerShell"]
published_at: "2025-11-10T06:08:00.000Z"
custom_excerpt: "How to declaratively define PowerShell module management with DSC resources"
feature_image: "images/2025-11-feature_dsc_image.png"
---

<p>I used to dread onboarding new developers.</p><p>"Just run this script," I'd say, handing over a 200-line PowerShell script mess that installed modules. Sometimes it worked. Usually, it didn't. Wrong versions installed. Dependencies conflicted. Four hours later, we'd still be troubleshooting why their environment didn't match the way mine did.</p><p>The worst part? I knew it was my fault. I'd tried everything. Documenting it in wikis, using external tools, and providing instructions on Teams. Nothing lasted, and environments kept drifting. I spent more time firefighting module issues than actually building things.</p><p>Then, during the DSC work group meeting I'm part of, it clicked.</p><p>While the problem wasn't in the tools, it was the dependency on them or the way <em>I </em>was writing it. </p><p>Enter the <code>Microsoft.PowerShell.PSResourceGet</code> DSC resource. Declarative module management that actually works. No more "works on my machine." No more version drift. No more setup scripts that break every month.</p><p>Adityha developed this unreleased resource with functionality planned for integration into <code>Microsoft.PowerShell.PSResourceGet</code> v1.2.0. And it's about to change how you manage PowerShell modules.</p><p>Here's what I learned down the road.</p><h2 id="the-module-version-game">The module version game</h2><p>Here's the scenario: Your deployment scripts need SqlServer module version 21.1.18256. Not 22.x, as it broke authentication behaviour. Pester needs to be 5.x because your tests don't work with 4.x. And PSScriptAnalyzer? Any recent version works, but it needs to be installed.</p><p>Now multiply this across:</p><ul><li>Your local machine where you develop</li><li>Three Windows servers running the deployment script</li><li>Four build agents running separate jobs to test your script</li><li>Any other developer's laptop on your team</li></ul><p>How do you guarantee everyone has the correct versions?</p><p>Most teams write a setup script. Something like this:</p><pre><code class="language-powershell">if (-not (Get-Module -ListAvailable -Name Az.Compute -RequiredVersion 5.7.0)) {
    Install-PSResource -Name Az.Compute -Version 5.7.0
}
# ...repeat 20 more times</code></pre><p>Others might fall back on the <a href="https://www.powershellgallery.com/packages/PSDepend/0.3.8">PSDepend</a> module. But that module still needs to be bootstrapped first.</p><p>So, it still works until it doesn't. Someone runs it twice and gets different results. A build agent has an old version cached. A developer manually installs something, breaking the pattern.</p><p>You return to the earlier point: document it, store it in a Wiki, and post it on Teams. That doesn't really stick.</p><p><strong>There's a better way: Stop writing installation instructions. Start declaring requirements.</strong></p><h2 id="how-psresourceget-dsc-resource-work">How PSResourceGet DSC resource work</h2><p>First, if you want to try this out, you've to grab the resource from <a href="https://github.com/PowerShell/PSResourceGet/pull/1852/files">GitHub</a> and store all three files in your <code>dsc.exe</code> file location. </p><p>Once you have the resource available, instead of imperative installation scripts, you declare your desired state:</p><pre><code class="language-yaml">$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: Required PowerShell Modules
    type: Microsoft.PowerShell.PSResourceGet/PSResourceList
    properties:
      repositoryName: PSGallery
      resources: 
        - name: Pester
          version: '[[5.0.0,6.0.0)'     # Exactly this version
        - name: PSScriptAnalyzer
          version: '[[&gt;=1.21.0]'         # 1.21.0 or newer
        - name: SqlServer
          version: '21.1.18256'          # Exactly this version
</code></pre><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">ℹ️</div><div class="kg-callout-text">If you're getting an error that the schema doesn't match the version, update the <code spellcheck="false" style="white-space: pre-wrap;">version</code> pattern in the resource manifest with:<br><code spellcheck="false" style="white-space: pre-wrap;">"pattern": "^((\\[|\\()[ \\t]*(&gt;=|&gt;|&lt;=|&lt;)?[ \\t]*\\d+(\\.\\d+){0,2}(-[0-9A-Za-z-.]+)?[ \\t]*(,[ \\t]*(&gt;=|&gt;|&lt;=|&lt;)?[ \\t]*(\\d+(\\.\\d+){0,2}(-[0-9A-Za-z-.]+)?)?[ \\t]*)?(\\]|\\))|\\d+(\\.\\d+){0,2}(-[0-9A-Za-z-.]+)?)$"</code></div></div><p></p><p>Save this as <code>module.dsc.yaml</code> and run:</p><pre><code class="language-powershell">dsc config get --file module.dsc.yaml</code></pre><p>DSC will fetch the current state, and if none are present, it returns:</p><pre><code class="language-yaml">results:
- metadata:
    Microsoft.DSC:
      duration: PT9.5483312S
  name: Required PowerShell Modules
  type: Microsoft.PowerShell.PSResourceGet/PSResourceList
  result:
    actualState:
      repositoryName: PSGallery
      resources:
      - name: Pester
        version: null
        scope: 0
        repositoryName: null
        preRelease: false
        _exist: false
      - name: PSScriptAnalyzer
        version: null
        scope: 0
        repositoryName: null
        preRelease: false
        _exist: false
      - name: SqlServer
        version: null
        scope: 0
        repositoryName: null
        preRelease: false
        _exist: false
messages: []
hadErrors: false</code></pre><p>Run it with the <code>dsc config set</code>, and it installs only what's needed. Run it again tomorrow, next week, or on a different machine, and you get the same results (unless a new version is released for the version range).</p><h2 id="version-ranges-flexibility-where-you-need-it">Version ranges: flexibility where you need it</h2><p>Notice the version syntax in the example above? That's NuGet version range notation, and it gives you precise control:</p><ul><li><code>'21.1.18256'</code> locks to an exact version</li><li><code>'[[5.0.0,6.0.0)'</code> accepts any 5.x release but excludes 6.0 and above</li><li><code>'[[&gt;=1.21.0]'</code> sets a minimum version</li></ul><p>You can also specify ranges with both bounds: <code>'[2.0.0,2.5.0]'</code> (both inclusive) when you've tested a specific version window.</p><p>This isn't just syntax flexibility—it's policy-as-code. Your config file captures exactly which versions are acceptable and which will break your automation.</p><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">ℹ️</div><div class="kg-callout-text">Do note that the module isn't officially released, and this behavior can change over time.</div></div><p></p><h2 id="managing-package-sources">Managing package sources</h2><p>You can also declare where modules come from:</p><pre><code class="language-yaml">resources:
  - name: Internal Module Repository
    type: Microsoft.PowerShell.PSResourceGet/Repository
    properties:
      Name: CompanyInternal
      Uri: https://nuget.company.com/powershell
      Trusted: true
      Priority: 10</code></pre><p>The key benefits of declaring such a configuration are:</p><ul><li><strong>Priority control</strong>: Lower numbers are checked first</li><li><strong>Consistency</strong>: Everyone uses the same sources</li><li><strong>Trusted repositories</strong>: No more confirmation prompts in automation (it doesn't mean you still have to take care of the authentication flow for these repositories)</li></ul><p>Once you've declared a repository, <code>PSResourceList</code> can automatically pull from it without additional configuration.</p><h2 id="real-scenarios-where-this-saves-your-day">Real scenarios where this saves your day</h2><p>Here are two scenarios where declaring your repositories and modules can save the day.</p><h3 id="scenario-1-new-build-agent-setup">Scenario 1: New build agent setup</h3><p>Your DevOps pipeline needs specific tool versions installed:</p><pre><code class="language-yaml">resources:
  - name: Build Tools
    type: Microsoft.PowerShell.PSResourceGet/PSResourceList
    properties:
      resources:
        - name: Pester
          version: '5.7.1'
        - name: PSScriptAnalyzer
          version: '1.22.0'
        - name: Microsoft.PowerShell.PlatyPS
          version: '1.0.1'</code></pre><p>New build agent? Apply this config. Agent acting weird? Reapply the config. Testing a new tool version? Change the config and reapply. Version control your infrastructure the same way you version control your code.</p><h3 id="scenario-2-developer-environment-consistency">Scenario 2: Developer environment consistency</h3><p>Every developer needs the same internal modules:</p><pre><code class="language-yaml">resources:
  - name: Company Module Repository
    type: Repository
    properties:
      Name: Microsoft.PowerShell.PSResourceGet/Repository
      Uri: https://artifacts.company.com/powershell
      Trusted: true
      Priority: 5&#10;  
  - name: Internal Modules
    type: Microsoft.PowerShell.PSResourceGet/PSResourceList
    properties:
      resources:
        - name: CompanyDSCResources
          version: '3.2.0'
          repository: CompanyPowerShell
        - name: CompanyAzureTools
          version: '1.5.0'
          repository: CompanyPowerShell</code></pre><p>New developer joins? They run one command and have a production-matched environment—no wiki pages listing manual steps. Just give them the <code>dsc config set</code> command, and they're ready to go.</p><h2 id="getting-started">Getting started</h2><p>Ready to try it? Here's how to get up and running in five minutes. Since this is currently unreleased, as mentioned earlier, you'll need to grab it from GitHub. However, once this functionality is integrated into PSResourceGet, you won't need these installation steps. Just install <code>dsc.exe</code>, upgrade PowerShell (PSResourceGet ships with newer versions of PowerShell), or update it manually.</p><p>For now, here's the setup:</p><ol><li><strong>Install <code>dsc.exe</code>:</strong></li></ol><pre><code class="language-powershell">Install-PSResource -Name PSDSC -Scope CurrentUser&#10;
Install-DscExe</code></pre><ol start="2"><li><strong>Download the Microsoft.PowerShell.PSResourceGet DSC resource:</strong></li></ol><pre><code class="language-powershell">$repoOwner = "PowerShell"
$repoName = "PSResourceGet"
$prNumber = 1852&#10;
$apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/pulls/$prNumber/files"
$pr = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell" }&#10;
$dscLocation = Get-Command dsc | Select-Object -ExpandProperty Source | Split-Path -Parent&#10;
foreach ($file in $pr) {
    if ($file.filename.Contains("/")) {
        $fileName = $file.filename.Split("/")[-1]
    } else {
        $fileName = $file.filename
    }
    Write-Output "Downloading $($file.filename) to $dscLocation"
    $outputFile = Join-Path -Path $dscLocation -ChildPath $fileName
    Invoke-RestMethod -Uri $file.raw_url -OutFile $outputFile
}</code></pre><ol start="3"><li><strong>Create a config file (<code>modules.dsc.yaml</code>):</strong></li></ol><pre><code class="language-yaml">$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: Essential Modules
    type: PSResourceList
    properties:
      resources:
        - name: Pester
          version: '5.7.1'</code></pre><ol start="4"><li><strong>Apply it:</strong></li></ol><pre><code class="language-powershell">dsc config set --file modules.dsc.yaml</code></pre><ol start="5"><li><strong>Test it later:</strong></li></ol><pre><code class="language-powershell">dsc config test --file modules.dsc.yaml</code></pre><p>The test command checks if the resource is in its desired state.</p><h2 id="why-this-matters">Why this matters</h2><p>This isn't just about easier installation. It's about:</p><ul><li><strong>Drift detection</strong>: Know when someone manually installed a different version (when there's an orchestrator)</li><li><strong>Compliance</strong>: Prove your environments match your actual document</li><li><strong>Reproducibility</strong>: Rebuild environments from code, not from memory</li></ul><p>Traditional imperative scripts can't give you these capabilities. DSC's declarative model makes them natural.</p><h2 id="try-it-break-it-share-your-experience">Try it, break it, share your experience</h2><p>The <code>Microsoft.PowerShell.PSResourceGet</code> DSC resource isn't officially released yet, but you've now learned how to get started. </p><ul><li>What scenarios work great for you?</li><li>What scenarios break it?</li><li>What features would make this indispensable?</li></ul><p>Configuration-as-code isn't just for servers and cloud resources anymore. Your automation toolchain deserves the same treatment.</p>
