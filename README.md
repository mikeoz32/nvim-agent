# nvim-agent

🤖 Powerful AI assistant for Neovim, replicating GitHub Copilot Chat functionality

## ✨ What's New

**🎉 Agent Mode with GitHub Copilot!** - Now you can use all 28 MCP tools with the GitHub Copilot API! Just sign in to GitHub Copilot (VSCode or `gh copilot`) and everything works automatically.

## 🚀 Features

- **💬 Interactive Chat** - Talk to AI directly in Neovim
- **🎯 Three Modes** - Ask (questions), Edit (code editing), Agent (autonomous tool usage)
- **🧠 Multiple AI Providers** - OpenAI, Anthropic, **GitHub Copilot** ✨, local APIs
- **🤖 Agent Mode with GitHub Copilot** - **First Neovim plugin with Copilot tools support!** ⚡
- **🔧 MCP (Model Context Protocol)** - 28 tools for actions (read files, code search, run commands)
- **👁️ Visual Feedback** - See all agent actions with icons like in VS Code
- **🎯 Review Mode** - Interactive review and control of changes (Accept/Discard like VS Code Copilot)
- **📝 Inline Buttons** - Accept/Discard buttons directly in chat (Enter/ga/gd like Copilot)
- **📝 Context Awareness** - AI understands your code and project
- **⚡ Quick Commands** - Explain, generate, refactor code with one click
- **🎨 Flexible Customization** - Fully customizable UI and behavior
- **📚 Automatic Documentation** - Generate docs and tests
- **💾 Chat History** - Save and restore conversations

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'your-username/nvim-agent',
    config = function()
        require('nvim-agent').setup({
            api = {
                provider = "openai",
                model = "gpt-4",
                api_key = os.getenv("OPENAI_API_KEY"),
            }
        })
    end,
    keys = {
        { "<leader>cc", "<cmd>NvimAgentChat<cr>", desc = "Toggle AI Chat" },
        { "<leader>ce", "<cmd>NvimAgentExplain<cr>", mode = "v", desc = "Explain Code" },
        { "<leader>cg", "<cmd>NvimAgentGenerate<cr>", desc = "Generate Code" },
    }
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'your-username/nvim-agent',
    config = function()
        require('nvim-agent').setup()
    end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'your-username/nvim-agent'
```

Then add to your `init.lua`:

```lua
require('nvim-agent').setup()
```

## ⚙️ Configuration

### � Optional Dependencies

For an enhanced experience with nvim-agent, you can install additional plugins:

- **[render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)** - Improved markdown rendering in chat
  - Renders bold text, italics, code blocks, headers
  - Automatically detected and applied if installed
  - Works without it too (basic concealing is used)

- **[ripgrep (rg)](https://github.com/BurntSushi/ripgrep)** - Fast file searching for `text_search` tool
  - Significantly faster than vimgrep
  - Automatically used if installed
  - Works without it too (fallback to vimgrep)

### �🚀 Quick Start with GitHub Copilot (Recommended)

**Agent Mode with full tool support works with GitHub Copilot!** 🎉

1. **Install GitHub CLI**:

```bash
# Windows (winget)
winget install GitHub.cli

# macOS
brew install gh

