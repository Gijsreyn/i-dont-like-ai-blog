---
title: "The platform engineer's guide to dynamic cluster policy enforcement in Databricks"
status: published
tags: ["Databricks", "Azure"]
published_at: "2025-12-12T03:42:47.000Z"
custom_excerpt: "Learn how to use the lookup function and mutators"
feature_image: "images/cover.jpg"
---

<p>Have you seen the following symptom: developers export jobs from the Databricks graphical user interface (GUI), only to find out later that they have to modify them when they reach production?</p><p>I've seen it and experienced it. From a platform engineering perspective, managing a Databricks instance with many clusters can be painful.</p><p>But with the launch of Python Databricks Asset Bundles (DABs), now in General Availability (GA) status, you gain more control. Control that has minimal impact on developers' exported job workflows. It also lets you avoid over-privileging either personal or non-personal accounts when leveraging the policy definitions you've created.</p><p>Let me show you how.</p><h2 id="prerequisites">Prerequisites</h2><p>Before you start your journey, there are three prerequisites:</p><ul><li>Databricks CLI v0.275.0 or above.</li><li>A Databricks instance.</li><li>Uv v0.9.17 or above.</li></ul><p>When these are in place, you're good to go.</p><h2 id="understanding-the-problem">Understanding the problem</h2><p>Often, developers create job workflows through the GUI. They receive YAML containing raw resource IDs. This works when they're testing in environments like development or test. But when they deploy it through DABs in production, these resource IDs wouldn't exist.</p><pre><code class="language-yaml">job_clusters:
  - job_cluster_key: development_cluster
    new_cluster:
      policy_id: "001DD81A49229D7C"
      num_workers: 4</code></pre><p>There's also another problem. Most environments operate under a "least privilege" model, and DABs are deployed via CI/CD systems. You can give the identity running the deployment many privileges, but why would you?</p><p>That's where you can use cluster policy definitions and provide the identity with the <em>Can manage </em>permission, allowing job workflows to spawn a job cluster when they need to.</p><p>But how do you instruct your developers to use the policy definition? And how can you make their lives easier without constantly modifying all <em>job workflows</em>?</p><h2 id="solution-1-lookup-function">Solution 1: Lookup function</h2><p>To provide a proper solution, there are two ingredients: the <em>lookup </em>function and <em>mutators</em>. Before you think, "What the hell are <em>mutators?", </em>hold that thought. I'll cover this one later. Let's first look at the lookup function.</p><p>The lookup function allows you to use the resource name instead of the resource ID. This enables you to reference cluster policies by their human-readable name.</p><p>For example, imagine you have the cluster policy definition named <em>small job cluster. </em>In your <code>databricks.yml</code> file, you can use it as follows:</p><pre><code class="language-yaml">variables:
  small_policy_id:
    description: The cluster policy ID to apply to all small job clusters
    lookup:
      cluster_policy: "small job cluster"</code></pre><p>When deploying a DAB containing the job workflow, it will fetch the cluster policy definition resource ID. The lookup function supports multiple resource types:</p><ul><li><code>alert</code></li><li><code>cluster_policy</code></li><li><code>cluster</code></li><li><code>dashboard</code></li><li><code>instance_pool</code></li><li><code>job</code></li><li><code>metastore</code></li><li><code>notificaiton_destination</code></li><li><code>pipeline</code></li><li><code>query</code></li><li><code>service_principal</code></li><li><code>warehouse</code></li></ul><p>You can now directly reference it in your job cluster definition as such:</p><pre><code class="language-yaml">job_clusters:
  - job_cluster_key: main_cluster
    new_cluster:
      policy_id: ${var.small_policy_id}
      num_workers: 2</code></pre><h2 id="solution-2-python-mutators">Solution 2: Python mutators</h2><p>The lookup function solves the portability problem. But what if developers forget to reference the cluster policy variable altogether? Or what if you want to enforce the policy without modifying every job definition?</p><p>That's where mutators come in.</p><p>You can see Python mutators as simple functions. Functions that transform resources during deployment. They run after all resources are loaded, but before deployment. This means you can intercept every job that gets deployed and apply cluster policies automatically.</p><p>To keep it even simpler, think of mutators as middleware for DABs. Developers export their jobs from the GUI, drop them in the resources folder, and your mutator handles the rest.</p><p>Let's take a look at how we can implement mutators step by step.</p><h3 id="step-1-initialize-a-python-dab">Step 1: Initialize a Python DAB</h3><p>To use mutators, you need a Python-enabled DAB. The easiest way to get started is with the <code>pydabs</code> template:</p><pre><code class="language-bash">databricks bundle init pydabs</code></pre><p>Follow the prompts provided by the template. This creates a project structure with Python support already configured:</p><pre><code class="language-plaintext">your_bundle/
