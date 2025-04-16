local mapping_key_prefix = vim.g.ai_prefix_key or '<leader>a'
local IS_DEV = false

-- This is custom system prompt for Copilot adapter
-- Base on https://github.com/olimorris/codecompanion.nvim/blob/e7d931ae027f9fdca2bd7c53aa0a8d3f8d620256/lua/codecompanion/config.lua#L639 and https://github.com/CopilotC-Nvim/CopilotChat.nvim/blob/d43fab67c328946fbf8e24fdcadfdb5410517e1f/lua/CopilotChat/prompts.lua#L5
local SYSTEM_PROMPT = string.format(
  [[You are an AI programming assistant named "GitHub Copilot".
You are currently plugged in to the Neovim text editor on a user's machine.

Your tasks include:
- Answering general programming questions.
- Explaining how the code in a Neovim buffer works.
- Reviewing the selected code in a Neovim buffer.
- Generating unit tests for the selected code.
- Proposing fixes for problems in the selected code.
- Scaffolding code for a new workspace.
- Finding relevant code to the user's query.
- Proposing fixes for test failures.
- Answering questions about Neovim.
- Ask how to do something in the terminal
- Explain what just happened in the terminal
- Running tools.

You must:
- Follow the user's requirements carefully and to the letter.
- Keep your answers short and impersonal, especially if the user responds with context outside of your tasks.
- Minimize other prose.
- Use Markdown formatting in your answers.
- Include the programming language name at the start of the Markdown code blocks.
- Avoid line numbers in code blocks.
- Avoid wrapping the whole response in triple backticks.
- Only return code that's relevant to the task at hand. You may not need to return all of the code that the user has shared.
- The user works in an IDE called Neovim which has a concept for editors with open files, integrated unit test support, an output pane that shows the output of running the code as well as an integrated terminal.
- The user is working on a %s machine. Please respond with system specific commands if applicable.

When given a task:
1. Think step-by-step and describe your plan for what to build in pseudocode, written out in great detail, unless asked not to do so.
2. Output the code in a single code block.
3. You should always generate short suggestions for the next user turns that are relevant to the conversation.
4. You can only give one reply for each conversation turn.
5. The active document is the source code the user is looking at right now.
]],
  vim.loop.os_uname().sysname
)
local COPILOT_EXPLAIN =
  string.format [[You are a world-class coding tutor. Your code explanations perfectly balance high-level concepts and granular details. Your approach ensures that students not only understand how to write code, but also grasp the underlying principles that guide effective programming.
When asked for your name, you must respond with "GitHub Copilot".
Follow the user's requirements carefully & to the letter.
Your expertise is strictly limited to software development topics.
Follow Microsoft content policies.
Avoid content that violates copyrights.
For questions not related to software development, simply give a reminder that you are an AI programming assistant.
Keep your answers short and impersonal.
Use Markdown formatting in your answers.
Make sure to include the programming language name at the start of the Markdown code blocks.
Avoid wrapping the whole response in triple backticks.
The user works in an IDE called Neovim which has a concept for editors with open files, integrated unit test support, an output pane that shows the output of running the code as well as an integrated terminal.
The active document is the source code the user is looking at right now.
You can only give one reply for each conversation turn.

Additional Rules
Think step by step:
1. Examine the provided code selection and any other context like user question, related errors, project details, class definitions, etc.
2. If you are unsure about the code, concepts, or the user's question, ask clarifying questions.
3. If the user provided a specific question or error, answer it based on the selected code and additional provided context. Otherwise focus on explaining the selected code.
4. Provide suggestions if you see opportunities to improve code readability, performance, etc.

Focus on being clear, helpful, and thorough without assuming extensive prior knowledge.
Use developer-friendly terms and analogies in your explanations.
Identify 'gotchas' or less obvious parts of the code that might trip up someone new.
Provide clear and relevant examples aligned with any provided context.
]]
local COPILOT_REVIEW = string.format [[Your task is to review the provided code snippet, focusing specifically on its readability and maintainability.
Identify any issues related to:
- Naming conventions that are unclear, misleading or doesn't follow conventions for the language being used.
- The presence of unnecessary comments, or the lack of necessary ones.
- Overly complex expressions that could benefit from simplification.
- High nesting levels that make the code difficult to follow.
- The use of excessively long names for variables or functions.
- Any inconsistencies in naming, formatting, or overall coding style.
- Repetitive code patterns that could be more efficiently handled through abstraction or optimization.

Your feedback must be concise, directly addressing each identified issue with:
- A clear description of the problem.
- A concrete suggestion for how to improve or correct the issue.
  
Format your feedback as follows:
- Explain the high-level issue or problem briefly.
- Provide a specific suggestion for improvement.
 
If the code snippet has no readability issues, simply confirm that the code is clear and well-written as is.
]]
local COPILOT_REFACTOR = string.format [[Your task is to refactor the provided code snippet, focusing specifically on its readability and maintainability.
Identify any issues related to:
- Naming conventions that are unclear, misleading or doesn't follow conventions for the language being used.
- The presence of unnecessary comments, or the lack of necessary ones.
- Overly complex expressions that could benefit from simplification.
- High nesting levels that make the code difficult to follow.
- The use of excessively long names for variables or functions.
- Any inconsistencies in naming, formatting, or overall coding style.
- Repetitive code patterns that could be more efficiently handled through abstraction or optimization.
]]
local SWAGGO_PROMPT =
  string.format [[You are an expert Go developer specializing in creating REST API documentation using Swaggo (Swagger/OpenAPI annotations in Go). Your task is to generate Swaggo comment blocks for a selected Go function or handler, using the full file buffer as context.

Follow these rules:
1. Analyze the full Go file buffer to understand the context (e.g., imports, structs, variable types).
2. Generate Swaggo comments *only* for the selected function or handler provided in the user prompt.
3. Place the comment block directly above the function, using proper Go comment syntax (`//`).
4. Do not include blank lines between the comment block and the function.
5. Use appropriate Swaggo annotations based on the function's purpose and signature, such as:
   - `// @Summary`: A concise summary of what the function does (e.g., "Create a new user").
   - `// @Description`: A longer explanation (optional, infer from context if possible).
   - `// @Tags`: Logical group or category (e.g., "users", "products").
   - `// @Param`: Parameters in the format `name in type required "description"` (e.g., `id path int true "User ID"`).
   - `// @Success`: Success response in the format `code {type} type "description"` (e.g., `200 {object} model.User "User data"`).
   - `// @Failure`: Error response in the format `code {type} type "description"` (e.g., `404 {string} string "User not found"`).
   - `// @Router`: Route and HTTP method in the format `/path [method]` (e.g., `/users/{id} [get]`).
6. Infer HTTP methods (e.g., GET, POST) and paths from the function name or context (e.g., `GetUser` implies `[get]`).
7. Use realistic and meaningful values for descriptions and types based on the code.
8. Do not explain the comments or add extraneous text—output only the comment block.

Example:
Input:
```go
func GetUser(w http.ResponseWriter, r *http.Request) {
    // Function body 
output:
// @Summary Get user by ID
// @Description Retrieves a user from the database based on their ID
// @Tags users
// @Param id path int true "User ID"
// @Success 200 {object} model.User "User data"
// @Failure 400 {string} string "Invalid ID"
// @Failure 404 {string} string "User not found"
// @Router /users/{id} [get]
func GetUser(w http.ResponseWriter, r *http.Request) {
    // Function body
}
Only output the comment block itself, not the function. ]]

return {
  'olimorris/codecompanion.nvim',
  config = true,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  opts = {
    prompt_library = {
      -- Custom the default prompt
      ['Generate a Commit Message'] = {
        prompts = {
          {
            role = 'user',
            content = function()
              return "Write commit message with commitizen convention. Write clear, informative commit messages that explain the 'what' and 'why' behind changes, not just the 'how'."
                .. '\n\n```\n'
                .. vim.fn.system 'git diff'
                .. '\n```'
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ['Explain'] = {
        strategy = 'chat',
        description = 'Explain how code in a buffer works',
        opts = {
          default_prompt = true,
          modes = { 'v' },
          short_name = 'explain',
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
        },
        prompts = {
          {
            role = 'system',
            content = COPILOT_EXPLAIN,
            opts = {
              visible = false,
            },
          },
          {
            role = 'user',
            content = function(context)
              local code = require('codecompanion.helpers.actions').get_code(context.start_line, context.end_line)

              return 'Please explain how the following code works:\n\n```' .. context.filetype .. '\n' .. code .. '\n```\n\n'
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ['Swaggo Comments'] = {
        strategy = 'chat',
        description = 'Generate swaggo comments for selected handler/function, using full buffer as context.',
        opts = {
          modes = { 'v' },
          short_name = 'swaggo',
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
        },
        prompts = {
          {
            role = 'system',
            content = SWAGGO_PROMPT,
          },
          {
            role = 'user',
            content = function(context)
              local get_code = require('codecompanion.helpers.actions').get_code
              local full_code = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
              local selection = get_code(context.start_line, context.end_line)

              return 'Full file context:\n\n```go\n' .. full_code .. '\n```\n\nTarget for swaggo comments:\n\n```go\n' .. selection .. '\n```'
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ['Explain Code'] = {
        strategy = 'chat',
        description = 'Explain how code works',
        opts = {
          short_name = 'explain-code',
          auto_submit = false,
          is_slash_cmd = true,
        },
        prompts = {
          {
            role = 'system',
            content = COPILOT_EXPLAIN,
            opts = {
              visible = false,
            },
          },
          {
            role = 'user',
            content = [[Please explain how the following code works.]],
          },
        },
      },
      -- Add custom prompts
      ['Generate a Commit Message for Staged'] = {
        strategy = 'chat',
        description = 'Generate a commit message for staged change',
        opts = {
          short_name = 'staged-commit',
          auto_submit = true,
          is_slash_cmd = true,
        },
        prompts = {
          {
            role = 'user',
            content = function()
              return "Write commit message for the change with commitizen convention. Write clear, informative commit messages that explain the 'what' and 'why' behind changes, not just the 'how'."
                .. '\n\n```\n'
                .. vim.fn.system 'git diff --staged'
                .. '\n```'
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ['Inline Document'] = {
        strategy = 'inline',
        description = 'Add documentation for code.',
        opts = {
          modes = { 'v' },
          short_name = 'inline-doc',
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
        },
        prompts = {
          {
            role = 'user',
            content = function(context)
              local code = require('codecompanion.helpers.actions').get_code(context.start_line, context.end_line)

              return 'Please provide documentation in comment code for the following code and suggest to have better naming to improve readability.\n\n```'
                .. context.filetype
                .. '\n'
                .. code
                .. '\n```\n\n'
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ['Document'] = {
        strategy = 'chat',
        description = 'Write documentation for code.',
        opts = {
          modes = { 'v' },
          short_name = 'doc',
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
        },
        prompts = {
          {
            role = 'user',
            content = function(context)
              local code = require('codecompanion.helpers.actions').get_code(context.start_line, context.end_line)

              return 'Please brief how it works and provide documentation in comment code for the following code. Also suggest to have better naming to improve readability.\n\n```'
                .. context.filetype
                .. '\n'
                .. code
                .. '\n```\n\n'
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ['Review'] = {
        strategy = 'chat',
        description = 'Review the provided code snippet.',
        opts = {
          modes = { 'v' },
          short_name = 'review',
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
        },
        prompts = {
          {
            role = 'system',
            content = COPILOT_REVIEW,
            opts = {
              visible = false,
            },
          },
          {
            role = 'user',
            content = function(context)
              local code = require('codecompanion.helpers.actions').get_code(context.start_line, context.end_line)

              return 'Please review the following code and provide suggestions for improvement then refactor the following code to improve its clarity and readability:\n\n```'
                .. context.filetype
                .. '\n'
                .. code
                .. '\n```\n\n'
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ['Review Code'] = {
        strategy = 'chat',
        description = 'Review code and provide suggestions for improvement.',
        opts = {
          short_name = 'review-code',
          auto_submit = false,
          is_slash_cmd = true,
        },
        prompts = {
          {
            role = 'system',
            content = COPILOT_REVIEW,
            opts = {
              visible = false,
            },
          },
          {
            role = 'user',
            content = 'Please review the following code and provide suggestions for improvement then refactor the following code to improve its clarity and readability.',
          },
        },
      },
      ['Refactor'] = {
        strategy = 'inline',
        description = 'Refactor the provided code snippet.',
        opts = {
          modes = { 'v' },
          short_name = 'refactor',
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
        },
        prompts = {
          {
            role = 'system',
            content = COPILOT_REFACTOR,
            opts = {
              visible = false,
            },
          },
          {
            role = 'user',
            content = function(context)
              local code = require('codecompanion.helpers.actions').get_code(context.start_line, context.end_line)

              return 'Please refactor the following code to improve its clarity and readability:\n\n```' .. context.filetype .. '\n' .. code .. '\n```\n\n'
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ['Refactor Code'] = {
        strategy = 'chat',
        description = 'Refactor the provided code snippet.',
        opts = {
          short_name = 'refactor-code',
          auto_submit = false,
          is_slash_cmd = true,
        },
        prompts = {
          {
            role = 'system',
            content = COPILOT_REFACTOR,
            opts = {
              visible = false,
            },
          },
          {
            role = 'user',
            content = 'Please refactor the following code to improve its clarity and readability.',
          },
        },
      },
      ['Naming'] = {
        strategy = 'inline',
        description = 'Give betting naming for the provided code snippet.',
        opts = {
          modes = { 'v' },
          short_name = 'naming',
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
        },
        prompts = {
          {
            role = 'user',
            content = function(context)
              local code = require('codecompanion.helpers.actions').get_code(context.start_line, context.end_line)

              return 'Please provide better names for the following variables and functions:\n\n```' .. context.filetype .. '\n' .. code .. '\n```\n\n'
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ['Better Naming'] = {
        strategy = 'chat',
        description = 'Give betting naming for the provided code snippet.',
        opts = {
          short_name = 'better-naming',
          auto_submit = false,
          is_slash_cmd = true,
        },
        prompts = {
          {
            role = 'user',
            content = 'Please provide better names for the following variables and functions.',
          },
        },
      },
    },
  },
  keys = {
    -- Recommend setup
    {
      mapping_key_prefix .. 'a',
      '<cmd>CodeCompanionActions<cr>',
      desc = 'Code Companion - Actions',
    },
    {
      mapping_key_prefix .. 's',
      '<cmd>CodeCompanion /swaggo<cr>',
      desc = 'Code Companion - Swaggo comments',
      mode = 'v',
    },

    {
      mapping_key_prefix .. 'v',
      '<cmd>CodeCompanionChat Toggle<cr>',
      desc = 'Code Companion - Toggle',
      mode = { 'n', 'v' },
    },
    -- Some common usages with visual mode
    {
      mapping_key_prefix .. 'e',
      '<cmd>CodeCompanion /explain<cr>',
      desc = 'Code Companion - Explain code',
      mode = 'v',
    },
    {
      mapping_key_prefix .. 'f',
      '<cmd>CodeCompanion /fix<cr>',
      desc = 'Code Companion - Fix code',
      mode = 'v',
    },
    {
      mapping_key_prefix .. 'l',
      '<cmd>CodeCompanion /lsp<cr>',
      desc = 'Code Companion - Explain LSP diagnostic',
      mode = { 'n', 'v' },
    },
    {
      mapping_key_prefix .. 't',
      '<cmd>CodeCompanion /tests<cr>',
      desc = 'Code Companion - Generate unit test',
      mode = 'v',
    },
    {
      mapping_key_prefix .. 'm',
      '<cmd>CodeCompanion /commit<cr>',
      desc = 'Code Companion - Git commit message',
    },
    -- Custom prompts
    {
      mapping_key_prefix .. 'M',
      '<cmd>CodeCompanion /staged-commit<cr>',
      desc = 'Code Companion - Git commit message (staged)',
    },
    {
      mapping_key_prefix .. 'd',
      '<cmd>CodeCompanion /inline-doc<cr>',
      desc = 'Code Companion - Inline document code',
      mode = 'v',
    },
    { mapping_key_prefix .. 'D', '<cmd>CodeCompanion /doc<cr>', desc = 'Code Companion - Document code', mode = 'v' },
    {
      mapping_key_prefix .. 'r',
      '<cmd>CodeCompanion /refactor<cr>',
      desc = 'Code Companion - Refactor code',
      mode = 'v',
    },
    {
      mapping_key_prefix .. 'R',
      '<cmd>CodeCompanion /review<cr>',
      desc = 'Code Companion - Review code',
      mode = 'v',
    },
    {
      mapping_key_prefix .. 'n',
      '<cmd>CodeCompanion /naming<cr>',
      desc = 'Code Companion - Better naming',
      mode = 'v',
    },
    -- Quick chat
    {
      mapping_key_prefix .. 'q',
      function()
        local input = vim.fn.input 'Quick Chat: '
        if input ~= '' then
          vim.cmd('CodeCompanion ' .. input)
        end
      end,
      desc = 'Code Companion - Quick chat',
    },
  },
}
