
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


local accessModifiers = {t "public", t "private", t "protected", t "internal", t "protected internal", t "private protected"}


local get_namespace = function ()
    return f(function()
        --get the path from our root, without the buffer filename
        --https://neovim.io/doc/user/cmdline.html#cmdline-special
        local path = vim.fn.expand('%:p:~:.:h')
        return path:gsub("/","."):gsub("\\",".")
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







-- A snippet that creates a namespace based on the folder structure
local namespace = function()
    return s(
    { trig = "namespace",descr="Create folder-based namespace and class" },
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
  )
end

-- property snippet
local property = function()
    return
    s(
        {trig="prop", descr="create a property"},
        fmt([[public {} {} {{get; set;}}]], {i(1, "int"), i(0, "MyProperty")})
        
    )
end

-- Create a public class
local class = function()
    return
    s(
        {trig="class", descr="Create a class"},

        fmt(
            [[
            public class {}
            {{
                {}
            }}
            ]],
            {i(1, "MyClass"), i(0)}
            )
    )
end


local method = function()
    return
    s(
        {trig="method", descr="Create a method"},

        fmt(
            [[
            {} {}{} {}({})
            {{
                {}
            }}
            ]],

            {
                c(1, accessModifiers),      --public, private etc
                c(2, {t "", t "static "}),  --static choice
                i(3, "void"),               --return type
                i(4,"MyMethod"),            --method name
                i(5),                       --parameters
                i(0)}                       --body
            )
    )
end

return {
    
    namespace(),
    property(),
    class(),
    method(),
    -- record snippet
    s(
    {trig="rec", descr="Create a record"},
    fmt(
        [[public record {} ({})]],
        {i(1, "RecordName"), i(0)}
        )
    ),

}
