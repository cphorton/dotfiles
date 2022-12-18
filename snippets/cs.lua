
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

function string:endswith(suffix)
    return self:sub(-#suffix) == suffix
end


local accessModifiers = {t "public", t "private", t "protected", t "internal", t "protected internal", t "private protected"}
-- local accessModifier = {t "public"}

--Use Plenary to scan the current file and then get the csproj name
local get_csproj_name = function()
    local proj_files = scan.scan_dir(".", {search_pattern = function(entry)
        return entry:endswith(".csproj")
    end} )

    if(next(proj_files) ~= nil) then
        local fileName = proj_files[1]

        fileName = fileName:gsub(".csproj",""):gsub("%.",""):gsub("/",""):gsub("\\","")
        return fileName
    end

    return ""
end



local get_namespace = function ()
    return f(function()
        --get the path from our root, without the buffer filename
        --based on the lsp workspace - in this case the csproj file
        local root = vim.lsp.buf.list_workspace_folders()[1]

        local path = vim.fn.expand('%:h')

        local bufferPath = path:gsub(root,"")
        bufferPath = bufferPath:sub(2)

        local csproj_name = get_csproj_name()

        if(bufferPath == "")then
            bufferPath = csproj_name
        elseif (not bufferPath:match(csproj_name)) then
            bufferPath = csproj_name .. "." .. bufferPath
        end


        return bufferPath:gsub("/","."):gsub("\\",".")
    end
    )
end

local get_classname = function ()
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
    { trig = "sns",descr="Create folder-based namespace and class" },
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
        {get_namespace(),
        c(1, {t "public", t "internal"}),
        c(2, {t "", t "static "}),
        get_classname(), i(0)}
        )
    ),

    -- property snippet
    s(
    {trig="spr", descr="create a property"},
    fmt([[public {} {} {{get; set;}}]], {i(1, "int"), i(0, "MyProperty")})
        
    ),

    -- Create a class
    s(
    {trig="scl", descr="Create a class"},
    fmt(
        [[
        {} {}class {}
        {{
            {}
        }}
        ]],
        {c(1, {t "public", t "internal"}),
        c(2, {t "", t "static "}),
        i(3, "MyClass"), i(0)}
        )
    ),

    -- create an interface
    s(
    {trig="sin", descr="Create an interface"},
    fmt(
        [[
        {} interface I{}
        {{
            {}
        }}
        ]],
        {c(1, {t "public", t "internal"}),
        i(2, "MyInterface"), i(0)}
        )
    ),

    -- Create a method
    s(
    {trig="sme", descr="Create a method"},
    fmt(
        [[
        {} {}{} {}({})
        {{
            {}
        }}
        ]],

        {
            c(1, {t "public"}),      --public, private etc
            c(2, {t "", t "static "}),  --static choice
            i(3, "void"),               --return type
            i(4,"MyMethod"),            --method name
            i(5),                       --parameters
            i(0)}                       --body
        )
    ),

    -- For each loop
    s(
    {trig="sfe", dscr="Foreach loop"},
    fmt(
        [[
        foreach(var {} in {})
        {{
            {}
        }}
        ]],
        {i(1, "MyVariable"),i(2, "MyCollection"),i(0)}
        )
    ),

    -- Record
    s(
    {trig="sre", descr="Create a record"},
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
    {trig="stc", descr="Try catch block"},
    fmt(
        [[
        try
        {{
            {}
        }}
        catch (Exception ex)
        {{
            //TODO: Log and handle exception
        }}
        ]],
        {i(0)}
        )
    ),

    --If statement
    s(
    {trig="sif", descr="If statement"},
    fmt(
        [[
        if ({})
        {{
            {}
        }}
        ]],
        {i(1),i(0)}
        )
    ),
    -- Create a Mediatr Handler
    s(
    {trig="smh", descr="Create a Mediatr handler class"},
    fmt(
        [[
        {} class {} : IRequestHandler<{}, {}>
        {{
            {}
        }}
        ]],
        {c(1, {t "public", t "internal"}),
        i(2, "MyClass"), i(3, "MyRequestType"), i(4,"MyReturnType"), i(0)}
        )
    ),

    -- Create a Mediatr Handler
    s(
    {trig="snmh", descr="Create a namespace and Mediatr handler class"},
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
        {get_namespace(),
        c(1, {t "public", t "internal"}),
        i(2, "MyClass"), i(3, "MyRequestType"), i(4,"MyReturnType"), i(0)}
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
    {trig="ssw", descr="Switch statement"},
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
        {i(1, "value"),i(2),i(0)}
            )
        )

   
})
