---
title: "How to use the `this` namespace in Bicep to check resources"
status: published
tags: ["Azure", "Bicep"]
published_at: "2025-11-21T04:38:03.000Z"
custom_excerpt: "Learn how to prevent common deployment failures from immutable property changes"
feature_image: "images/2025-11-7262e91c-4a25-4c78-b883-e027261840b6.png"
---

<p>Often you face challenges when deploying Azure resources against existing one: templates behave differently for new resources versus existing ones.</p><p>Some properties can only be set during creation, whilst others should be preserved during updates. You can't always know which scenario will happen until runtime. The <code>this</code> namespace solves this problem by enabling runtime checks and conditional logic based on the resource's existence.</p><p>In this guide, you will:</p><ul><li>Use <code>this.exists()</code> to determine if a resource already exists at deployment time.</li><li>Access existing resource properties with <code>this.existingResource()</code>.</li><li>Set different values for new resources versus updates.</li><li>Enable the experimental <code>this</code> namespace feature in your Bicep environment.</li></ul><h2 id="prerequisites">Prerequisites</h2><p>Before you dive in, you need to have:</p><ul><li>Bicep CLI nightly build installed.</li><li>A <code>bicepconfig.json</code> file in your project.</li></ul><p>To install the nightly CLI build, you can use:</p><pre><code class="language-powershell">iex "&amp; { $(irm https://aka.ms/bicep/nightly-cli.ps1) }"</code></pre><p>You can enable the experimental feature by creating or updating your <code>bicepconfig.json</code> file in your project root:</p><pre><code class="language-json">{
  "experimentalFeaturesEnabled": {
    "thisNamespace": true
  }
}</code></pre><h2 id="check-resource-existence">Check resource existence</h2><p>The <code>this.exists()</code> function is newly introduced in Bicep and returns a boolean value. This boolean value indicates whether the resource already exists in Azure at deployment time.</p><p>You can use <code>this.exists()</code> to set different default values for new versus existing resources:</p><pre><code class="language-bicep">resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // New storage accounts default to disabled public access
    // Existing accounts keep their current configuration
    allowBlobPublicAccess: this.exists() ? false : true
  }
}</code></pre><p>The function only works at deployment time, not compilation time. Azure examines the current state of your subscription and then returns the result. The Bicep compiler translates <code>this.exists()</code> to <code>[not(empty(target('full')))]</code> in the generated ARM template.</p><h2 id="access-existing-resource-properties">Access existing resource properties</h2><p>The other function newly introduced is the <code>this.existingResource()</code> function. This returns the complete resource object if it exists, or returns <code>null</code> if it doesn't. With this function, you can read the current property values and preserve them during updates.</p><p>By combining <code>this.existingResource()</code> with the safe navigation operator (<code>?.</code>), you can access nested properties without causing errors:</p><pre><code class="language-bicep">resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // Preserve the existing retention policy if it exists
    deleteRetentionPolicy: this.existingResource().?properties.deleteRetentionPolicy
  }
}</code></pre><p>Using the <code>?.</code> operator prevents Azure from throwing errors when the resource doesn't exist. If <code>this.existingResource()</code> returns <code>null</code>, the whole expression evaluates to <code>null</code>. </p><h2 id="combine-existence-checks-with-property-access">Combine existence checks with property access</h2><p>It's also possible to use both in combination for more complex scenarios. The following pattern is useful when you want to apply different configurations based on the current resource state.</p><p>In the following template, both <code>this.exists()</code> and <code>this.existingResource()</code> are used:</p><pre><code class="language-bicep">resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: 'mystorageaccount'
  location: 'westus'
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // New accounts get secure defaults
    // Existing accounts preserve their current settings
    allowBlobPublicAccess: this.exists() 
      ? this.existingResource().?properties.allowBlobPublicAccess 
      : false
  }&#10;  
  resource fileService 'fileServices' = {
    name: 'default'
    properties: {
      // Always preserve existing retention policies
      shareDeleteRetentionPolicy: this.existingResource().?properties.shareDeleteRetentionPolicy
    }&#10;    
    resource fileShare 'shares' = {
      name: 'exampleshare'
      properties: {
        // Keep the current access tier if it exists
        accessTier: this.existingResource().?properties.accessTier
      }
    }
  }
}</code></pre><p>Using the above pattern works with nested resources. Each resource independently checks the existence and accesses the current state. The template adapts to the presence or absence of the parent storage account and its nested resources.</p><h2 id="understand-function-limitations">Understand function limitations</h2><p>The <code>this</code> namespace functions have specific limitations (or constraints) that you should understand before implementing.</p><p>These functions only work inside resource property blocks. You cannot use them in:</p><ul><li>Resource names</li><li>Module parameters</li><li>Top-level loop expressions</li></ul><p>This restriction exists because the functions depend on the <em>resource context</em>.</p><pre><code class="language-bicep">// ✓ Valid - inside properties block
resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageAccountName
  properties: {
    allowBlobPublicAccess: this.exists() ? false : true
  }
}&#10;
// ✗ Invalid - in resource name
resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: this.exists() ? 'existing' : 'new'  // Error
  properties: {}
}</code></pre><h2 id="summary">Summary</h2><p>This quick guide demonstrated how to use the <code>this</code> namespace in Bicep templates. You've covered:</p><ul><li>Enable the experimental feature <code>thisNamespace</code> in the <code>bicepconfig.json</code> file.</li><li>Used <code>this.exists()</code> to determine if resources already exist at deployment time.</li><li>Accessed existing configurations with <code>this.existingResource()</code> and safe navigation operators</li><li>Implemented different behaviors for new versus existing resources</li></ul><p>By leveraging the <code>this</code> namespace, you eliminate the need for separate create and update templates while preventing deployment failures from immutable property changes. To learn more, check out the official documentation in the <a href="https://github.com/Azure/bicep/blob/main/docs/experimental-features.md#thisnamespace">Bicep repository</a>.</p>
