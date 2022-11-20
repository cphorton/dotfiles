
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



return(

{
    -- A snippet that creates a namespace based on the folder structure
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
            c(1, accessModifiers),      --public, private etc
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
    )    
})
