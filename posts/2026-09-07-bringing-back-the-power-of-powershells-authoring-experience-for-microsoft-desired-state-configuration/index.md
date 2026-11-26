---
title: "Bringing back the power of PowerShell's authoring experience for Microsoft Desired State Configuration"
status: published
tags: ["PowerShell", "Microsoft Desired State Configuration v3"]
published_at: "2026-09-07T06:09:14.000Z"
custom_excerpt: "PowerShell's imperative power and Microsoft DSC's declarative engine can finally meet in the middle"
feature_image: "images/cover.jpg"
---

<p>You've just received the task to investigate the upgrade from PowerShell Desired State Configuration (PSDSC) to Microsoft DSC and are expected to still be able to use the <code>configuration</code> keyword. Bad luck, that doesn't work in Microsoft DSC anymore.</p><p>The configuration management landscape tool from Microsoft has moved on. MOF  never caught on outside DSC when you compiled the <code>configuration</code> block. The new DSC engine speaks JSON and YAML documents with a real expression language. That means no more <em>real </em>PowerShell loops or conditionals. So the old authoring power was left behind. If you want a v3 or above configuration document, you write it by hand mostly in YAML.</p><p>An RFC by Steve Lee, a detailed community review of it, and now a working prototype are exploring how to bring back that power. This blog post walks through the design, decision by decision, with the reasoning behind each one.</p><blockquote>
<p>[!WARNING]<br>
Before you read any further: none of this is actually released already.</p>
<p>Everything in this post describes a <em>draft design under an open RFC</em> and a prototype built to make that discussion concrete. There is nothing in the PowerShell Gallery and it might mean that nothing here is guaranteed to survive the review.</p>
</blockquote>
<h2 id="the-design-that-needs-your-attention">The design that needs your attention</h2><p>The beautiful part about an RFC is not that it's really an announcement. It's a tour of design decisions that are still open for debate. So that means you can still be involved in three things: agree, object, or propose something better. The RFC's discussion can be used while it still matters.</p><p>Those three inputs shape what you're about to see:</p><ol><li>The draft RFC proposing PowerShell script authoring for Microsoft DSC.</li><li>A community review that checked the ideas against how the engine <em>actually </em>behaves (think about schema strictness, escaping rules, deprecated features).</li><li>A prototype module that turned both into something you can argue with.</li></ol><p>Every section below ends with the question you're best placed to answer.</p><h2 id="what-it-feels-like-today">What it feels like today</h2><p>Here's a full script, end to end. This is the mental model for everything that follows:</p><pre><code class="language-powershell">Import-Module DscResource.Configuration&#10;
$doc = New-DscConfigurationDocument -ContentVersion '1.0.0' -Metadata ([ordered]@{
    Name   = 'MyConfiguration'
    Author = 'SteveL-MSFT'
})&#10;
$doc.Parameters += New-DscParameter -Name 'computerName' -Type String -Required
$doc.Parameters += New-DscParameter -Name 'environment' -Type String -DefaultValue 'Production'&#10;
$echo = New-DscResourceInstance -Type 'Microsoft.DSC.Debug/Echo' -Name 'My echo' -Properties @{
    output = 'Hello World'
}&#10;
$echo2 = New-DscResourceInstance -Type 'Microsoft.DSC.Debug/Echo' -Name 'My echo 2' -Properties @{
    output = { $dsc.Parameters.environment + ' ' + $dsc.Parameters.computerName }
} -DependsOn $echo&#10;
$doc.Resources.Add($echo)
$doc.Resources.Add($echo2)&#10;
$doc | Export-DscConfigurationDocument -Path './MyConfiguration.dsc.json'</code></pre><p>You can already see it: imperative in, declarative out:</p><pre><code class="language-json">{
  "$schema": "https://aka.ms/dsc/schemas/v3/bundled/config/document.json",
  "contentVersion": "1.0.0",
  "metadata": {
    "Name": "MyConfiguration",
    "Author": "SteveL-MSFT"
  },
  "parameters": {
    "computerName": { "type": "string" },
    "environment": { "type": "string", "defaultValue": "Production" }
  },
  "resources": [
    {
      "type": "Microsoft.DSC.Debug/Echo",
      "name": "My echo",
      "properties": { "output": "Hello World" }
    },
    {
      "type": "Microsoft.DSC.Debug/Echo",
      "name": "My echo 2",
      "dependsOn": [ "[resourceId('Microsoft.DSC.Debug/Echo', 'My echo')]" ],
      "properties": {
        "output": "[concat(parameters('environment'), ' ', parameters('computerName'))]"
      }
    }
  ]
}</code></pre><p>Notice a couple of things here that you did not have to write: the <code>schema</code> URI, any camelCase key, the <code>resourceId(...)</code> expression, the <code>concat(...)</code> expression. You just wrote PowerShell, and the module wrote the DSC engine.</p><p>Now, let's look at every decision below that explains one piece of each gap.</p><h2 id="decision-1-%E2%80%93-two-doors-into-the-same-room">Decision 1 – Two doors into the same room</h2><p>The RFC asked for both cmdlets *and* types, and the prototype takes that seriously: everything you can do with a cmdlet, you can do with the object directly. Cmdlets are the discoverable door - <code>Get-Command -Noun Dsc*</code> finds them, tab completion walks you through them. Types are the direct door for people who think in objects.</p><pre><code class="language-powershell"># Door 1: cmdlets
$doc = New-DscConfigurationDocument
$doc.Parameters += New-DscParameter -Name 'computerName' -Type String
$doc | Export-DscConfigurationDocument -Path './MyConfiguration.dsc.json'&#10;
# Door 2: the types directly
$doc = [DscConfigurationDocument]::new()
$doc.Parameters += [DscParameter]@{ Name = 'computerName'; Type = [DscDataType]::String }
$doc.Export('./MyConfiguration.dsc.json')</code></pre><p>The important design detail sits within the class: the class methods <em>call the cmdlets</em>. There is exactly one implementation of every behavior, so the two doors can't drift apart.</p><p><strong>Your call</strong><em>: </em>is one door enough? Should the documentation showcase one style as canonical, meaning every example and doc page teaches the cmdlets, and the classes become a supported but unadvertised implementation detail? Or is dual-surface parity worth maintaining forever?</p><h2 id="decision-2-%E2%80%93-the-module-owns-the-schema-exactness">Decision 2 – The module owns the schema exactness</h2><p>In the community review, there was one sharp observation. The engine is <em>opinionated</em>. That means every document must carry a recognized <code>$schema</code> URI, all wire fields are camelCase, parameters are a map keyed by name, and a resource instance with unrecognized fields is rejected outright.</p><p>In the prototype, none of that is the author's job now. You pick a schema version from an enum; the module knows the URL. You write PascalCase and the serializer writes camelCase. And parameters give you the best of both worlds. They <em>feel </em>like a list but <em>serialize </em>as the schema's map:</p><pre><code class="language-powershell">$doc = New-DscConfigurationDocument -SchemaVersion V3_2 -ContentVersion '2.0.0'&#10;
# List-like authoring, exactly as the RFC's example wrote it:
$doc.Parameters += New-DscParameter -Name 'computerName' -Type String
$doc.Parameters.Add((New-DscParameter -Name 'environment' -DefaultValue 'Production'))&#10;
# Keyed reading:
$doc.Parameters.environment.DefaultValue    # Production&#10;
# Duplicate names are an error, because the wire shape is a map:
$doc.Parameters += New-DscParameter -Name 'ComputerName'
# Error: A parameter named 'ComputerName' already exists in the document ...</code></pre><p>Underneath the above example, there's a smaller decision that's easy to miss. The document schema has no <code>required</code> field. Instead, a parameter without a <code>defaultValue</code> simply <em>is </em>mandatory. So <code>-Required</code> writes nothing into the document. It exists purely to let you state your intent and get caught contradicting it:</p><pre><code class="language-powershell"># Emits nothing. It just guards your intent:
$doc.Parameters += New-DscParameter -Name 'computerName' -Type String -Required&#10;
# Contradiction is structurally impossible (separate parameter sets):
New-DscParameter -Name 'x' -Required -DefaultValue 'y'
# Error: Parameter set cannot be resolved ...&#10;
# Constraint fields map straight to the schema, checked against the type up front:
New-DscParameter -Name 'oops' -Type String -MinValue 1
# Error: -MinValue/-MaxValue only apply to Int parameters (the engine rejects them on 'String').</code></pre><p><strong>Your call</strong>: is hiding the wire format the right instinct, or do you <em>want </em>to see and control the raw schema details as an author? </p><pre><code class="language-powershell"># Hidden wire format (today's design): you can't produce an invalid document -
# but you also can't produce anything the module hasn't learned:
$doc.Parameters += New-DscParameter -Name 'computerName' -Type String&#10;
# Raw control (the alternative): imagine the engine ships a new parameter field
# tomorrow, say 'deprecatedMessage'. With today's design you wait for a module
# update; with raw access to the wire shape you could simply write it yourself:
$doc.Parameters['computerName'].deprecatedMessage = 'Use nodeName instead.'   # hypothetical</code></pre><h2 id="decision-3-%E2%80%93-one-rule-for-time-plain-powershell-is-now-scriptblocks-are-later">Decision 3 – One rule for time: plain PowerShell is now, scriptblocks are later</h2><p>This is the heart of the design, and the reason for this post's title.</p><p>Every imperative construct in an authoring script could mean one of two things: it runs <em>while you generate the document</em> (build time), or it should be encoded <em>into the document</em> for the engine to evaluate when applying it (deploy time). The engine has its own conditionals and loops in its expression language, so a <code>foreach</code> or an <code>if</code> in your script is genuinely ambiguous - and ambiguity here means someone's production config does the wrong thing silently.</p><p>The design resolves it with one rule, borrowed directly from the community review:</p><ol><li><strong>Plain PowerShell is always build-time</strong>. A <code>foreach</code> unrolls into N literal instances. An <code>if</code> decides, right now, whether a resource is in the document at all.</li><li><strong>Deploy-time is always explicit</strong>. A <code>{ scriptblock }</code> value, <code>-Condition</code>, or a raw&nbsp; &nbsp;expression - those are the only doors to "later."</li><li><strong>Nothing is ever silently promoted</strong>. Your <code>if</code> never becomes a <code>condition</code> field on your behalf.</li></ol><pre><code class="language-powershell"># BUILD-TIME: this 'if' runs now. Depending on the machine generating the
# document, the 'audit' resource is either in the document or it isn't.
if ($env:BUILD_ENV -eq 'Production')
{
    $doc.Resources.Add((New-DscResourceInstance -Type 'Microsoft.DSC.Debug/Echo' `
        -Name 'audit' -Properties @{ output = 'auditing on' }))
}&#10;
# DEPLOY-TIME: the decision goes INTO the document; the engine makes it at apply time.
$doc.Resources.Add((New-DscResourceInstance -Type 'Microsoft.DSC.Debug/Echo' -Name 'audit' `
    -Condition { $dsc.Parameters.environment -eq 'Production' } `
    -Properties @{ output = 'auditing on' }))</code></pre><p>And the rule is <em>enforced</em>, not just documented. </p><pre><code class="language-powershell">$site = 'company'
$echo.Properties.output = { $site }
# Error: the variable $site is a build-time value that does not exist at deploy time.
# Fix-it: Evaluate it outside the scriptblock and assign the result, or reference
#         deploy-time state through $dsc.</code></pre><p><strong>Your call</strong>: does "never promote" match your intuition? Or would you expect a<code>foreach</code> to become an engine-side loop automatically, the way ARM templates (<code>copy</code> syntax) users might?</p><h2 id="decision-4-%E2%80%93-dsc-one-name-for-everything-that-happens-later"><strong>Decision 4 – <code>$dsc</code>: one name for everything that happens later</strong></h2><p>If you look at the RFC's draft, it writes deploy-time references through the document variable itself: <code>{ $config.Parameters['Environment'] }</code>. That works until someone renames <code>config</code>. It then forces the transpiler to guess which variable is "the document."</p><p>The review proposed a single automatic variable, <code>$dsc</code>, as the <em>only </em>deploy-time reference point, and the prototype adopted it:</p><pre><code class="language-powershell"># Draft design (RFC):
$echoResource2.Properties.Output = {
    $config.Parameters['Environment'] + ' ' + $config.Parameters['ComputerName']
}&#10;
# Current design:
$echoResource2.Properties.output = {
    $dsc.Parameters.environment + ' ' + $dsc.Parameters.computerName
}
# exports as: "[concat(parameters('environment'), ' ', parameters('computerName'))]"</code></pre><p>Two things about <code>$dsc</code> are worth understanding, because they explain a lot of behavior:</p><ol><li>The scriptblocks are never executed. The transpiler reads their syntax tree and recognizes <code>$dsc</code> <em>by name</em>. The <code>$dsc</code> object exists so your editor can offer IntelliSense. For example, <code>$dsc.Parameters.&lt;TAB&gt;</code> completes the parameters you've added to the current document so far. Call a <code>$dsc</code> method outside a scriptblock and it tells you so:</li></ol><pre><code class="language-powershell">$dsc.Reference('My echo')
# Error: $dsc.Reference() is only meaningful inside a DSC expression scriptblock
#        (a deploy-time value). At build time, use the document object directly.</code></pre><ol start="2"><li>The engine has ~80 expression functions, and the transpiler doesn't gate them. A gateway object, <code>$dsc.Fn</code>, is generated from a snapshot of the engine's function registry. Known functions get their argument counts checked; unknown ones are emitted verbatim with a warning, because a newer engine may know a function this module doesn't:</li></ol><pre><code class="language-powershell">$echo.Properties.output = { $dsc.Fn.toUpper($dsc.Parameters.computerName) }
# exports as: "[toUpper(parameters('computerName'))]"&#10;
$echo.Properties.output = { $dsc.Fn.concat() }
# Error: concat() takes 2 to unlimited arguments (got 0).</code></pre><p><strong>Your call</strong>: is <code>$dsc</code> the right name and the right surface? What would you expect to find on it that isn't there? And does <code>Reference</code>, <code>Secret</code>, <code>EnvVar</code>, <code>CopyIndex</code> plus the <code>Fn</code> gateway cover your real configurations?</p><h2 id="decision-5-%E2%80%93-your-operators-the-engines-functions">Decision 5 – Your operators, the engine's functions</h2><p>And honest refusals. The RFC said the transpiler "should allow for idiomatic PowerShell." The review pushed back: <em>idiomatic </em>only works if the mapping is <em>normative</em>, meaning there is one fixed, published table of what every PowerShell operator becomes in the expression language. </p><p>The transpiler follows that table exactly; authors can rely on it when predicting their output, and any place where two languages disagree is a deliberate, documented decision instead of an accident.</p><p>That table now exists in code. A sampler:</p><pre><code class="language-powershell">{ $dsc.Parameters.retryCount + 1 }               # [add(parameters('retryCount'), 1)]
{ $dsc.Variables.prefix + '-web' }               # [concat(variables('prefix'), '-web')]
{ $dsc.Parameters.environment -eq 'Production' } # [equals(parameters('environment'), 'Production')]
{ $dsc.Parameters.custom ?? 'default' }          # [coalesce(parameters('custom'), 'default')]
{ $dsc.Parameters.isProd ? 'prd' : 'dev' }       # [if(parameters('isProd'), 'prd', 'dev')]
{ "server-$($dsc.Parameters.environment)" }      # [format('server-{0}', parameters('environment'))]
{ $dsc.Parameters.tags -join ',' }               # [join(parameters('tags'), ',')]
{ $dsc.Parameters.name.ToLower() }               # [toLower(parameters('name'))]
{ $dsc.Parameters.names | Where-Object { $_ -ne 'skip' } }
#   [filter(parameters('names'), lambda('_', not(equals(lambdaVariables('_'), 'skip'))))]</code></pre><p>The more interesting decisions are the refusals. Where PowerShell semantics and engine semantics diverge, the prototype does not guess; it simply errors or warns at build time.</p><pre><code class="language-powershell"># '+' maps by static operand type. When neither side's type is known,
# refusing beats guessing:
{ $dsc.Parameters.a + $dsc.Parameters.b }
# Error: the static types of the '+' operands are unknown, so it is ambiguous
#        between add() and concat().
# Fix-it: Say which you mean: $dsc.Fn.add(a, b) or $dsc.Fn.concat(a, b).&#10;
# The engine's expression language has no floats, and no split/replace:
{ $dsc.Parameters.threshold + 0.5 }
# Error: the DSC expression language has no floating point numbers - only integers.
{ $dsc.Parameters.name.Split('-') }
# Error: the engine has no equivalent of .Split() ...</code></pre><p><strong>Your call</strong>: should <code>-eq</code> and <code>-ceq</code> keep transpiling to plain <code>equals()</code> with the case-sensitivity divergence documented, or emit case-normalizing expressions(<code>equals(toLower(...), toLower(...))</code>) to preserve PowerShell semantics exactly?</p><h2 id="decision-6-%E2%80%93-a-values-type-decides-what-it-is-never-its-content">Decision 6 – A value's type decides what it is, never its content</h2><p>The engine has a trap for the unwary: any string starting with <code>[</code> in an evaluated position is treated as an expression, and a literal leading bracket must be escaped as<code>[[</code>. Nobody should have to know that. The design makes the rule unexploitable by tying everything to the value's <em>type</em>:</p><pre><code class="language-powershell"># 1) Plain strings are ALWAYS data. The exporter escapes the bracket for you:
$echo.Properties.output = '[this is data, not an expression]'
# exports as: "output": "[[this is data, not an expression]"&#10;
# 2) Scriptblocks are ALWAYS expressions:
$echo.Properties.output = { $dsc.Parameters.computerName }
# exports as: "output": "[parameters('computerName')]"&#10;
# 3) New-DscExpression is the verbatim escape hatch. For the window where the
#    engine ships a function before this module's transpiler learns it:
$echo.Properties.output = New-DscExpression "newEngineFn(parameters('computerName'))"
# exports as: "output": "[newEngineFn(parameters('computerName'))]"</code></pre><p>The same "make the mistake impossible" instinct applies to secrets, with three layers of enforcement instead of one:</p><pre><code class="language-powershell"># Creation time: secure parameters refuse default values outright.
New-DscParameter -Name 'password' -Type SecureString -DefaultValue 'hunter2'
# Error: ... secret material must never appear in a configuration document ...&#10;
# Serialization time: a SecureString anywhere in the tree throws.
# Validation time: a NoSecureLiterals check catches anything imported.&#10;
# The sanctioned pattern - the document carries a *reference*, never the value:
$echo.Properties.password = { $dsc.Secret('myAppPassword') }
# exports as: "password": "[secret('myAppPassword')]"</code></pre><p><strong>Your call</strong>: is type-decides-everything the right contract, or are there cases where you would want content-based detection, meaning a string whose text looks like an expression gets treated as one?</p><pre><code class="language-powershell"># Say your expressions come from a data file the script reads at build time:
$fromFile = '[parameters(''computerName'')]'&#10;
# Type decides: it's a string, so it is data. It gets escaped and deploys as
# the literal text [parameters('computerName')], probably not what you meant:
$echo.Properties.output = $fromFile&#10;
# Today you must state your intent explicitly to get an expression:
$echo.Properties.output = New-DscExpression $fromFile</code></pre><h2 id="decision-7-%E2%80%93-trust-but-verify-and-take-your-intellisense-with-you">Decision 7 – Trust, but verify (and take your IntelliSense with you)</h2><p>Okay, the two closing decisions that come straight from the community review.</p><p><em>Export validates by default. </em>There are six checks that run before anything is written. Think about schema validation, unique pairs (<code>type, name</code>), <code>dependsOn</code> targets exist, and the graph is acyclic, every expression parses, no secure literals, and properties conform to known resource schemas. The document is handed to <code>dsc config validate</code>, so the engine should be available on your <code>PATH</code> environment variable. There's one opt-out option, which is explicit (<code>-SkipValidation</code>).</p><pre><code class="language-powershell"># Findings as records, or a boolean gate for CI:
$doc | Test-DscConfigurationDocument
if (-not ($doc | Test-DscConfigurationDocument -Quiet)) { throw 'invalid document' }&#10;
# Or pipe the document straight into the engine, no temp file:
$doc | ConvertTo-DscConfigurationDocument -Format Json | dsc config test -f -</code></pre><p><em>IntelliSense travels with the repo</em>. The RFC imagined scanning local resources at module import. But the review pointed out several problems. Adapter scans are slow, and your ubild agent doesn't have the target machine's resources anyway. So the prototype loads nothing at import. Instead, you generate a cache on a representative machine, check it into the repo, and every environment gets the same completions and warnings:</p><pre><code class="language-powershell"># On a machine representative of your targets:
Export-DscResourceCache            # writes ./.dscResourceCache.json&#10;
# Everywhere else (CI, other platforms) - picked up automatically, or explicitly:
Import-DscResourceCache -Path './.dscResourceCache.json'&#10;
New-DscResourceInstance -Type Microsoft.&lt;TAB&gt;   # completes from the cache
$r.Properties.&lt;TAB&gt;                              # property names from the cached schema</code></pre><p>If you have unknown resource types, it warns rather than errors. That can be because your cache may be stale, or the type may only exist on the target. </p><h2 id="where-your-voice-matters-most">Where your voice matters most</h2><p>Each section above (except Decision 7) ended with an open question. But there are also other undecided points that the RFC discusses (and where things still need to get settled):</p><ol><li><em>YAML</em>. Most real-world Microsoft DSC documents are <code>.dsc.config.yaml</code>. The prototype exports JSON only, with YAML deliberately marked in the code but unbuilt. Is a dependency on a YAML module worth adding as support, or can it simply be documented?</li><li><em>Operator semantics</em>. Document the <code>-eq</code> case-sensitivity divergence, or emit case-normalizing expressions? (Decision 5.)</li><li><em>Copy loops</em>. The engine marked them as deprecated. The prototype includes it with <code>New-DscCopy</code>, but warns and points you to a build-time <code>foreach</code> instead. Should the cmdlet exists at all?</li><li><em>The DSC alternative</em>. The RFC lists a Pester-like <code>DscConfiguration { Resource ... }</code> syntax as an alternative proposal. Should that be layered on top of this object model later, or is the imperative surface enough?</li><li><em>Naming</em>. The prototype uses <code>New-DscResourceInstance</code> (declaring an instance in a document) with <code>New-DscResource</code> as an alias, because the latter historically means "scaffold a new resource." Did the muscle-memory argument get it right?</li></ol><p>If you take one action after reading this post: pick the question that touches your real configurations, and answer it in the RFC discussion on the PowerShell/DSC repository. I think the most valuable feedback sits mainly in "here is my scenario, and here is where this design would fight me."</p><h2 id="the-document-is-declarative-but-the-design-doesnt-have-to-be">The document is declarative, but the design doesn't have to be</h2><p>Every decision in this prototype comes back to one belief. PowerShell authors shouldn'thave to choose between the language they know and the engine they're targeting. PlainPowerShell runs when your script runs. A scriptblock is a promise the engine keeps later. Everything in between, like schema URIs, casing, escaping, and validation, is the module's problem rather than yours. That's the design on the table today. It isn't shipped, and it isn't final. It's on the table.</p><p>That part is worth repeating. <em>None of this is released.</em> There is no Gallery package to install, and any cmdlet name or behavior in this post may look different by the time one exists. That's on purpose. The review process this post feeds is meant to change things. The prototype exists so the RFC discussion can argue about something concrete instead of something imagined.</p><p>Which is where you come in. Maybe <code>$dsc</code> is the wrong name. Maybe hiding the wire format is a mistake. Maybe your configurations lean on YAML, or on a pattern none of these examples cover. That gap is exactly the feedback the working group can't come up with on its own. Take your gnarliest real-world configuration, walk it through the decisions above, and tell us where the design would fight you.</p>
