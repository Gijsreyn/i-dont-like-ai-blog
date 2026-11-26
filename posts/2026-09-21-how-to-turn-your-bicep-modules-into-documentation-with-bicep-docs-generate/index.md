---
title: "How to turn your Bicep modules into documentation with bicep docs generate"
status: published
tags: ["Bicep", "Azure"]
published_at: "2026-09-21T03:28:12.000Z"
custom_excerpt: "Turn Bicep modules into Markdown documentation with the experimental docs generate command and customizable Scriban templates."
feature_image: "images/cover.jpg"
---

<p>Changing a Bicep parameter takes seconds. Remembering every place that parameter appears in your README is another story.</p>
<p>In my previous <a href="/a-first-look-at-azure-biceps-new-documentation-generator/">post</a>, I looked at the history behind Bicep's new documentation generator and the community tooling that helped us get here. This time, I want to put the command to work. No more background story: let's take a module, generate its documentation, and then make that documentation look the way we want.</p>
<p>The interesting part isn't just getting a parameter table. It's getting that table from the compiler, alongside constraints, examples, and type information, without maintaining another interpretation of your module.</p>
<h2 id="before-you-begin">Before you begin</h2>
<p>You need a standalone Bicep CLI build that includes the experimental <code>docs</code> command(use <a href="https://github.com/Azure/bicep/releases/tag/v0.47.16">v0.47.16</a> or above). Check availability on your system with:</p>
<pre><code class="language-powershell">bicep --version
bicep docs --help
</code></pre>
<p>Run this through <code>bicep</code>, not <code>az bicep</code>. The Azure CLI doesn't expose this command group.</p>
<blockquote>
<p>[!IMPORTANT]<br>
Documentation generation is experimental. No feature flag is required, but command options, configuration, and template behavior can change. Pin your CLI version if you use it in automation.</p>
</blockquote>
<p>You also need a module that compiles successfully. Generating documentation doesn't deploy resources, so you can follow along without creating a storage account in Azure.</p>
<h2 id="1-give-the-generator-something-worth-documenting">1. Give the generator something worth documenting</h2>
<p>Create a folder named <code>storage</code> and save the following module as <code>storage/main.bicep</code>:</p>
<pre><code class="language-bicep">metadata name = 'Storage Account'
metadata description = 'Deploys a storage account for application data.'&#10;
@description('The globally unique storage account name.')
@minLength(3)
@maxLength(24)
param storageAccountName string&#10;
@description('The Azure region for the storage account.')
param location string = resourceGroup().location&#10;
@description('The storage account SKU.')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS'])
param skuName string = 'Standard_LRS'&#10;
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
  }
}&#10;
@description('The resource ID of the storage account.')
output storageAccountId string = storageAccount.id
</code></pre>
<p>The metadata supplies the document's title and introduction. Parameter and output descriptions become reference text, while decorators provide constraints. Required status comes from whether a parameter has a default value, not from wording you put in its description.</p>
<p>The resource disables anonymous blob access and shared-key authorization and requires HTTPS. It's deliberately small, not a complete production networking design.</p>
<p>This is also where useful documentation starts. The generator can expose what the compiler knows, but it can't explain your design decisions unless you write them down.</p>
<h2 id="2-generate-and-inspect-the-markdown">2. Generate and inspect the Markdown</h2>
<p>From the parent folder, run:</p>
<pre><code class="language-powershell">bicep docs generate ./storage/main.bicep
</code></pre>
<p>The command creates <code>storage/README.md</code>. An experimental warning on standard error is expected.</p>
<p>The built-in document includes navigation, resource types, parameters, and outputs. Here's a shortened excerpt, with navigation, resource types, and some parameter details omitted:</p>
<pre><code class="language-markdown"># Storage Account&#10;
Deploys a storage account for application data.&#10;
## Parameters&#10;
| Name | Type | Required | Description |
| :-- | :-- | :-- | :-- |
| `location` | `string` | No | The Azure region for the storage account. |
| `skuName` | `string` | No | The storage account SKU. |
| `storageAccountName` | `string` | Yes | The globally unique storage account name. |&#10;
### `skuName`&#10;
- Default value: `'Standard_LRS'`&#10;
- Allowed values: `Standard_GRS`, `Standard_LRS`, `Standard_ZRS`&#10;
### `storageAccountName`&#10;
- Min length: 3&#10;
- Max length: 24&#10;
## Outputs&#10;
| Name | Type | Description |
| :-- | :-- | :-- |
| `storageAccountId` | `string` | The resource ID of the storage account. |
</code></pre>
<p>Notice that parameters are sorted by name rather than declaration order. The allowed values and length constraints also come directly from the module.</p>
<p>More complex modules expose nested properties and discriminated union cases. Exported types, variables, and functions get their own sections when present. You aren't limited to the information that survives compilation into an ARM template.</p>
<p>To preview without touching an existing README, use:</p>
<pre><code class="language-powershell">bicep docs generate ./storage/main.bicep --stdout
</code></pre>
<p>Or choose an explicit destination:</p>
<pre><code class="language-powershell">bicep docs generate ./storage/main.bicep --outfile ./docs/storage.md
</code></pre>
<blockquote>
<p>[!TIP]<br>
Treat the generated file as output, not the source of truth. Successful regeneration replaces its contents. Keep handwritten guidance in your source descriptions or template fragments instead.</p>
</blockquote>
<h2 id="3-include-an-example-people-can-copy">3. Include an example people can copy</h2>
<p>A parameter table explains the interface. An example shows someone how to use it.</p>
<p>Save this as <code>storage/examples/minimal.bicep</code>:</p>
<pre><code class="language-bicep">metadata name = 'Minimal deployment'
metadata description = 'Uses the default region and storage SKU.'&#10;
module storage '../main.bicep' = {
  params: {
    storageAccountName: 'stcontosominimal'
  }
}
</code></pre>
<p>Run the generation command again. The README now includes a <strong>Usage Examples</strong> section with the heading <strong>Example 1: <em>Minimal deployment</em></strong>, its description, and the example's Bicep source in a code block. Readers should replace the sample account name with a globally unique value before deployment.</p>
<p>By default, discovery includes top-level Bicep files and nested <code>main.bicep</code> files under <code>examples</code>, plus <code>*.test.bicep</code> files anywhere under <code>tests</code>. Dependency files matching <code>dependencies*.bicep</code> are excluded.</p>
<p>Literal <code>metadata name</code> and <code>metadata description</code> declarations give examples readable titles and descriptions. Examples are ordered by their relative paths. Discovery includes source text; don't mistake its appearance in the README for proof that an example has been deployed or tested.</p>
<h2 id="4-make-the-output-yours-with-scriban">4. Make the output yours with Scriban</h2>
<p>The default layout is useful, but your repository might need ownership details, different headings, or a shorter reference section.</p>
<p>Bicep uses <a href="https://github.com/scriban/scriban">Scriban</a>, a .NET text-templating engine. Plain text passes through unchanged. Expressions inside <code>{{ ... }}</code> insert values, while loops and conditionals control what gets rendered. You don't need to install Scriban separately.</p>
<p>Crucially, the template doesn't parse Bicep. It receives a structured <code>module</code> object built from the compiler's semantic model. That separates understanding the language from deciding how the documentation looks.</p>
<p>Create <code>templates/readme.scriban</code> alongside the <code>storage</code> folder:</p>
<pre><code class="language-scriban"># {{ module.name }}&#10;
{{ module.description }}&#10;
Owner: {{ custom.owner }}&#10;
## Parameters
{{~ for parameter in module.parameters ~}}
- `{{ parameter.name }}` ({{ parameter.type }}{{ if parameter.required }}, required{{ end }}): {{ parameter.description }}
{{~ end ~}}&#10;
## Outputs
{{~ for output in module.outputs ~}}
- `{{ output.name }}` ({{ output.type }}): {{ output.description }}
{{~ end ~}}
</code></pre>
<p>Here, <code>module.parameters</code> and <code>module.outputs</code> are collections. The conditional adds “required” only where appropriate. The <code>~</code> markers trim surrounding whitespace so control statements don't leave unwanted blank lines.</p>
<p>Select the template with a <code>bicepconfig.json</code> in the parent folder:</p>
<pre><code class="language-json">{
  "documentation": {
    "template": {
      "file": "templates/readme.scriban",
      "includeRoot": "templates"
    }
  }
}
</code></pre>
<p>Both paths resolve relative to that configuration file. Each module uses its nearest configuration, so a nested configuration can change which documentation settings apply.</p>
<p>Now render with an ownership value:</p>
<pre><code class="language-powershell">bicep docs generate ./storage/main.bicep --stdout --custom-template-value "owner=Platform Team"
</code></pre>
<p>The custom template produces:</p>
<pre><code class="language-markdown"># Storage Account&#10;
Deploys a storage account for application data.&#10;
Owner: Platform Team&#10;
## Parameters
- `location` (string): The Azure region for the storage account.
- `skuName` (string): The storage account SKU.
- `storageAccountName` (string, required): The globally unique storage account name.&#10;
## Outputs
- `storageAccountId` (string): The resource ID of the storage account.
</code></pre>
<p>This replaces the built-in layout entirely. Our intentionally short template doesn't render constraints or examples, even though they're still available in the model. For a full replacement, also consider <code>module.resourceTypes</code>, <code>module.exportedTypes</code>, and <code>module.usageExamples</code>.</p>
<h2 id="5-reuse-content-without-editing-generated-files">5. Reuse content without editing generated files</h2>
<p>Scriban includes let you keep shared guidance outside the generated document. For example, save support instructions in <code>templates/_support.md</code> and add this to your template:</p>
<pre><code class="language-scriban">{{ include "_support.md" }}
</code></pre>
<p>The configured <code>includeRoot</code> makes Scriban look in the templates folder. Without it, includes resolve from each module's folder, not automatically from the template's location.</p>
<p>For more custom values, pass <code>--custom-template-value</code> repeatedly or use <code>--custom-template-value-file-path</code> with a JSON object whose values are strings. Values are processed in command-line order; the last value for a key wins.</p>
<p>Use these values for information the compiler can't supply, such as ownership or support links. Keep parameter descriptions in Bicep rather than duplicating them in template configuration.</p>
<h2 id="6-generate-documentation-across-a-repository">6. Generate documentation across a repository</h2>
<p>Once the single-module output looks right, use a glob:</p>
<pre><code class="language-powershell">bicep docs generate --pattern './modules/**/main.bicep' --outdir ./docs
</code></pre>
<p>A module at <code>modules/storage/main.bicep</code> produces <code>docs/storage/README.md</code>. Without <code>--outdir</code>, each document is written beside its module. The directory option preserves the configured output filename; <code>--outfile</code> selects an exact path for one module.</p>
<p>In CI, regenerate documentation and check for changes to committed output. Pinning the CLI and keeping templates in source control makes those diffs easier to review.</p>
<p>Compilation failures return a nonzero exit code. Bulk generation continues past modules with compilation errors, but setup, rendering, or write failures stop the command. A compile or render failure doesn't replace an existing document for that module.</p>
<p>For long-running tooling, <code>bicep/generateDocs</code> also exposes generation through JSON-RPC, with a .NET wrapper in <code>Azure.Bicep.RpcClient</code>. It returns content rather than writing files.</p>
<h2 id="summary">Summary</h2>
<p>Start with metadata and meaningful descriptions, generate the default Markdown, and add examples that show how to consume the module. Then introduce Scriban only where your documentation needs a different layout or additional context.</p>
<p>For me, that's the useful shift: keep the facts with the Bicep code, keep presentation in a template, and stop manually synchronizing the two. The command is experimental, but an existing module is a good place to try it and give feedback.</p>