# Linux
# See instructions at https://github.com/cli/cli#installation
```

2. **Authenticate**:

```bash
gh auth login
```

3. **Configure nvim-agent**:

```lua
require('nvim-agent').setup({
    api = {
        provider = "github-copilot",  -- ✨ Use Copilot!
        model = "gpt-4o",              -- gpt-4o or gpt-4
    }
})
```

4. **Done!** The plugin will automatically find your Copilot token from:
   - Windows: `%LOCALAPPDATA%\github-copilot\apps.json`
   - macOS/Linux: `~/.config/github-copilot/apps.json`

**Benefits of GitHub Copilot**:
- ✅ Automatic authentication (token is saved after logging in to VSCode/CLI)
- ✅ **Full Agent Mode support** with all 28 MCP tools
- ✅ GPT-4o model included in Copilot Pro subscription
- ✅ No additional API keys required
- ✅ Works with Copilot Individual, Business, and Pro

### Alternative Providers

#### OpenAI

```lua
require('nvim-agent').setup({
    api = {
        provider = "openai",
        model = "gpt-4",
        api_key = os.getenv("OPENAI_API_KEY"),
    }
})
```

#### Anthropic

```lua
require('nvim-agent').setup({
    api = {
        provider = "anthropic",
        model = "claude-3-opus-20240229",
        api_key = os.getenv("ANTHROPIC_API_KEY"),
    }
})
```

### Basic Configuration

```lua
require('nvim-agent').setup({
    -- API settings
    api = {
        provider = "openai",  -- "openai", "anthropic", "local"
        model = "gpt-4",      -- Model to use
        api_key = nil,        -- API key (preferably use environment variables)
        timeout = 30000,      -- Timeout in milliseconds
        temperature = 0.7,    -- Creativity (0.0 - 2.0)
    },
    
    -- UI settings
    ui = {
        chat = {
            width = 50,           -- Width in percent
            height = 80,          -- Height in percent
            position = "right",   -- "right", "left", "bottom", "float"
            border = "rounded",   -- Border style
        }
    },
    
    -- Hotkeys
    keymaps = {
        toggle_chat = "<leader>cc",
        explain_code = "<leader>ce",
        generate_code = "<leader>cg",
        refactor_code = "<leader>cr",
    }
})
```

### Environment Variables

Set one of the API keys in your environment variables:

```bash
export OPENAI_API_KEY="your-openai-api-key"
# or
export ANTHROPIC_API_KEY="your-anthropic-api-key"
# or for GitHub Copilot
export GITHUB_TOKEN="your-github-token"
# or
export NVIM_AGENT_API_KEY="your-custom-api-key"
```

### GitHub Copilot

To use with GitHub Copilot:

1. **Install GitHub CLI**:
```bash
# macOS
brew install gh

# Ubuntu/Debian  
sudo apt install gh

# Windows
winget install GitHub.CLI
```

2. **Authenticate**:
```bash
gh auth login
```

3. **Configure nvim-agent**:
```lua
require('nvim-agent').setup({
    api = {
        provider = "github-copilot",
        model = "gpt-4", -- or other available model
    }
})
```

### Local AI Server

To use with Ollama or other local AI servers:

```lua
require('nvim-agent').setup({
    api = {
        provider = "local",
        base_url = "http://localhost:11434/v1", -- Ollama URL
        model = "llama2", -- Local model
        api_key = nil, -- Not needed for local servers
    }
})
```

## 🎯 Usage

### Operating Modes

nvim-agent supports three operating modes, similar to GitHub Copilot Chat:

#### 💬 Ask (Questions) - Default Mode
- AI answers questions and provides explanations
- Does not make code changes automatically
- Ideal for learning and consulting

#### ✏️ Edit (Code Editing)
- AI suggests code changes
- Changes can be applied immediately
- Focus on improving existing code

#### 🤖 Agent (Autonomous)
- AI can perform tasks independently
- Can create files, modify code, execute commands
- Most powerful mode for complex tasks

**Switching modes:**
- Press `<leader>cm` to cycle through modes
- Or in chat, press `<Ctrl+M>`
- Or use the command `:NvimAgentMode [ask|edit|agent]`

### Commands

| Command | Description | Mode |
|---------|-------------|-------|
| `:NvimAgentChat` | Open/close chat | Normal |
| `:NvimAgentExplain` | Explain selected code | Visual |
| `:NvimAgentGenerate [description]` | Generate code | Normal |
| `:NvimAgentRefactor` | Improve code | Visual |
| `:NvimAgentTest` | Create tests | Visual |
| `:NvimAgentDoc` | Generate documentation | Visual |
| `:NvimAgentReview` | Code review | Visual |
| `:NvimAgentFix` | Fix errors | Visual |
| `:NvimAgentClear` | Clear chat | Normal |
| `:NvimAgentExport [format]` | Export chat | Normal |
| `:NvimAgentStats` | Show statistics | Normal |
| `:NvimAgentMode [mode]` | Set/show mode | Normal |
| `:NvimAgentModeHelp` | Mode help | Normal |
| `:NvimAgentProvider [provider]` | Change AI provider | Normal |
| `:NvimAgentModel [model]` | Set/show model | Normal |
| `:NvimAgentSelectModel` | 🎨 Interactive model selection | Normal |
| `:NvimAgentCopilot [action]` | Manage GitHub Copilot | Normal |

**New!** `:NvimAgentSelectModel` - beautiful interactive selection of all available GitHub Copilot models (24+ models!)

### Hotkeys (default)

- `<leader>cc` - Open/close chat
- `<leader>cm` - Switch mode (Ask/Edit/Agent)
- `<leader>ce` - Explain selected code
- `<leader>cg` - Generate code
- `<leader>cr` - Refactor code
- `<leader>ct` - Create tests
- `<leader>cd` - Generate documentation

### In Chat

- `<Enter>` - Send message
- `<Shift+Enter>` - New line
- `<Ctrl+M>` - Switch mode
- `<Ctrl+L>` - Clear chat
- `<Esc>` - Close chat
- `<Ctrl+I>` - Focus on input field

## 📝 Usage Examples

### 1. Explaining Code

Select a complex code fragment and press `<leader>ce`:

```lua
-- Select this code and press <leader>ce
local function quicksort(arr, low, high)
    if low < high then
        local pi = partition(arr, low, high)
        quicksort(arr, low, pi - 1)
        quicksort(arr, pi + 1, high)
    end
