
local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep


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
    { trig = "namespace",descr="Create folder-based namespace" },
    fmt(
        [[
        namespace {}
        {{
            public class {}
            {{
                {}
            }}
        }}

        ]],
        {get_namespace(),get_classname(), i(0)}
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
        {trig="class", descr="Create a public class"},

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

--Create a static class
local sclass = function()
    return
    s(
        {trig="sclass", descr="Create a public static class"},
        
        fmt(
            [[
            public static class {}
            {{
                {}
            }}
            ]],
            {i(1, "MyClass"), i(0)}
            )
    )
end


 


return {
    
    namespace(),
    property(),
    class(),
    sclass(),
    -- record snippet
    s(
    {trig="rec", descr="Create a record"},
    fmt(
        [[public record {} ({})]],
        {i(1, "RecordName"), i(0)}
        )
    )

}
