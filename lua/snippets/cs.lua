local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local c = ls.choice_node
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep

local scan = require("plenary.scandir")
local path = require("plenary.path")

local function get_csproj_file()
    --Find csproj files upward
    local projectFiles = vim.fs.find(function(name, _)
       return name:match('.*%.csproj$') end,
    {
       upward = true,
       stop = vim.loop.os_homedir(),
       path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
    })

    --Check to see if we find any
    if next(projectFiles) == nil then
        return ""
    end

    return projectFiles[1]
end

local accessModifiers = { t "public", t "private", t "protected", t "internal", t "protected internal",
    t "private protected" }


local get_folder = function(file_path)

    local sep = path.path.sep
    local idx = file_path:match('^.*()'..sep) - 1

    return file_path:sub(1,idx)

end

local get_csproj_name = function()

    local csproj_path = get_csproj_file()
    local sep = path.path.sep

    local index = csproj_path:match('^.*()'..sep) + 1

    local  proj_name = csproj_path:sub(index)
    
    if (proj_name ~= nil) then
        return proj_name
    end

    return ""
end

local get_namespace = function()
    return f(function()
        --local path = vim.fn.expand('%:h')

        local buffer_path = vim.api.nvim_buf_get_name(0)

        -- print ("Buffer path: "..get_folder(buffer_path))


        local csproj_file = get_csproj_file()

        local project_path = get_folder(get_csproj_file())

        -- print("Project path: "..project_path)


        local csproj_name = get_csproj_name():gsub(".csproj","")

        -- print("Full file: "..csproj_file)

        -- print("Full path: "..buffer_path)

        -- print("Projct name: "..csproj_name)

        local namespace_path = buffer_path:gsub(project_path,"")

        -- print("Namespace path: "..namespace_path)

        local sep = path.path.sep
        -- if (namespace_path:find(sep, 1, true) == 1) then
        --     namespace_path = namespace_path:sub((sep:len() + 1))
        -- end

        namespace_path = csproj_name..get_folder(namespace_path)


        --swap out slashes for '.'
        --local namespace = buffer_path:gsub(csproj_file,""):gsub("/","."):gsub("\\",".")
        --local namespace = namespace_path:gsub(csproj_file,""):gsub("/","."):gsub("\\",".")
        local namespace = namespace_path:gsub(sep,".")

        if (namespace == ".") then
            return csproj_name
        end


        return namespace
    end
    )
end

local get_classname = function()
    return f(function()
        --get the name of the current file
        return vim.fn.expand('%:t:r')
    end
    )
end

ls.add_snippets("cs",
    {
        -- A snippet that creates a namespace and class based on the folder structure
        s(
            { trig = "namespace", descr = "Create folder-based namespace and class" },
            fmt(
                [[
        namespace {}
        {{
            {} {}class {}
            {{
                {}
            }}
        }}

        ]],
                { get_namespace(),
                    c(1, { t "public", t "internal" }),
                    c(2, { t "", t "static " }),
                    get_classname(), i(0) }
            )
        ),

        -- property snippet
        s(
            { trig = "prop", descr = "create a property" },
            fmt([[public {} {} {{get; set;}}]], { i(1, "int"), i(0, "MyProperty") })

        ),

        -- Create a class
        s(
            { trig = "class", descr = "Create a class" },
            fmt(
                [[
        {} {}class {}
        {{
            {}
        }}
        ]],
                { c(1, { t "public", t "internal" }),
                    c(2, { t "", t "static " }),
                    i(3, "MyClass"), i(0) }
            )
        ),

        -- create an interface
        s(
            { trig = "interface", descr = "Create an interface" },
            fmt(
                [[
        {} interface I{}
        {{
            {}
        }}
        ]],
                { c(1, { t "public", t "internal" }),
                    i(2, "MyInterface"), i(0) }
            )
        ),

        -- Create a method
        s(
            { trig = "method", descr = "Create a method" },
            fmt(
                [[
        {} {}{} {}({})
        {{
            {}
        }}
        ]],

                {
                    c(1, { t "public" }), --public, private etc
                    c(2, { t "", t "static " }), --static choice
                    i(3, "void"),      --return type
                    i(4, "MyMethod"),  --method name
                    i(5),              --parameters
                    i(0) }             --body
            )
        ),

        -- For each loop
        s(
            { trig = "foreach", dscr = "Foreach loop" },
            fmt(
                [[
        foreach(var {} in {})
        {{
            {}
        }}
        ]],
                { i(1, "MyVariable"), i(2, "MyCollection"), i(0) }
            )
        ),

        -- Record
        s(
            { trig = "record", descr = "Create a record" },
            fmt(
                [[{} record {} ({})]],
                {
                    c(1, accessModifiers),
                    i(2, "MyRecord"),
                    i(0)
                })
        ),

        -- Try catch
        s(
            { trig = "trycatch", descr = "Try catch block" },
            fmt(
                [[
        try
        {{
            {}
        }}
        catch (Exception ex)
        {{
            //TODO: Log and handle exception
        }}
        ]],
                { i(0) }
            )
        ),

        --If statement
        s(
            { trig = "if", descr = "If statement" },
            fmt(
                [[
        if ({})
        {{
            {}
        }}
        ]],
                { i(1), i(0) }
            )
        ),
        -- Create a Mediatr Handler
        s(
            { trig = "mediator", descr = "Create a Mediatr handler class" },
            fmt(
                [[
        {} class {} : IRequestHandler<{}, {}>
        {{
            {}
        }}
        ]],
                { c(1, { t "public", t "internal" }),
                    i(2, "MyClass"), i(3, "MyRequestType"), i(4, "MyReturnType"), i(0) }
            )
        ),

        -- Create a Mediatr Handler
        s(
            { trig = "mediatorhandler", descr = "Create a namespace and Mediatr handler class" },
            fmt(
                [[
        using MediatR;
        namespace {}
        {{
            {} class {} : IRequestHandler<{}, {}>
            {{
                {}
            }}
        }}
        ]],
                { get_namespace(),
                    c(1, { t "public", t "internal" }),
                    i(2, "MyClass"), i(3, "MyRequestType"), i(4, "MyReturnType"), i(0) }
            )
        ),
        -- Create a Mediatr Handler
        -- https://github.com/L3MON4D3/LuaSnip/wiki/Cool-Snippets#all---insert-space-when-the-next-character-after-snippet-is-a-letter
        -- s(
        -- {trig="smhf", descr="Create a Mediatr handler class"},
        -- fmt(
        --     [[
        --     public class {}
        --     {{
        --
        --         public record {}({}) : IRequest<{}>
        --
        --         public record {}({})
        --
        --         public class {} : IRequestHandler<{}, {}>
        --         {{
        --             {}
        --         }}
        --     }}
        --     ]],
        --     {c(1, {t "public", t "internal"}),
        --     i(2, "MyClass"), i(3, "MyRequestType"), i(4,"MyReturnType"), i(0)}
        --     )
        -- )
        s(
            { trig = "switchstd", descr = "Switch statement" },
            fmt(
                [[
            switch ({})
            {{
                case {}:
                    {}
                    break;

                default:
                    break;
            }}
        ]],
                { i(1, "value"), i(2), i(0) }
            )
        )
    })