end
```

### 2. Code Generation

Press `<leader>cg` and describe what you need:
```
"Create a function to validate email addresses in Lua"
```

### 3. Refactoring

Select code that needs improvement and press `<leader>cr`:

```lua
-- Old code
function bad_function(a,b,c)
local x=a+b
if x>c then return true else return false end
end
```

### 4. Test Creation

Select a function and press `<leader>ct` for automatic test generation.

## 🔧 Advanced Settings

### Custom Prompts

```lua
require('nvim-agent').setup({
    prompts = {
        explain = "Explain this code in detail and how it can be improved:",
        generate = "Create high-quality code with comments:",
        refactor = "Optimize this code for better performance:",
        -- ... other prompts
    }
})
```

### UI Customization

```lua
require('nvim-agent').setup({
    ui = {
        chat = {
            width = 60,
            height = 90,
            position = "float", -- Floating window
            border = "double",
            title = "🤖 AI Assistant",
        },
        highlights = {
            chat_border = "FloatBorder",
            user_message = "Comment",
            ai_message = "Normal",
        }
    }
})
```

### Behavior Settings

```lua
require('nvim-agent').setup({
    behavior = {
        auto_save_chat = true,
        include_file_context = true,
        context_lines = 30,
        max_context_files = 10,
    }
})
```

### MCP (Model Context Protocol) Settings

MCP allows AI to use tools to interact with Neovim:

```lua
require('nvim-agent').setup({
    mcp = {
        enabled = true,  -- Enable MCP (default true)
        
        -- Basic Neovim tools always available:
        -- - read_file - read files
        -- - write_file - write files
        -- - find_files - find files
        -- - grep_search - search text in files
        -- - execute_command - execute Neovim commands
        -- - execute_shell - execute shell commands
        -- - list_buffers - list buffers
        -- - get_diagnostics - get LSP diagnostics
        
        -- External MCP servers (optional)
        servers = {
            {
                name = "filesystem",
                command = "mcp-server-filesystem",
                args = {vim.fn.getcwd()},
            },
            {
                name = "git",
                command = "mcp-server-git",
                args = {},
            }
        }
    }
})
```

#### Example of using MCP in Agent mode

```
User: "Find all functions named 'process' and fix errors in them"

AI (using tools):
1. 🔧 Performing grep_search to find functions
2. 🔧 Performing read_file to read each file
3. 🔧 Performing get_diagnostics to check for errors
4. 🔧 Performing write_file to save fixes
✅ Found 5 functions, fixed 3 errors
```

### 🎯 Automatic Project Context

**New feature!** AI can automatically load the entire project into context:

```
User: "Add dark theme support"

