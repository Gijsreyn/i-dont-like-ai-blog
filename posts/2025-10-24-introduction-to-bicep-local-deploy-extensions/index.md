---
title: "Introduction to Bicep Local Deploy extensions"
status: published
tags: ["Course", "Build custom Bicep extensions with Bicep Local Deploy"]
published_at: "2025-10-24T11:28:30.000Z"
custom_template: "custom-lesson"
---

<p><strong>Bicep Local Deploy extensions</strong> launched their simplified authoring experience in v0.37.4, opening up a whole new world of management capabilities <em>outside</em> Azure. They're .NET-based services that enable Bicep to manage <em>any</em> resource with a REST API. From third-party SaaS platforms to internal APIs and custom services, you can now create an extension and write a Bicep file to deploy your infrastructure — just like you would with native Azure resources.</p><p>Unlike traditional Bicep, which is limited to <strong>Azure Resource Manager, </strong>Bicep Local Deploy extensions let you bring your own resources into your deployment. You define:</p><ul><li>The type models with .NET.</li><li>The handlers that communicate with REST APIs.</li><li>Bicep starts treating these custom resources like native Azure resources.</li></ul><p><strong>What you'll learn:</strong></p><p>In this module, you'll learn the fundamentals of working with Bicep Local Deploy extensions. By the end of this module, you'll be able to:</p><ul><li>Understand what Bicep Local Deploy extensions are and how they extend Bicep's capabilities.</li><li>Identify the key components of the framework and their roles.</li><li>Recognize real-world scenarios where custom extensions add value.</li><li>Set up your development environment with .NET SDK and other tooling.</li><li>Scaffold a new extension project using templates.</li></ul><h2 id="what-are-bicep-local-deploy-extensions">What are Bicep Local Deploy extensions?</h2><p>Bicep Local Deploy extensions enable you to extend Bicep's capabilities outside Azure. Normally, you would use the Azure CLI or PowerShell to deploy a Bicep file. But what if you're not working with Azure and still want to use Bicep's framework?</p><p>That's where Bicep Local Deploy extensions come in. You can manage custom resources through REST APIs, integrate with your third-party services, and create Infrastructure as Code (IaC) solutions for any platform that exposes an HTTP API.</p><h3 id="how-extensions-work">How extensions work</h3><p>Extensions are tiny .NET applications that run locally during Bicep deployments. When Bicep encounters a resource type defined by your extension, it communicates with your extension service to:</p><ol><li><strong>Preview</strong> the resource state before deployment.</li><li><strong>Create or update</strong> resources based on your Bicep configuration.</li><li><strong>Retrieve </strong>resource identifiers and output properties.</li></ol><p>Here's a rough diagram of how the components interact:</p><figure class="kg-card kg-image-card kg-card-hascaption"><img src="http://localhost:2367/content/images/2025/10/image-2.png" class="kg-image" alt="Figure 1: Components interaction" loading="lazy" width="1024" height="1536"><figcaption><span style="white-space: pre-wrap;">Figure 1: Components interaction</span></figcaption></figure><p>This architecture allows Bicep to maintain its declarative syntax while enabling integration with any REST API.</p><h2 id="key-components">Key components</h2><p>The Bicep Local Deploy ecosystems consist of several key components, where one is developed by the Bicep team and the other by the community.</p><h3 id="the-azurebiceplocalextension-library">The Azure.Bicep.Local.Extension library</h3><p>The official .NET library from the Bicep team for building local extensions:</p><ul><li><code>TypedResourceHandler&lt;TProps, TIdentifiers, TConfig&gt;</code> – Base class for resource handlers.</li><li><code>ResourceRequest</code> and <code>ResourceResponse</code> – Request/response handling.</li><li>Extension host configuration and registration.</li><li>HTTP client integration for REST APIs.</li></ul><p>Here's a C# snippet of how a basic resource handler structure looks:</p><pre><code class="language-csharp">using Bicep.Local.Extension.Types;&#10;
public class ApiKeyHandler : TypedResourceHandler&lt;ApiKeyProperties, ApiKeyIdentifiers, ApiKeyConfig&gt;
{
    public ApiKeyHandler(HttpClient httpClient) : base(httpClient)
    {
    }&#10;
    // Preview what will be created/updated
    public override Task&lt;ResourceResponse&lt;ApiKeyProperties&gt;&gt; Preview(
        ResourceRequest&lt;ApiKeyProperties, ApiKeyConfig&gt; request)
    {
        // Preview logic here
    }&#10;
    // Create or update the resource
    public override Task&lt;ResourceResponse&lt;ApiKeyProperties&gt;&gt; CreateOrUpdate(
        ResourceRequest&lt;ApiKeyProperties, ApiKeyConfig&gt; request)
    {
        // Call REST API to create/update
    }&#10;
    // Delete the resource
    public override Task&lt;ResourceResponse&lt;ApiKeyProperties&gt;&gt; Delete(
        ResourceRequest&lt;ApiKeyProperties, ApiKeyConfig&gt; request)
    {
        // Call REST API to delete
    }&#10;
    // Get resource identifiers
    public override Task&lt;ResourceResponse&lt;ApiKeyIdentifiers&gt;&gt; GetIdentifiers(
        ResourceRequest&lt;ApiKeyProperties, ApiKeyConfig&gt; request)
    {
        // Return unique identifiers
    }
}</code></pre><h3 id="the-biceplocalextensiontypesattributes">The Bicep.Local.Extension.Types.Attributes</h3><p>These are the core attributes provided by the Bicep team for defining resource types and their properties. The attributes are fundamental to creating Bicep resources, providing type safety and metadata that enables the IntelliSense in your editor.</p><p>Every extension must use these attributes to define its resource schema:</p><ul><li><code>[ResourceType]</code> – Marks a class as a Bicep resource type with a unique identifier.</li><li><code>[TypeProperty]</code> – Defines resource properties with descriptions, required/optional flags, and read-only outputs.</li></ul><p>The following example defines a resource type with its core attributes:</p><pre><code class="language-csharp">using Bicep.Local.Extension.Types.Attributes;&#10;
// Mark this class as a Bicep resource type
[ResourceType("ApiKey")]
public class ApiKeyProperties
{
    // Required property
    [TypeProperty(Description = "The name of the API key", Required = true)]
    public string? Name { get; set; }&#10;
    // Optional property with validation
    [TypeProperty(Description = "The environment where the key is used")]
    public string? Environment { get; set; }&#10;
    // Read-only output property
    [TypeProperty(Description = "The generated API key value", ReadOnly = true)]
    public string? KeyValue { get; set; }&#10;
    // Secure property (hidden in logs)
    [TypeProperty(Description = "Metadata for the key", Secure = true)]
    public string? Metadata { get; set; }
}&#10;
// Identifiers class for unique resource identification
public class ApiKeyIdentifiers
{
    [TypeProperty(Description = "The unique identifier of the API key")]
    public string? Id { get; set; }&#10;
    [TypeProperty(Description = "The resource name")]
    public string? Name { get; set; }
}&#10;
// Configuration class for extension settings
public class ApiKeyConfig
{
    [TypeProperty(Description = "The base URL of the API")]
    public string? BaseUrl { get; set; }&#10;
    [TypeProperty(Description = "Authentication token", Secure = true)]
    public string? Token { get; set; }
}</code></pre><h3 id="the-biceplocaldeploy-library-optional">The Bicep.LocalDeploy library (optional)</h3><p>The unofficial library created by the community to provide attributes to annotate your resource models for documentation generation. It consists of four annotation attributes you can add to your code:</p><ul><li><code>[BicepDocHeading]</code> – Customizes documentation headings.</li><li><code>[BicepDocExample]</code> – Adds usage examples to documentation.</li><li><code>[BicepFrontMatter]</code> – Adds YAML front matter for documentation sites.</li><li><code>[BicepDocCustom]</code> – Includes custom documentation sections.</li></ul><p>The following example illustrates how you can add these annotation attributes:</p><pre><code class="language-csharp">using Bicep.LocalDeploy;
using Bicep.Local.Extension.Types.Attributes;&#10;
[BicepFrontMatter("title: ApiKey Resource\nlayout: documentation")]
[BicepDocHeading("API Key Management", "Manage API keys for your service")]
[ResourceType("ApiKey")]
public class ApiKeyProperties
{
    [TypeProperty(Description = "The name of the API key", Required = true)]
    [BicepDocExample("myApiKey", "A unique identifier for your API key")]
    public string? Name { get; set; }&#10;
    [TypeProperty(Description = "The environment where the key is used")]
    [BicepDocExample("production", "Valid values: development, staging, production")]
    public string? Environment { get; set; }&#10;
    [TypeProperty(Description = "Expiration date in ISO 8601 format")]
    [BicepDocExample("2025-12-31T23:59:59Z", "When the API key expires")]
    public string? ExpiresAt { get; set; }&#10;
    [TypeProperty(Description = "The generated API key value", ReadOnly = true)]
    [BicepDocCustom("Security", "This value is sensitive and should be stored securely")]
    public string? KeyValue { get; set; }
}</code></pre><h3 id="bicep-local-deploy-docs-generator-cli-optional">Bicep Local Deploy docs generator CLI (optional)</h3><p>A command-line tool developed by the community that generates Markdown documentation from the earlier-mentioned annotated models. When you use the <code>Bicep.LocalDeploy</code> library annotations to decorate your resource models, the <code>bicep-local-docgen</code> transforms them into rich documentation with:</p><ul><li>Examples</li><li>Usage patterns</li><li>Property descriptions</li><li>Custom sections</li></ul><p>Key capabilities of the CLI:</p><ul><li>Analyzes C# source code using Roslyn compiler services.</li><li>Extracts documentation from both core Bicep attributes and documentation specific.</li><li>Generates consistent Markdown documentation with proper formatting. </li><li>Validates documentation completeness by running analysis.</li></ul><p>Example usage can be found on <a href="https://github.com/Gijsreyn/bicep-local-docgen/blob/main/docs/cli.md">GitHub</a>. In the last module lesson, you'll use this CLI to create documentation.</p><h3 id="bicep-local-deploy-templates">Bicep Local Deploy templates</h3><p>The Bicep Local Deploy templates are unofficial and created by the community. It are .NET templates to accelerate extension development by providing a complete working starting point. These templates contain best practices and include a build automation script that builds and publishes your extension locally.</p><p>What the templates provide:</p><ul><li>Preconfigured project structure with organized folders for:<ul><li>Models</li><li>Handlers</li><li>Configuration</li></ul></li><li>Sample resource models annotated with both core Bicep and documentation attributes.</li><li>Build and publish scripts (PowerShell) for packing your extension.</li><li>README with setup instructions and development guidelines.</li></ul><p>Throughout this course, you'll use this to scaffold your extension project.</p><h2 id="real-world-scenarios">Real-world scenarios</h2><p>Where do Bicep Local Deploy extensions shine? Well, you've already read it in this lesson: <em>"when you want to manage resources outside Azure and leverage Bicep."</em></p><p>Many organizations use a hybrid approach by combining Azure infrastructure with third-party SaaS platforms, on-premises systems, or custom internal APIs. Often, they extend Bicep with custom deployment scripts to entirely write in Bicep. This leads to the development of large deployment scripts. Extensions bridge this gap. Rather than working with multiple tools and deployment scripts, you develop an <strong>extension</strong>.</p><p>The following subsections describe some common scenarios in which extensions add value.</p><h3 id="scenario-1-managing-databricks-resources">Scenario 1: Managing Databricks resources</h3><p>You've developed your IaC in Bicep to deploy an Azure Databricks instance and any other required resources. You now want to create a resource within the instance, but you hit a wall: it's not possible to use Bicep out of the box. </p><p>That's where an extension comes into play. Databricks always offered a rich REST API, and as you've just learned, extensions can leverage REST APIs to extend further. Here's an example in Bicep code to create a Databricks cluster:</p><pre><code class="language-bicep">resource cluster 'Cluster' = {
  name: 'analytics-cluster'
  sparkVersion: '13.3.x-scala2.12'
  nodeTypeId: 'Standard_DS3_v2'
  numWorkers: 2
}</code></pre><h3 id="scenario-2-configuring-saas-applications">Scenario 2: Configuring SaaS applications</h3><p>Your team is deploying applications to Azure, but you also need to set up GitHub repositories, maybe configure CI/CD secrets, and add collaborators. Typically, you'd use the GitHub CLI or manually configure it. This fragments your deployment across multiple tools and scripts.</p><p>With a GitHub extension, you can manage your entire pipeline in a single Bicep template. GitHub provides REST API calls for multiple areas, and extensions bring that directly into your IaC workflow. Here's an example in Bicep code to create a GitHub repository with secrets and collaborators:</p><pre><code class="language-bicep">extension github with {
  token: githubToken
}&#10;
resource repo 'Repository' = {
  owner: owner
  name: 'my-app'
  description: 'Application repository'
  visibility: 'Public'
}&#10;
resource collaborator 'Collaborator' = {
  owner: owner
  repo: repo.name
  user: collaboratorName
}&#10;
resource secret 'ActionsSecret' = {
  owner: owner
  repo: repo.name
  name: 'AZURE_CREDENTIALS'
  value: azureServicePrincipalSecret
}</code></pre><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">ℹ️</div><div class="kg-callout-text">In practice, it's not fully possible (yet) to define both scopes e.g. <code spellcheck="false" style="white-space: pre-wrap;">targetScope = 'local'</code> and <code spellcheck="false" style="white-space: pre-wrap;">targetScope = 'subscription'</code>.</div></div><p></p><h3 id="scenario-3-custom-resource-providers">Scenario 3: Custom resource providers</h3><p>Many organizations build internal APIs for managing resources that are unique to their business needs. These systems often lack IaC tooling, forcing teams to rely on custom scripts or even do it manually.</p><p>With Bicep extensions, you can bring your internal APIs into the Bicep IaC ecosystem. By creating an extension for your custom resource provider, platform teams can expose a consistent, type-safe interface for managing these internal resources.</p><p>This approach is valuable for building internal developer platforms where standardization and self-service are key priorities. Here's an example of how that would look like roughly:</p><pre><code class="language-bicep">extension inventory with {
  baseUrl: 'https://inventory.myorganization.com/api'
}&#10;
resource server 'Inventory' = {
  hostname: 'app-server-01'
  environment: 'production'
  team: 'platform-engineering'
}</code></pre><h2 id="architecture-overview">Architecture overview</h2><p>Understanding the architecture helps you effective Bicep Local Deploy extensions. Unlike traditional Bicep deployments that communicate directly with Azure Resource Manager, the Bicep Local Deploy extension introduces a local service layer that acts as a bridge between Bicep's declarative syntax and any REST API.</p><p>This architectural pattern gives you the flexibility to integrate with any HTTP-enabled service while maintaining Bicep's type safety, validation, and declarative deployment model.</p><p>The architecture is designed for extensibility and isolation. Each extension runs a separate .NET application, allowing you to version, test, and deploy extensions independently. The Bicep CLI discovers and communicates with extensions through JSON-RPC, sending requests and receiving responses. Your extension translates these requests into REST API calls and returns the output.</p><pre><code class="language-markdown">┌─────────────────┐
│  Bicep file     │
│  (main.bicep)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Bicep CLI      │◄─────── Bicep compilation
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Extension      │
│  Service        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  REST API       │
│  (Your service) │
└─────────────────┘</code></pre><h3 id="component-interaction-flow">Component interaction flow</h3><p>The lifecycle of an extension deployment follows a predictable pattern, mirroring the declarative nature of Bicep itself:</p><ol><li><strong>Design time: </strong>You write Bicep files using extension resources with full IntelliSense support. The Bicep language service validates your syntax, checks the property types, and provides suggestions based on your extension's type definitions.</li><li><strong>Build time: </strong>Bicep CLI validates syntax and types, ensuring all required properties are present and correctly typed.</li><li><strong>Deploy time: </strong>Extension service receives request from the Bicep CLI (<code>bicep local-deploy</code>) for each resource operation. The extension validates incoming requests and determines what actions need to be taken against the target API.</li><li><strong>Runtime: </strong>The extension makes the actual REST API calls to manage resources, handle authentication, and parse responses. </li><li><strong>Completion: </strong>Extension returns resource outputs to Bicep.</li></ol><h2 id="setting-up-your-development-environment">Setting up your development environment</h2><p>Setting up your development environment for Bicep Local Deploy extensions is straightforward. It works across Windows, macOS, and Linux. The cross-platform nature of .NET means you can develop extensions on your preferred operating system. </p><p>In this section, you'll install the core dependencies needed to build extensions:</p><ul><li>The .NET SDK</li><li>The Bicep CLI</li><li>Project templates</li><li>Documentation generator</li></ul><p>The installation process can be automated through package managers, making it easy for you to get started. Once everything is installed, you'll verify your setup by creating a test extension project.</p><h3 id="install-net-sdk">Install .NET SDK</h3><p>The .NET SDK is available for all major platforms. Choose the installation method for your operating system.</p><p>For Windows:</p><pre><code class="language-powershell"># Install .NET 9.0 SDK using WinGet
winget install Microsoft.DotNet.SDK.9&#10;
# Verify installation
dotnet --version
# Should output: 9.0.x or later</code></pre><p>For macOS:</p><pre><code class="language-bash"># Install .NET SDK using Homebrew
brew install dotnet-sdk&#10;
# Verify installation
dotnet --version</code></pre><p>For Linux (Ubuntu/Debian):</p><pre><code class="language-bash"># Add Microsoft package repository
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb&#10;
# Install .NET SDK
sudo apt-get update
sudo apt-get install -y dotnet-sdk-9.0&#10;
# Verify installation
dotnet --version</code></pre><p>For other Linux distributions or manual installation, visit the <a href="https://dotnet.microsoft.com/download">official .NET download page</a>.</p><h3 id="installing-bicep-cli">Installing Bicep CLI</h3><p>The Bicep CLI is required to compile and deploy Bicep Local Deploy files. Install it using your platform's package manager.</p><p>For Windows:</p><pre><code class="language-powershell"># Install Bicep CLI using WinGet
winget install Microsoft.Bicep&#10;
# Verify installation
bicep --version</code></pre><p>For macOS:</p><pre><code class="language-bash"># Install Bicep CLI using Homebrew
brew install bicep&#10;
# Verify installation
bicep --version</code></pre><p>For Linux (using Azure CLI):</p><pre><code class="language-bash"># Install Azure CLI first if not already installed
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash&#10;
# Install Bicep CLI via Azure CLI
az bicep install&#10;
# Verify installation
bicep --version</code></pre><p>Alternatively, on Linux, you can download the Bicep CLI binary directly from the <a href="https://github.com/Azure/bicep/releases">Bicep releases page</a>.</p><h3 id="installing-the-templates-package">Installing the templates package</h3><p>To get started easily, you can install the <code>Bicep.LocalDeploy.Templates</code> package globally:</p><pre><code class="language-bash">dotnet new install Bicep.LocalDeploy.Templates</code></pre><p>Verify the installation:</p><pre><code class="language-bash">dotnet new list --tag Bicep</code></pre><p>You should see:</p><pre><code class="language-plaintext">Template Name                 Short Name       Language  Tags
----------------------------  ---------------  --------  ---------------------------
Bicep Local Deploy Extension  bicep-ld-tpl     [C#]      Bicep/Extension/LocalDeploy</code></pre><h3 id="install-the-documentation-cli">Install the documentation CLI</h3><p>At the end of this module, there will be a lesson on creating documentation. To already prepare you for this lesson, you can install the <code>bicep-local-docgen</code> globally:</p><pre><code class="language-bash">dotnet tool install bicep-local-docgen -g</code></pre><p>Verify the installation:</p><pre><code class="language-bash">bicep-local-docgen --version</code></pre><h3 id="configure-your-editor">Configure your editor</h3><p>Visual Studio Code (VS Code) is the preferred editor for developing the Bicep Local Deploy extension. It is cross-platform and has a rich extension ecosystem. To install VS Code on the different platforms, use one of the following methods:</p><p>For Windows:</p><pre><code class="language-powershell"># Install VS Code using WinGet
winget install Microsoft.VisualStudioCode&#10;
# Launch VS Code
code</code></pre><p>For macOS:</p><pre><code class="language-bash"># Install VS Code using Homebrew
brew install --cask visual-studio-code&#10;
# Launch VS Code
code</code></pre><p>For Linux (Ubuntu/Debian):</p><pre><code class="language-bash"># Download and install VS Code
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor &gt; packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" &gt; /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg&#10;
sudo apt-get update
sudo apt-get install code&#10;
# Launch VS Code
code</code></pre><p>Alternatively, download VS Code directly from <a href="https://code.visualstudio.com/">code.visualstudio.com</a> for any platform.</p><p>Once VS Code is installed, add the following extensions:</p><pre><code class="language-bash"># Install C# Dev Kit (C# language support, debugging, project management)
code --install-extension ms-dotnettools.csdevkit&#10;
# Install Bicep (Bicep language support, IntelliSense, validation)
code --install-extension ms-azuretools.vscode-bicep&#10;
# Install PowerShell (PowerShell scripting support for build scripts)
code --install-extension ms-vscode.powershell</code></pre><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">ℹ️</div><div class="kg-callout-text">For the C# Dev Kit, you need a valid license or subscription.</div></div><p></p><h2 id="understanding-the-development-workflow">Understanding the development workflow</h2><p>Building a Bicep extension follows a structured workflow that takes you from an empty project to a deployable, ready extension. By following this pattern, you can quickly add functionality to an extension while maintaining code quality and documentation. Each step builds on the previous one.</p><p>A typical extension development workflow follows these steps:</p><ol><li><strong>Scaffold:</strong> Create project from template (or manual).</li></ol><p>Start by generating a new extension project using a template. This gives you a pre-configured project structure with sample resources.</p><ol start="2"><li><strong>Define: </strong>Design resource models with attributes.</li></ol><p>Design your resource types by creating C# classes annotated with <code>[ResourceType]</code> and <code>[TypeProperty]</code> attributes. Define what properties your resources will have, which are required or optional, and what outputs they produce. This is where you establish the contract between Bicep and your extension. Add documentation attributes like <code>[BicepDocExample]</code> and <code>[BicepDocHeading]</code> to enrich your API documentation from the start.</p><ol start="3"><li><strong>Implement: </strong>Code resource handlers and API integration.</li></ol><p>Build the business logic by implementing resource handlers that inherit from <code>TypedResourceHandler&lt;TProps, TIdentifiers, TConfig&gt;</code>. Write the code that translates Bicep resource requests into REST API calls. This is where you integrate with external APIs, handle authentication, and manage errors.</p><ol start="4"><li><strong>Test: </strong>Run locally and validate behavior.</li></ol><p>Test your extension by building it locally and deploying it using regular Bicep files. Use the <code>bicep local-deploy</code> command to validate the functionality.</p><ol start="5"><li><strong>Document: </strong>Generate documentation from attributes.</li></ol><p>Generate documentation using the <code>bicep-local-docgen</code> CLI tool. This extracts all metadata from your annotated models and automatically generates Markdown documentation.</p><ol start="6"><li><strong>Publish: </strong>Publish the extension to a container registry.</li></ol><p>Bicep can use a container registry to publish and install extensions. Configure the extension path in your Bicep configuration file, then use it in your Bicep files with the <code>extension</code> keyword.</p><h2 id="quick-start-verify-your-setup">Quick start: Verify your setup</h2><p>Now that everything is in place, let's verify everything is installed correctly by creating a test extension:</p><pre><code class="language-powershell">```bash
# Create a test extension
dotnet new bicep-ld-tpl -n HelloBicep&#10;
# Navigate to the project
cd HelloBicep&#10;
# Build the extension
.\build.ps1
```</code></pre><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">⚠️</div><div class="kg-callout-text">If you get an error on <code spellcheck="false" style="white-space: pre-wrap;">dotnet</code> version, update the <code spellcheck="false" style="white-space: pre-wrap;">global.json</code> file with the version you're using.</div></div><p></p><p>If the build succeeded, your environment is correctly configured, and a new <code>output</code> directory is created with a file in the root of the directory named <code>my-extension</code>.</p><h2 id="next-up">Next up</h2><p>Now that you understand the basics and have your environment set up, you're ready to create your first extension. In the next lesson, you'll:</p><ul><li>Explore the template project structure.</li><li>Define custom resource models.</li><li>Implement resource handlers.</li><li>Test your extension with Bicep files.</li></ul>
