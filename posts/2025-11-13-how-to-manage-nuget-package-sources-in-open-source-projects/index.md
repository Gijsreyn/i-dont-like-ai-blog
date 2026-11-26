---
title: "How to manage NuGet package sources in open-source projects"
status: published
tags: [".NET"]
published_at: "2025-11-13T03:03:55.000Z"
custom_excerpt: "Managing multiple NuGet feeds just became easy"
feature_image: "images/2025-11-manage_nuget_package.png"
---

<p>I love contributing to open-source projects. There's something satisfying about building tools that anyone can use and improve.</p><p>But every now and then, I hit a peculiar problem that sits right at the intersection of open source ideals. This is one of those problems.</p><p>Suppose you've tried contributing to an open-source project that configured private NuGet feeds for internal builds. In that case, you know the tension: External contributors can't access those feeds, but the DevOps pipeline created needs them to restore.</p><p>I spent a few walks thinking about this one. How do you keep a project truly open? But at the same time, buildable by anyone while still using private dependencies if run through an internal infrastructure?<br><br>The answer turned out to be simpler than I thought. It only took some trial and error to get there.</p><p>Here's what I learned.</p><h2 id="the-problem-when-open-source-meets-private-feeds">The problem: When open source meets private feeds</h2><p>The thing about open-source projects should be straightforward: they're meant to be built by anyone and anywhere. Clone it, restore it, and build it to run it. That <em>should </em>be the promise.</p><p>But with recent supply chain attacks, many open-source projects have introduced an internal feed to their DevOps pipelines. These feeds aren't available for public consumption and require authentication nine out of ten times.</p><p>That brings a challenge. You can't expect external contributors to have access to those private feeds by default. It totally defeats the whole purpose of being open source.</p><p>I encountered this while working on a project that had a private Azure DevOps feed for those internal dependencies. The contributors already did a fantastic job by providing a build automation script (<code>build.ps1</code>). But triggering this script instantly gave me the error message:</p><pre><code class="language-plaintext">The plugin credential provider could not acquire credentials. Authentication may require manual action. Consider re-running t 
he command with --interactive for `dotnet`, /p:NuGetInteractive="true" for MSBuild or removing the -NonInteractive switch for `NuGet`</code></pre><p>When I tried to add both NuGet's public feed and the private one in the <code>nuget.config</code> file, I was presented with MSBuild's strict mode:</p><pre><code class="language-plaintext">When using central package management, please map your package sources with package source mapping</code></pre><p>The problem was clear: Contributors shouldn't need credentials to build an open-source project, regardless.</p><h2 id="enter-package-source-mapping">Enter package source mapping</h2><p>The clue was already given. Map the package sources with package source mapping in the <code>nuget.config</code> file. .NET 6 introduced this mapping, telling NuGet: "This package comes from here, that packages come from there."</p><p>What you can now do is define the source mapping for each pattern you want it to follow:</p><pre><code class="language-xml">&lt;packageSourceMapping&gt;
  &lt;packageSource key="NuGet"&gt;
    &lt;package pattern="*" /&gt;
  &lt;/packageSource&gt;
  &lt;packageSource key="OtherFeed"&gt;
    &lt;package pattern="CustomPackage.*" /&gt;
  &lt;/packageSource&gt;
&lt;/packageSourceMapping&gt;</code></pre><p>This tells NuGet: "Hey, if you find a package with CustomPackage in the name, you need to fetch it from there. Everything else can go through NuGet's feed."</p><p>But did it solve the two issues? Not fully, because there was another problem. The private feed.</p><h2 id="the-solution-split-your-configs">The solution: Split your configs</h2><p>This is where it gets interesting. What if we could simply use different NuGet configs for different scenarios?</p><p>Most CI/CD system runners have predefined variables. These are populated when a task runs. For example, Azure DevOps has a known variable <code>TF_BUILD</code> that is set when a build task runs a script.</p><p>Knowing this allows you to split your <code>nuget.config</code> files in two: one for the public builds and the other for private builds:</p><pre><code class="language-xml">&lt;packageSources&gt;
  &lt;add key="NuGet" value="https://api.nuget.org/v3/index.json" /&gt;
  &lt;add key="OtherFeed" value="https://otherfeed.com/v3/index.json" /&gt;
&lt;/packageSources&gt;
&lt;packageSourceMapping&gt;
  &lt;packageSource key="NuGet"&gt;
    &lt;package pattern="*" /&gt;
  &lt;/packageSource&gt;
  &lt;packageSource key="OtherFeed"&gt;
    &lt;package pattern="CustomPackage.*" /&gt;
  &lt;/packageSource&gt;
&lt;/packageSourceMapping&gt;</code></pre><p>Then, you can create a <code>nuget.internal.config</code> file used only for internal builds:</p><pre><code class="language-xml">&lt;packageSources&gt;
  &lt;add key="Packages" value="https://pkgs.dev.azure.com/&lt;organizationName&gt;/&lt;artifactFeedName&gt;/..." /&gt;
&lt;/packageSources&gt;</code></pre><p>In this case, you don't have to set the <code>packageSourceMapping</code> element. It's a single source, so MSBuild doesn't require mappings.</p><p>Luckily, as mentioned earlier, the project already had a build automation script available. This is where the actual magic happens. During a pipeline run, you can easily swap to the internal config:</p><pre><code class="language-powershell">function Restore-NuGet
{
    [CmdletBinding()]
    param (
        [string]$SolutionPath,
        [switch]$UseInternal
    )&#10;
    $nugetConfig = Join-Path (Split-Path $SolutionPath -Parent) "nuget.config"&#10;
    if ($UseInternal)
    {
        Write-Verbose "Using internal NuGet configuration"
        $nugetConfig = Join-Path (Split-Path $SolutionPath -Parent) "nuget.internal.config"
    }&#10;
    $dotNetPath = (Get-Command "dotnet" -CommandType Application -ErrorAction SilentlyContinue).Source&#10;
    if (!$dotNetPath)
    {
        throw "dotnet CLI not found. Please ensure that .NET SDK is installed and 'dotnet' is in the system PATH."
    }&#10;
    &amp; dotnet restore $SolutionPath --configfile $nugetConfig
}</code></pre><p>Whenever you call the function, you can use the <code>$env:TF_BUILD</code> variable to determine if it is run through Azure DevOps, or not:</p><pre><code class="language-powershell">Restore-Nuget -SolutionPath $solutionPath -UseInternal:([bool]$env:TF_BUILD)</code></pre><p>This results in local builds and community PRs always using the public config with source mappings, whereas internal builds swap to the private feed.</p><h2 id="the-key-insight">The key insight</h2><p>So what's the real lesson here? Package source mapping is helpful in itself, but it's not a one-size-fits-all solution. Each open-source project lives in its own bubble where you need to balance between:</p><ol><li>Security</li><li>Accessibility</li><li>Flexibility</li></ol><p>Each point gets covered if you split your NuGet configs into your build context. </p><h2 id="what-you-should-do">What you should do</h2><p>If you ever encounter the above issue in similar projects, start the discussion and:</p><ol><li>Start mapping your package explicitly using the <code>packageSourceMapping</code> element. Use a (<code>*</code>) wildcard pattern for your primary source</li><li>If you want to capture errors early on, set the <code>RestorePackageDownloadTrustedSources</code> property to error in your builds</li><li>When you want contributions, consider splitting your configs if you require internal builds</li></ol><p>The beauty of this approach is that it's transparent and doesn't require additional work from contributors. They can just clone, build, and everything should work as expected. That's the kind of simplicity I love. One straightforward solution that lets everything else fade to the background.</p>
