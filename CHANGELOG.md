# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ✨ New Features
- **text_search tool**: Fast text search with ripgrep support
  - Uses ripgrep (rg) if available for blazing-fast searches
  - Falls back to vimgrep automatically
  - Supports exact string and regex patterns with alternation (`function|method|procedure`)
  - File filtering with glob patterns or absolute paths
  - Matches VS Code Copilot Chat behavior
  - Added 6 comprehensive unit tests (32 total tests, 100% pass rate)

### ⚠️ Breaking Changes
- **read_file tool**: `start_line` and `end_line` are now required parameters (previously optional)
  - Aligns with VS Code Copilot Chat behavior
  - Prevents accidental large file reads
  - Better token efficiency for LLM context
  - Response now includes navigation hints: `has_more_before`, `has_more_after`

## [0.1.0] - 2025-10-28

### 🎉 Initial Release

First public release of nvim-agent - AI assistant for Neovim with GitHub Copilot support.

### ✨ Features

#### Core Functionality
- **Interactive AI Chat** - Floating chat window with full conversation history
- **Three Operating Modes:**
  - `ask` - Ask questions and get answers
  - `edit` - Request code changes with inline buttons (Accept/Discard)
  - `agent` - Autonomous mode with tool execution
- **Multi-Session Support** - Create, switch, rename, and manage multiple chat sessions
- **Auto-attach File Context** - Automatically includes active file in conversation

#### AI Provider Support
- **GitHub Copilot** (recommended) - Full support including tools/function calling ⚡
- **OpenAI** - GPT-4, GPT-3.5-turbo support
- **Anthropic** - Claude models support
- **Local APIs** - Compatible with Ollama and other OpenAI-compatible endpoints
- **Mock Provider** - For testing without API access

#### Agent Mode (MCP Tools)
28 built-in tools for code analysis and manipulation:

**File Operations:**
- `read_file` - Read file contents with line range support
- `write_file` - Write content to files
- `list_directory` - Browse directory structure
- `get_project_structure` - Generate full project tree

**Search & Analysis:**
- `grep_search` - Pattern search across files
- `semantic_search` - AI-powered semantic code search
- `list_code_definition_names` - List symbols in file
- `file_search` - Find files by glob pattern

**Code Intelligence:**
- `get_diagnostics` - Get LSP diagnostics and errors
- `get_references` - Find all symbol references
- `get_definition` - Go to definition
- `get_type_definition` - Go to type definition
- `get_implementation` - Find implementations

**Git Integration:**
- `git_diff` - View working directory changes
- `git_status` - Check repository status
- `git_log` - View commit history
- `git_show` - Show commit details

**Editor Actions:**
- `get_open_buffers` - List open files
- `get_cursor_position` - Current cursor location
- `set_cursor_position` - Move cursor
- `get_selection` - Get visual selection

**System Operations:**
- `run_command` - Execute shell commands
- `get_environment_info` - System information

And more tools for comprehensive code manipulation!

#### UI Features
- **Visual Feedback** - Real-time tool execution status with icons (🔧 📝 ✅ ❌)
- **Inline Buttons** - Accept/Discard changes directly in chat (like VS Code Copilot)
  - `Enter` or `ga` - Accept changes
  - `gd` - Discard changes
  - `gA` - Accept all
  - `gD` - Discard all
- **Review Mode** - Interactive change review with diff view
- **Customizable UI** - Configurable window size, position, borders, colors
- **Help System** - Built-in `:help nvim-agent` documentation

#### Commands
- `:NvimAgentChat` - Toggle chat window
- `:NvimAgentNewChat [name]` - Create new session
- `:NvimAgentListChats` - List and switch sessions
- `:NvimAgentDeleteChat` - Delete current session
- `:NvimAgentRenameChat <name>` - Rename session
- `:NvimAgentMode <mode>` - Change mode (ask/edit/agent)
- `:NvimAgentClear` - Clear chat history
- `:NvimAgentExplain` - Explain selected code
- `:NvimAgentReview` - Review code changes
- `:NvimAgentToggleDebug` - Toggle debug logging
- `:NvimAgentAttachFile` - Manually attach current file to context

#### Default Keybindings
- `<leader>aa` - Toggle chat
- `<leader>ac` - Clear chat
- `<leader>am` - Change mode
- `<leader>an` - New session
- `<leader>al` - List sessions
- `<leader>ae` - Explain code (visual mode)
- `<leader>ar` - Review mode

### 🧪 Testing
- **Professional Test Infrastructure** with plenary.nvim
- **26 Unit Tests** covering all major functionality:
  - Config management (3 tests)
  - Copilot API integration (3 tests)
  - MCP tools system (5 tests)
  - Session management (13 tests)
  - Basic functionality (2 tests)
- **100% Test Pass Rate**
- **CI/CD Ready** with GitHub Actions
- Cross-platform testing (Ubuntu, Windows, macOS)

### 📚 Documentation
- Comprehensive README with quick start guide
- Detailed MCP tools reference
- Command reference and cheatsheet
- Examples and configuration guide
- Contributing guidelines
- Multiple tutorials and guides

### 🏗️ Project Structure
```
nvim-agent/
├── lua/nvim-agent/      # Core plugin code
│   ├── api/             # AI provider integrations
│   ├── ui/              # User interface components
│   ├── chat.lua         # Chat management
│   ├── mcp.lua          # MCP tools implementation
│   └── config.lua       # Configuration
├── plugin/              # Plugin initialization
├── doc/                 # Neovim help docs
├── tests/               # Unit tests (plenary.nvim)
├── docs/                # Markdown documentation
├── examples/            # Configuration examples
└── scripts/             # Development scripts
```

### 🔧 Technical Details
- **Language:** Lua 5.1+
- **Dependencies:** 
  - Neovim 0.8.0+
  - curl (for API requests)
  - git (for Git tools)
- **Test Framework:** plenary.nvim
- **Architecture:** Modular with clean separation of concerns
- **API Design:** OpenAI-compatible for easy provider switching

### 🎯 Highlights
- **First Neovim plugin** with full GitHub Copilot tools/function calling support
- **Zero global pollution** - all dependencies in local `deps/` folder
- **Smart file handling** - Automatic chunking for large files
- **Token optimization** - Efficient context management
- **Production ready** - Comprehensive error handling and logging

### 📝 Notes
- GitHub Copilot requires authentication via `gh` CLI or VS Code
- Some tools require LSP to be configured
- Git tools require working directory to be a git repository
- Agent mode works best with GPT-4 or Claude models

### 🙏 Acknowledgments
- Inspired by GitHub Copilot Chat for VS Code
- Built for the Neovim community
- Uses Model Context Protocol (MCP) for tool standardization

[Unreleased]: https://github.com/your-username/nvim-agent/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/your-username/nvim-agent/releases/tag/v0.1.0
