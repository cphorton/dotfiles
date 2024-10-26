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



local dotnet_utils = require("dotnet.utils.dotnet-utils")
local function get_filename()
    return dotnet_utils.get_file_and_namespace().file_name
end


local accessModifiers = { t "public", t "private", t "protected", t "internal", t "protected internal",
    t "private protected" }

ls.add_snippets("cs",
    {
        -- property snippet
        s(
            { trig = "prop", descr = "create a property" },
            fmt([[public {} {} {{ get; set; }}{}]], { i(1, "int"), i(0, "MyProperty"), c(2,{t "", t " = string.Empty"}) })

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
        {{
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

        -- Create a mediator endpoint
        s(
            { trig = "men", descr = "Mediator Endpoint"},
            fmt(
                [[
        public class {}Endpoint: ApiEndpoint
        {{
            public {}Endpoint(WebApplication app, AvailableVersions availableVersions) : base(app, availableVersions)
            {{

            }}
        }}

        public class {}Validator : AbstractValidator<{}Request>
        {{
            public {}Validator()
            {{
                
            }}
        }}

        public class {}Request : IRequest<{}Response>
        {{

        }}

        public class {}Response 
        {{

        }}

        public class {}Handler : IRequestHandler<{}Request, {}Response>
        {{
            public {}Handler()
            {{

            }}

            public async Task<{}Response> Handle({}Request request, CancellationToken cancellationToken)
            {{

            }}
        }}]],
                {f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                 f(get_filename),
                }
            )
        )
    })
