---
title: "I documented Oh My Posh's DSC support and your terminal configuration just got way easier"
status: published
featured: true
tags: ["Microsoft Desired State Configuration v3"]
published_at: "2025-11-07T04:59:59.000Z"
custom_excerpt: "Stop manually configuring your prompt. Start automating it and store it in version control"
feature_image: "images/cover.jpg"
---

<p>I've been using Oh My Posh for nearly a year now. Custom themes. Tweaked a bunch of segments. Perfected my colors—everything exactly how I wanted it.</p><p>And then I got a new machine and started over again.</p><p>After doing this for <a href="/i-automated-my-entire-powertoys-setup-and-you-can-too/">PowerToys</a> (where I documented Microsoft DSC support), I looked at Oh My Posh and thought: this needs the same treatment. All these configurations with all these settings. All are manually synchronized across my machines. There had to be a better approach.</p><p>So I wrote the documentation for Oh My Posh's DSC capabilities. And honestly? It changed how I think about my terminal configuration.</p><p>No more manual theme copying. No more editing profile files by hand. No more "wait, which settings did I use on my desktop?"<br><br>Just configuration as code. Define it once. Deploy it everywhere. Exactly how it should be.<br><br>If you're tired of manually configuring your prompt every time you touch a new machine, this is the solution you didn't know existed.</p><h2 id="the-real-problem-isnt-configuration">The real problem isn't configuration</h2><p>Oh My Posh gives you incredible control. That's its strength. But it's also the source of the pain.</p><p>Look at what you can configure:</p><ul><li>Themes and color schemes.</li><li>Individual segment behavior and styling.</li><li>Font choices and rendering.</li><li>Shell-specific initialization.</li><li>Transient prompt behavior</li><li>And dozens more settings buried in JSON files</li></ul><p>For one machine? Manageable. For three machines? Tedious. For all your colleagues who think you've got the best terminal? A nightmare.</p><p>The manual approach kills your momentum. You spend time clicking through menus instead of actually using your beautifully configured terminal. And the worst part? Two months later, you can't remember exactly what you did.<br><br>I kept thinking: <em>there has to be a better way</em>.</p><h2 id="what-dsc-actually-does-and-why-you-should-care">What DSC actually does (and why you should care)</h2><p>Desired State Configuration isn't new. Microsoft introduced it from PowerShell's early beginnings. But what Oh My Posh did recently changes the game for terminal configuration.</p><p>Here's what makes it powerful: you describe what you want, not how to get there.</p><p>Instead of: "Click here, then here, paste this, run that command, hope you didn't miss a step..."</p><p>You write: "This is my theme. This is my shell setup. This is what I want."</p><p>Then you tell Oh My Posh to make it happen. On any machine. Anytime. Consistently.</p><p>Three DSC resources handle everything:</p><ol><li><strong>Config </strong>manages your theme files.</li><li><strong>Shell </strong>handles shell initialization.</li><li><strong>Font </strong>tracks your installed Nerd fonts.</li></ol><p>The beauty? These resources work through simple CLI commands. No external dependencies. No complex frameworks. Just oh-my-posh with a few extra flags.</p><h2 id="your-first-automated-powershell-prompt">Your first automated PowerShell prompt</h2><p>Let me show you what this looks like in practice. We'll focus on PowerShell since that's where most Windows developers live.</p><p>The DSC system tracks configurations you explicitly tell it to manage. If you're already using Oh My Posh (via <code>oh-my-posh init pwsh --config &lt;path&gt;</code>), DSC won't know about it until you register your configuration.<br><br>Here's how to capture your existing setup. First, check what DSC currently knows:</p><pre><code class="language-powershell">oh-my-posh config dsc get</code></pre><p>If you get an empty result or just a schema, that's normal—DSC hasn't tracked anything yet.</p><p>To register your current theme, you need to tell DSC where your config file is. Let's start with a built-in theme:</p><pre><code class="language-powershell">$themePath = Join-Path $env:POSH_THEMES_PATH "jandedobbeleer.omp.json"
$config = @{
    states = @(
        @{
            source = $themePath
            format = "json"
        }
    )
}
$state = $config | ConvertTo-Json -Compress
oh-my-posh config dsc set --state $state</code></pre><p>This uses the <code>jandedobbeleer</code> theme that ships with Oh My Posh. You can replace it with any built-in themelike <code>atomic.omp.json</code>, <code>catppuccin.omp.json</code>, or point to your own custom theme file at <code>~/.mytheme.omp.json</code>.</p><p>Now, when you run <code>oh-my-posh config dsc get</code>, you'll see your full theme configuration:</p><pre><code class="language-json">{
  "states": [
    {
      "format": "json",
      "source": "C:\\Users\\&lt;userName&gt;\\AppData\\Local\\Programs\\oh-my-posh\\themes\\jandedobbeleer.omp.json",
      "upgrade": {
        "source": "cdn",
        "interval": "168h",
        "auto": false,
        "notice": false
      },
      "version": 3
    }
  ]
}</code></pre><p>Simple, right? This is your configuration state, fully captured and exportable.<br><br>Now comes the magic part. Save that output to a file:</p><pre><code class="language-powershell">oh-my-posh config dsc get | Out-File my-prompt.json</code></pre><p>On any new machine, apply your saved configuration:</p><pre><code class="language-powershell">oh-my-posh config dsc set --state (Get-Content my-prompt.json -Raw)</code></pre><p>DSC reads the config, writes the theme file to the correct location, and tracks it for future updates.</p><h2 id="the-shell-setup-that-actually-works">The shell setup that actually works</h2><p>But having a theme file isn't enough. Your PowerShell profile needs to initialize Oh My Posh. This is where most guides leave you hanging with "just add this line to your profile."</p><p>DSC handles this automatically.</p><p>Check your current shell configuration:</p><pre><code class="language-powershell">oh-my-posh shell dsc get</code></pre><p>If Oh My Posh is already initialized, you'll see:</p><pre><code class="language-json">{"$schema":"https://ohmyposh.dev/dsc.shell.schema.json","states":[{"command":"oh-my-posh init pwsh","name":"pwsh"}]}</code></pre><p>To set it up from scratch on a new machine using a different theme:</p><pre><code class="language-powershell">$themePath = Join-Path $env:POSH_THEMES_PATH "atomic.omp.json"
$shell = @{
    states = @(
        @{
            name = "pwsh"
            command = "oh-my-posh init pwsh --config $themePath"
        }
    )
}
$state = $shell | ConvertTo-Json -Compress
oh-my-posh shell dsc set --state $state</code></pre><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">⚠️</div><div class="kg-callout-text">DSC writes the configuration files, but doesn't reload your shell. Restart your terminal to see the changes take effect.</div></div><p></p><p>What just happened? Oh My Posh:</p><ol><li>Found your PowerShell profile file</li><li>Added (or updated) the initialization command</li><li>Configured the shell-specific syntax (Invoke-Expression for PowerShell)</li><li>Left everything else in your profile untouched</li></ol><p>No manual editing. No risk of breaking your profile. No copy-paste errors.</p><h2 id="the-complete-configuration-workflow">The complete configuration workflow</h2><p>Here's how I set up a new machine now. Three commands. Two minutes.</p><p><strong>Step 1: Install Oh My Posh</strong></p><pre><code class="language-powershell">winget install JanDeDobbeleer.OhMyPosh</code></pre><p><strong>Step 2: Apply your theme</strong></p><pre><code class="language-powershell">$config = @{
    states = @(
        @{
            source = "~/.config/omp/my-theme.omp.json"
            format = "json"
        }
    )
}
oh-my-posh config dsc set --state ($config | ConvertTo-Json -Compress)</code></pre><p><strong>Step 3: Initialize PowerShell</strong></p><pre><code class="language-powershell">$shell = @{
    states = @(
        @{
            name = "pwsh"
            command = "oh-my-posh init pwsh --config ~/.config/omp/my-theme.omp.json"
        }
    )
}
oh-my-posh shell dsc set --state ($shell | ConvertTo-Json -Compress)</code></pre><p><strong>Step 4: Restart your terminal</strong></p><p>The DSC commands write configuration files and update your profile, but don't reload the active shell. Close and reopen PowerShell to see your new prompt in action.</p><p>The difference isn't just time saved. It's the consistency that's guaranteed. You can save these commands to a PowerShell script or use WinGet as an orchestrator.</p><p>Before DSC, I'd hesitate to update Oh My Posh. What if the new version broke my carefully configured prompt? What if I couldn't reproduce my setup?</p><p>Now? Update fearlessly. Your configuration is captured. If something breaks, restore it in seconds:</p><pre><code class="language-powershell">oh-my-posh config dsc set --state (Get-Content backup.json -Raw)</code></pre><h2 id="your-next-move">Your next move</h2><p>If you're still manually configuring Oh My Posh across machines, stop. You're working too hard.</p><p>Start with just PowerShell. Export your current config:</p><pre><code class="language-powershell">oh-my-posh config dsc get | Out-File ~/omp-config.json
oh-my-posh shell dsc get | Out-File ~/omp-shell.json</code></pre><p>Store those files somewhere safe, whether it is GitHub, OneDrive, or Dropbox.</p><p>Next time you set up a new machine, use those files. Watch how fast it becomes. Feel the relief of knowing your configuration is captured, not lost in your memory.</p><p>Want to dive deeper? Check out the <a href="https://ohmyposh.dev/docs/dsc">Oh My Posh DSC documentation</a> for advanced configuration techniques, WinGet integration, and multi-shell setup.</p>
