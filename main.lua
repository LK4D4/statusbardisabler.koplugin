local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local ConfirmBox = require("ui/widget/confirmbox")
local _ = require("gettext")

local StatusBarDisabler = WidgetContainer:extend{
    name = "statusbardisabler",
}

local DEFAULT_SETTINGS = {
    enabled = true,
    path_fragments = {},
}

local DEFAULT_RUNTIME_STATE = {
    hidden_by_plugin = false,
    previous_footer_mode = nil,
}

local function trim(text)
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

function StatusBarDisabler:findPathFragment(fragment, skip_index)
    if type(fragment) ~= "string" or fragment == "" then
        return nil
    end

    for index, existing in ipairs(self.settings.path_fragments or {}) do
        if index ~= skip_index and existing == fragment then
            return index
        end
    end

    return nil
end

function StatusBarDisabler:normalizeSettings(settings)
    settings = settings or {}
    if settings.enabled == nil then
        settings.enabled = DEFAULT_SETTINGS.enabled
    end

    local fragments = {}
    local seen = {}
    if type(settings.path_fragments) == "table" then
        for _, fragment in ipairs(settings.path_fragments) do
            if type(fragment) == "string" then
                local cleaned = trim(fragment)
                if cleaned ~= "" and not seen[cleaned] then
                    seen[cleaned] = true
                    table.insert(fragments, cleaned)
                end
            end
        end
    end
    settings.path_fragments = fragments

    return settings
end

function StatusBarDisabler:init()
    self.settings = self:normalizeSettings(G_reader_settings:readSetting("statusbardisabler", DEFAULT_SETTINGS))
    self.state = self.state or G_reader_settings:readSetting("statusbardisabler_runtime", DEFAULT_RUNTIME_STATE) or {}
    if self.state.hidden_by_plugin == nil then
        self.state.hidden_by_plugin = false
    end
    self.ui.menu:registerToMainMenu(self)
end

function StatusBarDisabler:persistSettings()
    G_reader_settings:saveSetting("statusbardisabler", self.settings)
end

function StatusBarDisabler:persistRuntimeState()
    G_reader_settings:saveSetting("statusbardisabler_runtime", {
        hidden_by_plugin = self.state.hidden_by_plugin == true,
        previous_footer_mode = self.state.previous_footer_mode,
    })
end

function StatusBarDisabler:pathMatches(file_path)
    if type(file_path) ~= "string" or file_path == "" then
        return false
    end

    for _, fragment in ipairs(self.settings.path_fragments) do
        if file_path:find(fragment, 1, true) then
            return true
        end
    end

    return false
end

function StatusBarDisabler:getCurrentBookPath()
    return self.ui and self.ui.document and self.ui.document.file or nil
end

function StatusBarDisabler:isFooterVisible()
    return self.ui and self.ui.view and self.ui.view.footer_visible == true
end

function StatusBarDisabler:getFooter()
    return self.ui and self.ui.view and self.ui.view.footer or nil
end

function StatusBarDisabler:getCurrentFooterMode()
    local footer = self:getFooter()
    return footer and footer.mode or nil
end

function StatusBarDisabler:applyFooterMode(mode)
    local footer = self:getFooter()
    if not footer or not footer.applyFooterMode then
        return false
    end

    footer:applyFooterMode(mode)
    if footer.onUpdateFooter then
        footer:onUpdateFooter(true)
    end
    return true
end

function StatusBarDisabler:applyPathPolicy(file_path)
    if not self.settings.enabled then
        return
    end

    if self:pathMatches(file_path) then
        if self:isFooterVisible() then
            local current_mode = self:getCurrentFooterMode()
            if current_mode and current_mode ~= 0 and self:applyFooterMode(0) then
                self.state.previous_footer_mode = current_mode
                self.state.hidden_by_plugin = true
                self:persistRuntimeState()
            end
        end
        return
    end

    if self.state.hidden_by_plugin and not self:isFooterVisible() then
        local restore_mode = self.state.previous_footer_mode
        if restore_mode and restore_mode ~= 0 then
            self:applyFooterMode(restore_mode)
        end
    end
    self.state.hidden_by_plugin = false
    self.state.previous_footer_mode = nil
    self:persistRuntimeState()
end

function StatusBarDisabler:onReaderReady()
    self:applyPathPolicy(self:getCurrentBookPath())
end

function StatusBarDisabler:addPathFragment(fragment)
    if type(fragment) ~= "string" then
        return false
    end
    local cleaned = trim(fragment)
    if cleaned == "" or self:findPathFragment(cleaned) then
        return false
    end

    table.insert(self.settings.path_fragments, cleaned)
    self:persistSettings()
    return true
