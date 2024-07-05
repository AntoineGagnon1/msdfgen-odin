package msdfgen

import "core:c"

when ODIN_OS == .Windows {
    foreign import msdfgen "msdfgen.lib"
}