├── databricks.yml
├── pyproject.toml
├── resources/
│   └── __init__.py
├── src/
│   └── your_bundle/
└── tests/</code></pre><h3 id="step-2-create-the-mutator-file"><strong>Step 2: Create the mutator file</strong></h3><p>Create a file named <code>mutators.py</code> in your bundle root. This file contains functions decorated with <code>@job_mutator</code> that transform jobs during deployment:</p><pre><code class="language-python">from dataclasses import replace&#10;
from databricks.bundles.core import Bundle, Variable, job_mutator, variables
from databricks.bundles.jobs import ClusterSpec, Job, JobCluster&#10;&#10;
@variables
class BundleVariables:
    """
    Bundle variables resolved at deployment time.&#10;    
    These map to the variables defined in databricks.yml.
    The @variables decorator enables type-safe access to bundle variables.
    """
    cluster_policy_id: Variable[str]
    num_workers: Variable[str]&#10;&#10;
@job_mutator
def apply_cluster_policy(bundle: Bundle, job: Job) -&gt; Job:
    """
    Applies a cluster policy to all job clusters.&#10;    
    This mutator ensures governance by applying a cluster policy 
    to all job clusters, regardless of how the job was defined.
    Developers can export jobs from the GUI without worrying about
    cluster policies
    """
    # Skip jobs without job clusters
    if not job.job_clusters:
        return job&#10;
    # Resolve the cluster policy ID from bundle variables
    try:
        policy_id = bundle.resolve_variable(BundleVariables.cluster_policy_id)
    except Exception:
        # No policy configured, skip mutation
        return job&#10;
    # Skip if policy_id is empty or unresolved
    if not policy_id or policy_id.startswith("${"):
        return job&#10;
    # Get num_workers from variables (policies often require fixed workers)
    try:
        num_workers_str = bundle.resolve_variable(BundleVariables.num_workers)
        num_workers = int(num_workers_str) if num_workers_str else 4
    except Exception:
        num_workers = 4&#10;
    # Apply the policy to each job cluster
    updated_clusters = []
    for cluster in job.job_clusters:
        if cluster.new_cluster:
            updated_spec = replace(
                cluster.new_cluster,
                policy_id=policy_id,
                num_workers=num_workers,
                autoscale=None,  # Remove autoscale for policy compliance
                apply_policy_default_values=True,
            )
            updated_clusters.append(replace(cluster, new_cluster=updated_spec))
        else:
            updated_clusters.append(cluster)&#10;
    return replace(job, job_clusters=updated_clusters)</code></pre><p>Key points about this mutator:</p><ul><li>The <code>@variables</code> decorator creates a type-safe mapping to your <code>databricks.yml</code> variables.</li><li>The <code>@job_mutator</code> decorator registers the function to run on every job during deployment.</li><li>The function receives the current <code>Bundle</code> context and the <code>Job</code> being processed.</li><li>It must return a <code>Job</code> object (either the original or a modified copy).</li><li>The <code>replace()</code> function from <code>dataclasses</code> creates immutable copies with updated fields.</li></ul><h3 id="step-3-configure-variables-in-databricksyml"><strong>Step 3: Configure variables in databricks.yml</strong></h3><p>Add the cluster policy variable using the lookup function, and define the num_workers variable:</p><pre><code class="language-yaml">variables:
  cluster_policy_id:
    description: The cluster policy ID to apply to all job clusters
    lookup:
      small_cluster_policy: "small job cluster"
  num_workers:
    description: Fixed number of workers (required by most cluster policies)
    default: "4"</code></pre><h3 id="step-4-register-the-mutator"><strong>Step 4: Register the mutator</strong></h3><p>In your <code>databricks.yml</code>, add the mutator to the Python configuration section. Mutators run in the order they're listed:</p><pre><code class="language-yaml">python:
  venv_path: .venv
  mutators:
    - "mutators:apply_cluster_policy"</code></pre><p>The format is <code>module_name:function_name</code>. Since <code>mutators.py</code> is in the bundle root, the module name is <code>mutators</code>.</p><h3 id="step-5-add-developer-job-definitions"><strong>Step 5: Add developer job definitions</strong></h3><p>Now your developers can export jobs from their GUI and place them in the <code>resources/</code> folder. For example, a file named <code>resources/my_job.yaml</code>:</p><pre><code class="language-yaml">resources:
  jobs:
    my_etl_job:
      name: "My ETL Job"
      job_clusters:
        - job_cluster_key: main_cluster
          new_cluster:
            spark_version: "14.3.x-scala2.12"
            node_type_id: "Standard_D4s_v5"
            num_workers: 2
      tasks:
        - task_key: ingest_data
          job_cluster_key: main_cluster
          notebook_task:
            notebook_path: ../src/notebooks/ingest.py</code></pre><p>Notice there's no <code>policy_id</code> in the job definition. The mutator adds it automatically during deployment.</p><h3 id="step-6-configure-per-target-overrides-optional"><strong>Step 6: Configure per-target overrides (optional)</strong></h3><p>Different environments often require different cluster policies. You can override the lookup per target:</p><pre><code class="language-yaml">targets:
  dev:
    mode: development
    variables:
      # Uses the default lookup from bundle variables&#10;      
  prod:
    mode: production
    variables:
      # Override with a production-specific policy
      cluster_policy_id:
        lookup:
          cluster_policy: "production job cluster"</code></pre><h2 id="validation-and-deployment">Validation and deployment</h2><p>To validate whether the mutator or lookup function works, you can use the <code>bundle validate</code> command:</p><pre><code class="language-bash">databricks bundle validate --target dev</code></pre><p>The expected output:</p><pre><code class="language-plaintext">Name: your_bundle
Target: dev
Workspace:
  Host: https://your-workspace.azuredatabricks.net
  User: your.email@company.com
  Path: /Workspace/Users/your.email@company.com/.bundle/your_bundle/dev&#10;
Validation OK!</code></pre><p>To deploy the bundle, use the <code>bundle deploy</code> command:</p><pre><code class="language-bash">databricks bundle deploy --target dev</code></pre><p>During deployment, the CLI loads all resources, runs your mutators, and then deploys the transformed jobs. Every job cluster now includes the cluster policy. Your developers didn't have to know anything about the resource ID.</p><h2 id="summary">Summary</h2><p>Now that Python DABs are GA, attention shifts to engineering teams that need to enforce governance rules in Databricks. </p><p>With the lookup function, you get <em>portability</em>, allowing you to reuse the exact bundle definition across development, test, and production environments without developers hardcoding IDs.</p><p>With mutators, you get automatic enforcement. Developers can export jobs from the GUI, and your policies will automatically apply them. No manual edits required, and no forgotten policy references. </p><p>For more information, check out the <a href="https://docs.databricks.com/dev-tools/bundles/index.html">official documentation on Databricks</a>.</p>
