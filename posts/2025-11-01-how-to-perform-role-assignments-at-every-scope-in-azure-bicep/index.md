---
title: "How to perform role assignments at every scope in Azure Bicep"
status: published
tags: ["Bicep", "Azure"]
published_at: "2025-11-01T04:52:12.000Z"
custom_excerpt: "Learn how to perform role assignments at every scope in Azure Bicep"
feature_image: "images/2025-10-scopes.png"
---

<p>Have you ever copied and pasted the same role assignment code three times, once for each Azure scope?</p><p>If you maintain infrastructure at different scopes (e.g., management groups, subscriptions, and resource groups), you know the pattern. You need consistent RBAC policies, but each scope demands its own deployment target. You write similar Bicep modules, then duplicate the same logic across the scope. But the deployment commands and resource scopes differ just enough to force separate templates.</p><p>This repetition can breed drifting. One template gains a condition parameter, and another gets updated role mappings. A third still references an older API version. Onboarding new team members means explaining why "it's the same pattern, just different scopes".</p><p>In this blog post, you'll learn about a recent addition to the Azure Verified Modules (AVM) public registry, where one module rules them all. </p><h2 id="one-module-three-scopes">One module, three scopes</h2><p>AVM now ships a role assignment module that handles all three scopes from a single pattern. Alexander Sehr <a href="https://github.com/Azure/bicep-registry-modules/pull/5153">created a multi-scope design</a>, and it's live in the public registry at version <code>0.1.0</code>.</p><p>The parent lives at <code>avm/res/authorization/role-assignment</code>, and each child module is published under a scope-specific path:</p><ul><li><code>br/public:avm/res/authorization/role-assignment/mg-scope:0.1.0</code></li><li><code>br/public:avm/res/authorization/role-assignment/sub-scope:0.1.0</code></li><li><code>br/public:avm/res/authorization/role-assignment/rg-scope:0.1.0</code></li></ul><p>You pick the scope you need, reference the corresponding module, and supply at least the same core parameters every time: <code>principalId</code> and <code>roleDefinitionIdOrName</code>. The rest, such as conditions, descriptions, or telemetry toggles, remain optional across all three variants.</p><h2 id="why-this-matters">Why this matters</h2><p>Imagine now a scenario where you're setting up RBAC for a new compliance initiative. Your platform team needs <code>Reader</code> access at the management group level to audit all subscriptions. Your development team needs <code>Contributor</code> rights scoped to their individual resource groups, and lastly, the finance departments want cost visibility across specific subscriptions.</p><p>You can already see it here. Three different scopes, three different audiences, but the same underlying task: to assign a role to a principal. Before this module, you maintained three separate templates. The management group would look something like:</p><pre><code class="language-bicep">// mg-role-assignment.bicep
targetScope = 'managementGroup'&#10;
resource mgRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managementGroup().id, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: 'ServicePrincipal'
  }
}</code></pre><p>The subscription version is another:</p><pre><code class="language-bicep">targetScope = 'subscription'&#10;
resource subRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: 'ServicePrincipal'
  }
}</code></pre><p>And the resource group in a third:</p><pre><code class="language-bicep">// rg-role-assignment.bicep
targetScope = 'resourceGroup'&#10;
resource rgRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: 'ServicePrincipal'
  }
}</code></pre><p>When you need to add ABAC conditions or update role mappings, you'll probably go to edit each template individually. Then your favorite smart newcomer asked: </p><p><em>"Why the hell is the same logic applied three times?" </em></p><p>You've to explain that there are different scopes, different deployment targets.</p><p>Now you write your role assignment logic once. <strong>One pattern, many scopes. </strong>That's the design of the AVM module. </p><h2 id="choosing-your-scope">Choosing your scope</h2><p>The parent module handles scoping by adding the required parameters or specifying the current context.</p><p>For example, imagine you want to deploy at the management group scope. It will look as follows:</p><pre><code class="language-bicep">module roleAssignment 'br/public:avm/res/authorization/role-assignment:0.1.0' = {
  name: 'roleAssignmentDeployment'
  params: {
    principalId: '&lt;principal object id&gt;'
    roleDefinitionIdOrName: 'Resource Policy Contributor'
    location: '&lt;location&gt;'
    principalType: 'ServicePrincipal'
    // Omit managementGroupId to use current scope, or add it to target a specific group
    managementGroupId: '&lt;management-group-id&gt;'
  }
}</code></pre><p>If you're going to do it for a subscription, you can use the <code>subscriptionId</code>:</p><pre><code class="language-bicep">module roleAssignment 'br/public:avm/res/authorization/role-assignment:0.1.0' = {
  name: 'roleAssignmentDeployment'
  params: {
    principalId: '&lt;principal object id&gt;'
    roleDefinitionIdOrName: 'Reader'
    location: '&lt;location&gt;'
    principalType: 'ServicePrincipal'
    subscriptionId: '&lt;subscription-id&gt;'
  }
}</code></pre><p>And lastly, the resource group-level:</p><pre><code class="language-bicep">module roleAssignment 'br/public:avm/res/authorization/role-assignment:0.1.0' = {
  name: 'roleAssignmentDeployment'
  params: {
    principalId: '&lt;principal object id&gt;'
    roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11'
    location: '&lt;location&gt;'
    principalType: 'ServicePrincipal'
    subscriptionId: '&lt;subscription-id&gt;'
    resourceGroupName: '&lt;resource-group-name&gt;'
  }
}</code></pre><h2 id="summary">Summary</h2><p>The module is live in the Bicep public registry for you to use. Reference it once, control the scope with parameters, and deploy. One module, all scopes. No more drift in templates.</p><p>Are you going to get started with it? Bet you do!</p>
