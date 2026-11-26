---
title: "Using inline() function for runtime parameter overrides in Azure Bicep"
status: published
tags: ["Bicep", "Azure"]
published_at: "2025-11-03T22:32:59.000Z"
custom_excerpt: "Learn how to use the new inline() function in Azure Bicep to provide runtime parameter overrides directly within your deployments."
feature_image: "images/2025-11-arrows.png"
---

<p>You've been there. You create a <code>.bicepparam</code> file, leave out a required parameter because you want to supply it at deployment time, and Bicep throws a BCP258 error in your face.</p><p>Bad luck? Maybe.</p><p>That error makes perfect sense from a validation perspective. But it broke a legitimate workflow: providing sensitive values like passwords, API keys, or environment-specific configurations at the command line during deployment.</p><p>The <code>inline()</code> (or the syntactic sugar <code>externalInput()</code> function) function fixes this. It's a placeholder that tells Bicep, "I'll provide this value later." No errors and no workarounds needed. Just clean parameter files that defer values to deployment time. </p><p>This blog post dives into the problem it solves, how it works, and provides real-world examples.</p><h2 id="the-problem-this-solves">The problem this solves</h2><p>Before <code>inline()</code>, you had a few options, but none were splendid for every scenario:</p><ol><li>Use the <code>getSecret()</code> function to reference Azure Key Vault secrets (great for secrets already in Key Vault).</li><li>Use <code>readEnvironmentVariable()</code> to read environment variables at compile time (works, but requires setting the variable before compilation).</li><li>Hardcode values in your <code>.bicepparam</code> file (don't do this).</li><li>Remove required parameters and deal with validation errors (bad for peace of mind).</li></ol><p>The <code>inline()</code> function fills a specific gap. While Key Vault functions work when secrets are stored in Azure, and <code>readEnvironmentVariable()</code> works for compile-time environment variables, <code>inline()</code> shines when you need to:</p><ul><li>Deploy the sample template to multiple environments with different credentials.</li><li>Provide secrets through Azure CLI (or Azure PowerShell soon)</li><li>Use DevOps pipelines that inject parameters at runtime.</li></ul><h2 id="how-inline-works">How inline() works</h2><p>The <code>inline()</code> function acts as a placeholder in your parameter file. When you build your parameters with overrides, Bicep replaces `inline()` with the actual value you provide.</p><p>Here's the syntax:</p><pre><code class="language-bicep">using './main.bicep'&#10;
param apiKey = inline()
param connectionString = inline()
param environment = 'production'</code></pre><p>At build time, you provide the override values:</p><pre><code class="language-bash">az bicep build-params main.bicepparam \
  --parameters-override apiKey="secret-key-123" \
  --parameters-override connectionString="Server=..."</code></pre><p>The generated parameters file includes your runtime values without ever exposing them in source control.</p><h2 id="real-world-examples">Real-world examples</h2><p>Theory is nice. But let's see how <code>inline()</code> solves actual problems you might face every day.</p><h3 id="example-1-multi-environment-deployments">Example 1: Multi-environment deployments</h3><p>You're deploying to dev, staging, and production. Each environment needs different database credentials:</p><pre><code class="language-bicep">using './database.bicep'&#10;
param serverName = 'sql-${environment}'
param adminUsername = inline()
param adminPassword = inline()
param environment = inline()</code></pre><p>The deployment commands:</p><pre><code class="language-bash"># Dev environment
az bicep build-params params.bicepparam \
  --parameters-override environment="dev" \
  --parameters-override adminUsername="dev-admin" \
  --parameters-override adminPassword="${DEV_PASSWORD}"&#10;
# Staging environment
az bicep build-params params.bicepparam \
  --parameters-override environment="dev" \
  --parameters-override adminUsername="dev-admin" \
  --parameters-override adminPassword="${STAGING_PASSWORD}"&#10;
# Production environment
az bicep build-params params.bicepparam \
  --parameters-override environment="prod" \
  --parameters-override adminUsername="prod-admin" \
  --parameters-override adminPassword="${PROD_PASSWORD}"</code></pre><h3 id="example-2-nested-object-properties">Example 2: Nested object properties</h3><p>The <code>inline()</code> function works inside object properties, not just top-level parameters:</p><pre><code class="language-bicep">using './app.bicep'&#10;
param config = {
  appName: 'my-app'
  secrets: {
    apiKey: inline()
    clientSecret: inline()
  }
  region: 'eastus'
}</code></pre><p>When you override, use the property name as the key:</p><pre><code class="language-bash">az bicep build-params app.bicepparam \
  --parameters-override apiKey="key-value" \
  --parameters-override clientSecret="secret-value"</code></pre><h3 id="example-3-devops-pipeline-integration">Example 3: DevOps pipeline integration</h3><p>In GitHub Actions or Azure Pipelines, you can inject secrets without storing them in parameter files:</p><pre><code class="language-yaml">- name: Build Bicep Parameters
  run: |
    az bicep build-params production.bicepparam \
      --parameters-override sqlPassword="${{ secrets.SQL_PASSWORD }}" \
      --parameters-override apiKey="${{ secrets.API_KEY }}" \
      --stdout &gt; parameters.json</code></pre><h2 id="important-constraints">Important constraints</h2><p>The <code>inline()</code> function has specific rules about where it can appear in your parameter files. These constraints exist to maintain type safety and ensure predictable behavior during the build process.</p><p><strong>You CAN use inline():</strong></p><ul><li>In parameter assignments</li><li>In object property values</li><li>In array elements</li></ul><p><strong>You CANNOT use inline():</strong></p><ul><li>In variable declarations</li><li>In string interpolation</li><li>In decorators</li></ul><p>If you try using <code>inline()</code> in an invalid location, you'll get a clear error message telling you why.</p><h2 id="choosing-your-approach-inline-vs-alternatives">Choosing your approach: inline() vs alternatives</h2><p>Here's the thing: Bicep gives you multiple tools for the same job, and that's actually a good thing. Each approach has its moment to shine. I've used all three, and here's what I've learned about when each one makes the most sense.</p><p><strong>Use <code>inline()</code></strong> for values provided via CLI at build time:</p><pre><code class="language-bicep">param apiKey = inline()  // Provided via --parameters-override</code></pre><p><strong>Use <code>readEnvironmentVariable()</code></strong> for compile-time environment variables:</p><pre><code class="language-bicep">param apiKey = readEnvironmentVariable('API_KEY')
param apiKeyWithDefault = readEnvironmentVariable('API_KEY', 'default-value')</code></pre><p><strong>Use <code>kv.getSecret()</code></strong> for secrets already in Key Vault:</p><pre><code class="language-bicep">resource kv 'Microsoft.KeyVault/vaults@2025-05-01' existing = {
  name: 'my-keyvault'
}&#10;
module app 'app.bicep' = {
  name: 'app'
  params: {
    apiKey: kv.getSecret('apiKey')  // Retrieved from Key Vault at deployment
  }
}</code></pre><p>The key differences:</p><ul><li><code>inline()</code>: Value provided explicitly via CLI flag at build time.</li><li><code>readEnvironmentVariable()</code>: Value read from environment variable during compilation.</li><li><code>getSecret()</code>: Value retrieved from Azure Key Vault during deployment.</li></ul><p>And honestly? Skip <code>inline()</code> if the value is known at authoring time—just hardcode it. The same goes for non-sensitive, environment-agnostic parameters. If your secret is already sitting in Key Vault, use <code>getSecret()</code> instead. And if you've already got environment variables set up on your build machine, <code>readEnvironmentVariable()</code> provides cleaner syntax with less ceremony.</p><h2 id="summary">Summary</h2><p>The <code>inline()</code> function is available in the nightly builds of Bicep and is likely to be released in Bicep v0.39+. To use it, start updating your <code>.bicepparam</code> files and use the <code>az bicep build-params</code> with <code>--parameters-override</code> flags. </p><p>That's it. No additional configuration required. Just a cleaner way to handle runtime parameter values.</p><p>The next time you need to provide a password during deployment, you'll know exactly what to do. </p>
