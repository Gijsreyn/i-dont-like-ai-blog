---
title: "Practicing and exploring"
status: published
tags: ["The fundamentals of Microsoft DSC"]
published_at: "2025-10-22T02:51:07.000Z"
custom_template: "custom-lesson"
---

<p>Time to test your knowledge and understanding by performing exercises and answering some questions. Get your hands dirty with the following exercises.</p>
<!--kg-card-begin: html-->
<!-- PRACTICE EXERCISES: Installing Microsoft DSC -->
<section class="practice-section">
    <div class="practice-exercises">
        <!-- Exercise 1 -->
        <article class="practice-exercise">
            <header class="practice-exercise-header">
                <div class="practice-exercise-title-wrapper">
                    <span class="practice-exercise-number">1</span>
                    <h3 class="practice-exercise-title">Verify your Microsoft DSC installation</h3>
                </div>
                <span class="practice-difficulty easy">
                    <span class="practice-difficulty-dot"></span>
                    Easy
                </span>
            </header>
            <p class="practice-exercise-description">
                Confirm that Microsoft DSC is properly installed and accessible from your command line, and document your system configuration.
            </p>
            <div class="practice-exercise-task">
                <span class="practice-task-label">Your Task</span>
                <div class="practice-task-content">
                    <p>Complete the following verification steps:</p>
                    <ul>
                        <li>Run <code>dsc --version</code> and record the version number</li>
                        <li>Run each DSC command and name the available options (except for <code>--version</code> and <code>--help</code>)</li>
                        <li>List out the available DSC functions and count how many are available</li>
                        <li>Document your OS, architecture, and edition using a DSC resource</li>
                    </ul>
                </div>
            </div>
            <div class="practice-tips">
                <div class="practice-tips-title">
                    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="12" cy="12" r="10"/>
                        <path d="M12 16v-4M12 8h.01"/>
                    </svg>
                    Hints
                </div>
                <div class="practice-tips-content">
                    <ul>
                        <li>If the command is not found, check your PATH environment variable</li>
                        <li>On Windows, you may need to restart your terminal after adding to PATH</li>
                    </ul>
                </div>
            </div>
            <div class="practice-exercise-links">
                <a href="https://github.com/Gijsreyn/idontlikeai/tree/main/courses/the-fundamentals-of-microsoft-dsc/getting-started/instructions/01-verify-installation.md" class="practice-link" target="_blank" rel="noopener">
                    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6z"/>
                        <path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/>
                    </svg>
                    View instructions
                </a>
                <a href="https://github.com/Gijsreyn/idontlikeai/tree/main/courses/the-fundamentals-of-microsoft-dsc/getting-started/answers/01-verify-installation-solution.md" class="practice-link secondary" target="_blank" rel="noopener">
                    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path d="M9 11l3 3L22 4"/>
                        <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
                    </svg>
                    View solution
                </a>
            </div>
        </article>
        <!-- Exercise 2 -->
        <article class="practice-exercise">
            <header class="practice-exercise-header">
                <div class="practice-exercise-title-wrapper">
                    <span class="practice-exercise-number">2</span>
                    <h3 class="practice-exercise-title">Create registry management script</h3>
                </div>
                <span class="practice-difficulty medium">
                    <span class="practice-difficulty-dot"></span>
                    Medium
                </span>
            </header>
            <p class="practice-exercise-description">
                Build a PowerShell script that manages registry keys using the <code>Microsoft.Windows/Registry</code> resource with full CRUD operations and driven behavior using parameters.
            </p>
            <div class="practice-exercise-task">
                <span class="practice-task-label">Your Task</span>
                <div class="practice-task-content">
                    <p>Create a PowerShell script that:</p>
                    <ul>
                        <li>Accepts parameters for operation type (<code>get</code>, <code>set</code>, <code>test</code>, <code>delete</code>)</li>
                        <li>Creates a registry key with <code>_exist = $true</code> when using <code>set</code></li>
                        <li>Implements <code>get</code> operation to retrieve current registry key state</li>
                        <li>Implements <code>test</code> operation to verify if key exists and matches desired state</li>
                        <li>Implements <code>delete</code> operation when <code>_exist = $false</code> is specified</li>
                        <li>Uses the <code>Microsoft.Windows/Registry</code> DSC resource</li>
                        <li>Includes error handling and validation</li>
                        <li>Provides clear output showing the operation result in PowerShell objects</li>
                    </ul>
                </div>
            </div>
            <div class="practice-tips">
                <div class="practice-tips-title">
                    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="12" cy="12" r="10"/>
                        <path d="M12 16v-4M12 8h.01"/>
                    </svg>
                    Hints
                </div>
                <div class="practice-tips-content">
                    <ul>
                        <li>Use a <code>[ValidateSet]</code> attribute for the operation parameter</li>
                        <li>Build the JSON input dynamically based on the operation</li>
                        <li>Use <code>ConvertFrom-Json</code> to parse DSC output for better handling</li>
                        <li>Remember: <code>delete</code> requires setting <code>_exist</code> to false in the input</li>
                        <li>Test your script with HKCU hive to avoid needing admin privileges</li>
                    </ul>
                </div>
            </div>
            <div class="practice-exercise-links">
                <a href="https://github.com/Gijsreyn/idontlikeai/tree/main/courses/the-fundamentals-of-microsoft-dsc/getting-started/instructions/02-registry-management-script.md" class="practice-link" target="_blank" rel="noopener">
                    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6z"/>
                        <path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/>
                    </svg>
                    View instructions
                </a>
                <a href="https://github.com/Gijsreyn/idontlikeai/tree/main/courses/the-fundamentals-of-microsoft-dsc/getting-started/answers/02-registry-management-script-solution.ps1" class="practice-link secondary" target="_blank" rel="noopener">
                    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path d="M9 11l3 3L22 4"/>
                        <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
                    </svg>
                    View solution
                </a>
            </div>
        </article>
        <!-- Question 3 -->
        <article class="practice-exercise">
            <header class="practice-exercise-header">
                <div class="practice-exercise-title-wrapper">
                    <span class="practice-exercise-number">3</span>
                    <h3 class="practice-exercise-title">Knowledge check</h3>
                </div>
                <span class="practice-difficulty easy">
                    <span class="practice-difficulty-dot"></span>
                    Easy
                </span>
            </header>
            <p class="practice-exercise-description">
                Test your understanding of core Microsoft DSC concepts, architecture, and how it differs from traditional configuration management tools.
            </p>
            <div class="practice-exercise-task">
                <span class="practice-task-label">Questions</span>
                <div class="practice-task-content">
                    <ol>
                        <li>What does DSC stand for, and what problem does it solve in configuration management?</li>
                        <li>How does DSC differ from imperative configuration tools?</li>
                        <li>What does it mean when we say DSC is idempotent?</li>
                        <li>What's the role of a DSC Resource?</li>
                        <li>How do DSC configuration documents describe the desired state of a system?</li>
                        <li>What are the main operations supported by DSC resources?</li>
                        <li>How is DSC different from PowerShell DSC in terms of dependencies and architecture?</li>
                        <li>What formats can DSC configuration documents be written in?</li>
                        <li>Why doesn't the new DSC include a Local Configuration Manager?</li>
                    </ol>
                </div>
            </div>
            <div class="practice-exercise-links">
                <a href="https://github.com/Gijsreyn/idontlikeai/tree/main/courses/the-fundamentals-of-microsoft-dsc/getting-started/answers/03-knowledge-check-solution.md" class="practice-link" target="_blank" rel="noopener">
                    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path d="M9 11l3 3L22 4"/>
                        <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
                    </svg>
                    View answers
                </a>
            </div>
        </article>
    </div>
    <!-- Related Resources -->
    <div class="practice-resources">
        <h3 class="practice-resources-title">
            Related resources
        </h3>
        <div class="practice-resources-list">
            <a href="https://github.com/PowerShell/DSC/releases" class="practice-resource-link" target="_blank" rel="noopener">
                <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
                    <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
                </svg>
                <span>DSC releases on GitHub</span>
                <svg class="external-icon" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6M15 3h6v6M10 14L21 3"/>
                </svg>
            </a>
            <a href="https://www.powershellgallery.com/packages/PSDSC" class="practice-resource-link" target="_blank" rel="noopener">
                <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
                    <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
                </svg>
                <span>PSDSC module</span>
                <svg class="external-icon" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6M15 3h6v6M10 14L21 3"/>
                </svg>
            </a>
        </div>
    </div>
</section>
<!--kg-card-end: html-->
