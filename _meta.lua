local _ = require("gettext")

return {
    name = "statusbardisabler",
    fullname = _("Status bar disabler"),
    description = _([[Disables the bottom status bar on books whose paths match configured fragments and restores it elsewhere only when this plugin disabled it.]]),
    version = "0.1.0",
}
