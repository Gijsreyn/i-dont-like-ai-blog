---
title: "Office installations made easy: Introducing OfficeDsc PowerShell module"
status: published
tags: ["PowerShell", "Microsoft Desired State Configuration v3"]
published_at: "2025-09-26T03:38:31.000Z"
custom_excerpt: "Learn how you can easily automate Office installations using PowerShell DSC"
feature_image: "images/2025-09-Introducing-OfficeDsc-PowerShell-module--1--1.png"
feature_image_alt: "Introducing OfficeDsc PowerShell module"
---

<p></p><p>If you've ever had to deploy Microsoft Office on multiple systems, you already know the struggle. Handling updates, excluding apps, and choosing the right channel, the process is rarely straightforward.</p>
<p>Traditional enterprise tooling requires some form of configuration to get started. But what if you want a repeatable, compliant, and automated way to install Office? That's precisely why I built the OfficeDsc module.</p>
<p>OfficeDsc is a PowerShell module containing class-based DSC resources for installing and configuring Office. Rather than wrestling with the available configuration options, you simply define the desired state once, and DSC ensures it stays that way.</p>
<p>In this blog post, you will learn why you can use DSC for Office and how you can get started.</p>
<h2 id="pre-requisites">Pre-requisites</h2>
<p>The OfficeDsc module requires you to have:</p>
<ul>
<li>PowerShell 7.2+ installed.</li>
<li><a href="https://www.powershellgallery.com/packages/PSDesiredStateConfiguration/2.0.7">PSDesiredStateConfiguration</a> v2.0.7.</li>
</ul>
<h2 id="why-dsc-for-office">Why DSC for Office</h2>
<p>DSC is always built with compliance and repeatability in mind. With DSC, you:</p>
<ul>
<li>Define <em>what</em> the system should look like.</li>
<li>Ensure that machines remain compliant.</li>
<li>Gain consistency across multiple systems.</li>
</ul>
<p>The Office Deployment Tool (ODT) requires you to define a configuration file (<code>.xml</code>) with multiple options. While you can look up the documentation for each available element, OfficeDsc makes it easy for you to define it based on properties that are strongly validated.</p>
<p>Imagine you want to install the <em>O365BusinessRetail</em> version and receive <em>SemiAnnual</em> updates. Normally, you would run the following:</p>
<pre><code class="language-powershell">$configXml = @"
&lt;Configuration&gt;
  &lt;Add OfficeClientEdition="64" Channel="SemiAnnual"&gt;
    &lt;Product ID="O365BusinessRetail"&gt;
      &lt;Language ID="en-US" /&gt;
    &lt;/Product&gt;
  &lt;/Add&gt;
  &lt;Display Level="None" AcceptEULA="TRUE" /&gt;
&lt;/Configuration&gt;
"@
$configPath = Join-Path $env:TEMP 'ODT_Install.xml'
Set-Content -Path $configPath -Value $configPath
&amp; setup.exe /configure $configPath
</code></pre>
<p>With DSC, you can do it differently:</p>
<pre><code class="language-powershell">Invoke-DscResource -ModuleName OfficeDsc -Name Office365Installer -Method Set -Property @{
    Path = 'C:\ODT\setup.exe'
    ProductId = 'O365BusinessRetail'
    Channel = 'SemiAnnual'
}
</code></pre>
<p>With this invocation, you've just told DSC:</p>
<ul>
<li>Install <em>Office 365 Business Retail</em>.</li>
<li>Use the <em>Semi Annual channel</em>.</li>
<li>Deploys the package with your system culture (the language).</li>
<li>Automatically accepts the EULA.</li>
</ul>
<p>No need to write a small script or babysit the installer. When you run DSC from an orchestrator, you get the benefit of compliance and easy automation across multiple systems.</p>
<h2 id="getting-started">Getting started</h2>
<p>To get started with OfficeDsc, you can install the module from the PowerShell Gallery:</p>
<pre><code class="language-powershell"># Install from PowerShell Gallery
Install-PSResource -Name OfficeDsc -Repository PSGallery
</code></pre>
<p>You can list out the available DSC resources by running:</p>
<pre><code class="language-powershell"># Use PSDesiredStateConfiguration module
Get-DscResource -Module OfficeDsc
</code></pre>
<p>If you want to play right out of the box without using the <code>PSDesiredStateConfiguration</code> module, you can instantiate a class and get IntelliSense on the available properties:</p>
<pre><code class="language-powershell"># Import classes and enumerations
using module OfficeDsc&#10;
# Instantiate class
$officeDsc = [Office365Installer]::new()&#10;
# Try to set a property
$officeDsc.ProductId = # Press tab here to hover through the available products
</code></pre>
<h2 id="get-help">Get-Help</h2>
<p>Unlike standard PowerShell cmdlets, class-based DSC resources don't have the default <code>Get-Help</code> experience. To fill this gap, you can find documented examples and usage instructions on the <a href="https://github.com/Gijsreyn/random-tools-gijs/blob/main/powershell/modules/OfficeDsc/Office365Installer.md">GitHub</a> repository. Here you can see the most up-to-date references.</p>
<p>If you're looking for alternative ways of managing Office installations using OfficeDsc, WinGet, and Microsoft DSC v3 are also options. For more information, check out the documentation at:</p>
<ul>
<li>Running <a href="https://github.com/Gijsreyn/random-tools-gijs/tree/main/powershell/modules/OfficeDsc#running-winget-configurations">OfficeDsc through WinGet</a></li>
<li>Running <a href="https://github.com/Gijsreyn/random-tools-gijs/tree/main/powershell/modules/OfficeDsc#running-with-microsoft-dsc-v3">OfficeDsc through Microsoft DSC v3</a></li>
</ul>
<h2 id="whats-next">What's next</h2>
<p>OfficeDsc is just getting started. The initial release focused on the default options, but the roadmap includes:</p>
<ul>
<li>Allow offline installation.</li>
<li>Add <code>AppSettings</code> elements.</li>
<li>Support multiple Office versions.</li>
</ul>
<p>If you would like me to prioritize these features, let me know. You can open an issue on the repository or reach out to me on social media.</p>
<h2 id="summary">Summary</h2>
<p>Whilst OfficeDsc just got released, it brings the benefit of:</p>
<ul>
<li>Automatically install Office using a declarative DSC resource or invoke directly.</li>
<li>Enforce compliance and drift-detection.</li>
<li>Avoid the complexity of defining XML-based configuration files.</li>
</ul>
<p>The module is still evolving, but it already provides a simple yet reliable way to manage Office installations. Give it a try and let me know how it works for you.</p>