AI (in Agent mode):
🔧 get_project_context()
   ✅ Loaded 42 files (1.8MB)
   📊 Project: React + TypeScript
   📦 Components: Header, Footer, Sidebar
   🎨 Styles: CSS modules
   
Analysis:
- Found theme provider in App.tsx
- CSS variables in styles/variables.css
- Components use inline styles
   
Plan:
1. Create theme context
2. Add theme switcher
3. Update all components
4. Add saving selection to localStorage

Start implementation?
```

### 👁️ Visual Feedback

**Like in VS Code!** See all agent actions in real-time with icons:

```
🤖 Performing 4 tools...

  🔎 Searching text: "TODO"
  ✅ Found 15 matches

  🔍 Checking for errors
  ✅ Found 3 issues

  📖 Reading file: utils.lua, lines 45-67
  ✅ Read 22 lines

  💾 Writing file: utils.lua
  ✅ File saved

  💭 Analyzing results...
```

**28 icons** for different operations (📖📦🔍✏️💾⚡🌲 etc.)

Detailed documentation: [docs/VISUAL_FEEDBACK.md](docs/VISUAL_FEEDBACK.md)

### 🎯 Review Mode - Change Control

**Like Accept/Discard in VS Code!** Review and control every change:

```vim
" 1. Enable review mode
:NvimAgentReviewMode on

" 2. Ask AI to make changes
:NvimAgentChat
> Add error handling to all functions

" 3. Review changes
:NvimAgentReviewChanges
```

**Interactive diff window:**
```diff
=== Changes in file: src/app.js ===

  import express from 'express';
+ import { validateEmail } from './validators.js';
  
  app.post('/signup', (req, res) => {
-   // TODO: validate email
+   if (!validateEmail(req.body.email)) {
+     return res.status(400).json({ error: 'Invalid email' });
+   }
  });

[a]ccept  [d]iscard  [A]ccept All  [D]iscard All  [n]ext  [p]rev  [q]uit
```

**Features:**
- ✅ Accept/Discard individual changes
- ✅ Accept/Discard all changes
- ✅ Navigate between changes (n/p)
- ✅ Diff preview with syntax highlighting
- ✅ Automatic backup/restore
- ✅ Change statistics

Detailed documentation: [docs/REVIEW_MODE.md](docs/REVIEW_MODE.md)

### 🔘 Inline Buttons - Like Copilot!

**Inline buttons right in the chat!** When AI makes changes, buttons appear:

```
🤖 Performing 2 tools...

  💾 Writing file: src/app.lua
  ✅ File saved (waiting for review)

📋 There are 2 changes to review. Press Enter or ga to accept.

  [Accept (2)] [Discard (2)] [Accept All] [Discard All]  ← inline buttons!
```

**Hotkeys** (when cursor is on the line with buttons):
- `Enter` or `ga` - Accept changes
- `gd` - Discard changes
- `gA` - Accept All
- `gD` - Discard All
- `gp` - Open full Preview

**Colored buttons:**
- 🟢 Accept - green
- 🔴 Discard - red
- 🔵 Accept All - cyan
- 🟡 Discard All - orange

Detailed documentation: [docs/INLINE_BUTTONS.md](docs/INLINE_BUTTONS.md)

**Available tools:**
- `get_project_context` - loads the full project context (files + metadata)
- `get_project_structure` - quickly shows project structure
- 28 other tools for code manipulation

Detailed documentation: [docs/MCP_TOOLS.md](docs/MCP_TOOLS.md)

MCP tools are automatically available in **Agent mode**. In Ask and Edit modes, tools are not used.

## � Troubleshooting

### GitHub Copilot

#### Issue: "Copilot OAuth token not found"

**Solution:**

1. Make sure you are logged in to GitHub Copilot:

```bash
# Check status
gh auth status

# If not logged in
gh auth login
```

2. Check for the token file:

```bash
# Windows
dir %LOCALAPPDATA%\github-copilot\apps.json

