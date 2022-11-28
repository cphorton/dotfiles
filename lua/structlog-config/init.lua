local log = require("structlog")

log.configure({
  name = {
    sinks = {
        log.sinks.NvimNotify(
        log.level.INFO,
        {
          processors = {
            log.processors.Namer(),
          },
          formatter = log.formatters.Format( --
            "%s",
            { "msg" },
            { blacklist = { "level", "logger_name" } }
          ),
          params_map = { title = "logger_name" },
        })
            }
        }
    })