end

function StatusBarDisabler:updatePathFragment(index, fragment)
    if type(fragment) ~= "string" or type(index) ~= "number" or not self.settings.path_fragments[index] then
        return false
    end
    local cleaned = trim(fragment)
    if cleaned == "" or self:findPathFragment(cleaned, index) then
        return false
    end

    self.settings.path_fragments[index] = cleaned
    self:persistSettings()
    return true
end

function StatusBarDisabler:removePathFragment(index)
    if type(index) ~= "number" or not self.settings.path_fragments[index] then
        return false
    end

    table.remove(self.settings.path_fragments, index)
    self:persistSettings()
    return true
end

function StatusBarDisabler:showInfo(text)
    UIManager:show(InfoMessage:new{
        text = text,
    })
end

function StatusBarDisabler:showPathEditor(title, initial_value, on_save)
    local dialog
    local handled = false
    local function closeDialog()
        if not handled and dialog then
            handled = true
            UIManager:close(dialog)
        end
    end

    dialog = InputDialog:new{
        title = title,
        input = initial_value,
        buttons = {{
            {
                text = _("Cancel"),
                id = "close",
                callback = function()
                    closeDialog()
                end,
            },
            {
                text = _("Save"),
                callback = function()
                    if handled then
                        return
                    end
                    if on_save(dialog and dialog.getInputText and dialog:getInputText() or initial_value) then
                        closeDialog()
                    else
                        self:showInfo(_("Path fragment must be non-empty and unique."))
                    end
                end,
            },
        }},
    }
    UIManager:show(dialog)
    if dialog.onShowKeyboard then
        dialog:onShowKeyboard()
    end
end

function StatusBarDisabler:showAddPathDialog()
    self:showPathEditor(_("Add path fragment"), "", function(value)
        return self:addPathFragment(value)
    end)
end

function StatusBarDisabler:showEditPathDialog(index)
    self:showPathEditor(_("Edit path fragment"), self.settings.path_fragments[index], function(value)
        return self:updatePathFragment(index, value)
    end)
end

function StatusBarDisabler:showRemovePathDialog(index)
    UIManager:show(ConfirmBox:new{
        text = _("Delete this path fragment?"),
        ok_text = _("Delete"),
        ok_callback = function()
            self:removePathFragment(index)
        end,
    })
end

function StatusBarDisabler:showDebugInfo()
    local path = self:getCurrentBookPath() or _("No open book")
    local fragments = #self.settings.path_fragments > 0 and table.concat(self.settings.path_fragments, ", ") or _("(none)")
    local status = self:isFooterVisible() and _("visible") or _("hidden")
    local hidden_by_plugin = self.state.hidden_by_plugin and _("yes") or _("no")

    self:showInfo(table.concat({
        _("Current path: ") .. path,
        _("Configured fragments: ") .. fragments,
        _("Footer currently: ") .. status,
        _("Hidden by plugin: ") .. hidden_by_plugin,
    }, "\n"))
end

function StatusBarDisabler:getManagedPathsMenu()
    local items = {}

    for index, fragment in ipairs(self.settings.path_fragments) do
        table.insert(items, {
            text = fragment,
            sub_item_table = {
                {
                    text = _("Edit"),
                    keep_menu_open = true,
                    callback = function()
                        self:showEditPathDialog(index)
                    end,
                },
                {
                    text = _("Delete"),
                    keep_menu_open = true,
                    callback = function()
                        self:showRemovePathDialog(index)
                    end,
                },
            },
        })
    end

    if #items == 0 then
        table.insert(items, {
            text = _("No path fragments configured"),
            enabled = false,
        })
    end

    return items
end

function StatusBarDisabler:addToMainMenu(menu_items)
    menu_items.status_bar_disabler = {
        text = _("Status bar disabler"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = _("Enabled"),
                checked_func = function()
                    return self.settings.enabled
                end,
                callback = function()
                    self.settings.enabled = not self.settings.enabled
                    self:persistSettings()
                end,
            },
            {
                text = _("Add path fragment"),
                keep_menu_open = true,
                callback = function()
                    self:showAddPathDialog()
                end,
            },
            {
                text = _("Managed paths"),
                sub_item_table_func = function()
                    return self:getManagedPathsMenu()
                end,
            },
            {
                text = _("Show debug info"),
                keep_menu_open = true,
                callback = function()
                    self:showDebugInfo()
                end,
            },
        },
    }
end

return StatusBarDisabler