# Linux/Mac
ls -la ~/.config/github-copilot/apps.json
```

3. If the file does not exist:
   - Open VSCode
   - Sign in to GitHub Copilot via Command Palette: `GitHub Copilot: Sign In`
   - Or run `gh copilot` in the terminal

4. Alternatively, set the token manually:

```bash
export GITHUB_COPILOT_TOKEN="your-copilot-oauth-token"
```

#### Issue: "Failed to get session token"

**Possible reasons:**
- Token expired
- No active Copilot subscription
- Network issues

**Solution:**

1. Check your subscription:
   - Open https://github.com/settings/copilot
   - Ensure the subscription is active

2. Refresh the token:

```bash
# Log out and log in again
gh auth logout
gh auth login

# Or in VSCode
# Command Palette → "GitHub Copilot: Sign Out" → "GitHub Copilot: Sign In"
```

3. Check the connection:

```vim
:lua require('nvim-agent.api.copilot').test_connection(function(ok, msg) print(ok and "✅ OK" or "❌ " .. msg) end)
```

#### Issue: "Tools not working in Agent mode"

**Check:**

1. Is Agent mode enabled?

```vim
:NvimAgentMode agent
```

2. Does the provider support tools?

```vim
:lua print(require('nvim-agent.api').supports_tools() and "✅ Tools supported" or "❌ Tools not supported")
```

3. Are you using the gpt-4o or gpt-4 model?

```lua
require('nvim-agent').setup({
    api = {
        provider = "github-copilot",
        model = "gpt-4o",  -- ✅ Supports tools
    }
})
```

### General Issues

#### Issue: API not responding

1. Check your internet connection
2. Check timeouts in the configuration:

```lua
require('nvim-agent').setup({
    api = {
        timeout = 60000,  -- Increase to 60 seconds
    }
})
```

3. Enable debug logs:

```lua
require('nvim-agent').setup({
    debug = {
        enabled = true,
        log_level = "debug",
    }
})
```

#### Issue: Slow performance

1. Decrease max_tokens:

```lua
require('nvim-agent').setup({
    api = {
        max_tokens = 1024,  -- Instead of 4096
    }
})
```

2. Use a faster model:

```lua
require('nvim-agent').setup({
    api = {
        model = "gpt-4o-mini",  -- Faster, cheaper
    }
})
```

## �🐛 Debugging

Enable debug mode:

```lua
require('nvim-agent').setup({
    debug = {
        enabled = true,
        log_level = "debug",
        log_file = vim.fn.stdpath("cache") .. "/nvim-agent.log",
    }
})
```

Check the logs:
```bash
tail -f ~/.cache/nvim/nvim-agent.log
```

Check API connection:
```vim
:NvimAgentTestConnection
```

## 🤝 Contributing

Welcome to contribute! Please:

1. Fork the repository
2. Create a branch for the new feature (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a Pull Request

### Development

```bash
# Clone the repository
git clone https://github.com/your-username/nvim-agent.git
cd nvim-agent

# Install dependencies for tests (in project in deps/)
./scripts/setup.sh  # Linux/macOS
# or
.\scripts\setup.ps1  # Windows

# Run tests
make test  # Linux/macOS
# or
.\test.ps1  # Windows

# Or a specific file
make test-file FILE=tests/nvim-agent/config_spec.lua
```

**Note**: plenary.nvim is installed locally in `deps/` and will not affect your global Neovim configuration.

For detailed testing instructions, see [tests/README.md](tests/README.md).

## 🧪 Testing

The project uses [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for unit tests.

```bash
# Run all tests
make test

# Run a specific test file
make test-file FILE=tests/nvim-agent/mcp_spec.lua

# Watch mode (requires entr)
make test-watch
```

Tests are automatically run in GitHub Actions on Ubuntu, Windows, and macOS.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [GitHub Copilot](https://github.com/features/copilot) for the inspiration
- [Neovim](https://neovim.io/) for the great editor
- The Neovim plugin development community

## 📞 Support

- 📋 [Report an issue](https://github.com/your-username/nvim-agent/issues)
- 💡 [Suggest a feature](https://github.com/your-username/nvim-agent/discussions)
- 📧 [Email](mailto:your-email@example.com)

---

**nvim-agent** - Your smart programming assistant in Neovim! 🚀