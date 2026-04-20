package.path = "./?.lua;./?/init.lua;" .. package.path

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s\nexpected: %s\nactual: %s", message or "assertEquals failed", tostring(expected), tostring(actual)))
    end
end

local function assertTrue(value, message)
    if not value then
        error(message or "assertTrue failed")
    end
end

local persisted_settings
local shown_widgets = {}
local closed_widgets = {}

package.preload["gettext"] = function()
    return function(text)
        return text
    end
end

package.preload["ui/widget/container/widgetcontainer"] = function()
    local WidgetContainer = {}

    function WidgetContainer:extend(definition)
        definition = definition or {}
        definition.__index = definition
        return setmetatable(definition, { __index = self })
    end

    return WidgetContainer
end

package.preload["ui/uimanager"] = function()
    return {
        show = function(_, widget)
            table.insert(shown_widgets, widget)
        end,
        close = function(_, widget)
            table.insert(closed_widgets, widget)
        end,
    }
end

package.preload["ui/widget/infomessage"] = function()
    return {
        new = function(_, opts)
            return opts
        end,
    }
end

package.preload["ui/widget/inputdialog"] = function()
    return {
        new = function(_, opts)
            return opts
        end,
    }
end

package.preload["ui/widget/confirmbox"] = function()
    return {
        new = function(_, opts)
            return opts
        end,
    }
end

_G.G_reader_settings = {
    readSetting = function(_, key, default)
        if key == "statusbardisabler" then
            return persisted_settings or default
        end
        return default
    end,
    saveSetting = function(_, key, value)
        if key == "statusbardisabler" then
            persisted_settings = value
        end
    end,
}

local StatusBarDisabler = dofile("main.lua")

local function newPlugin(settings, state)
    persisted_settings = settings
    shown_widgets = {}
    closed_widgets = {}

    local footer = {
        toggle_calls = 0,
    }

    function footer:onToggleFooterMode()
        self.toggle_calls = self.toggle_calls + 1
    end

    local plugin = setmetatable({
        ui = {
            menu = {
                registerToMainMenu = function() end,
            },
            document = {
                file = state.file,
            },
            view = {
                footer_visible = state.footer_visible,
                footer = footer,
            },
        },
        state = {
            hidden_by_plugin = state.hidden_by_plugin or false,
        },
    }, { __index = StatusBarDisabler })

    plugin:init()
    return plugin
end

local matching_plugin = newPlugin({
    enabled = true,
    path_fragments = { "Manga" },
}, {
    file = "/books/Manga/One Piece.cbz",
    footer_visible = true,
})

matching_plugin:onReaderReady()

assertEquals(matching_plugin.ui.view.footer.toggle_calls, 1, "matching path should toggle visible footer off")
assertTrue(matching_plugin.state.hidden_by_plugin, "plugin should remember that it hid the footer")

local restore_plugin = newPlugin({
    enabled = true,
    path_fragments = { "Manga" },
}, {
    file = "/books/Novel/book.epub",
    footer_visible = false,
    hidden_by_plugin = true,
})

restore_plugin:onReaderReady()

assertEquals(restore_plugin.ui.view.footer.toggle_calls, 1, "non-matching path should restore footer only when plugin hid it")
assertTrue(not restore_plugin.state.hidden_by_plugin, "restore should clear plugin-owned hidden flag")

local user_hidden_plugin = newPlugin({
    enabled = true,
    path_fragments = { "Manga" },
}, {
    file = "/books/Novel/book.epub",
    footer_visible = false,
    hidden_by_plugin = false,
})

user_hidden_plugin:onReaderReady()

assertEquals(user_hidden_plugin.ui.view.footer.toggle_calls, 0, "plugin must not force footer on when user hid it")

local settings_plugin = newPlugin({
    enabled = true,
    path_fragments = { "Manga" },
}, {
    file = "/books/Novel/book.epub",
    footer_visible = true,
})

settings_plugin:addPathFragment("Comics")
assertEquals(settings_plugin.settings.path_fragments[2], "Comics", "addPathFragment should append a cleaned fragment")

settings_plugin:updatePathFragment(1, " MangaHD ")
assertEquals(settings_plugin.settings.path_fragments[1], "MangaHD", "updatePathFragment should trim whitespace")

settings_plugin:removePathFragment(2)
assertEquals(#settings_plugin.settings.path_fragments, 1, "removePathFragment should delete the selected fragment")
assertTrue(persisted_settings ~= nil, "settings mutations should persist plugin settings")

local disabled_plugin = newPlugin({
    enabled = false,
    path_fragments = { "Manga" },
}, {
    file = "/books/Manga/A.cbz",
    footer_visible = true,
})

disabled_plugin:onReaderReady()
assertEquals(disabled_plugin.ui.view.footer.toggle_calls, 0, "disabled plugin should not change footer visibility")

local menu_items = {}
matching_plugin:addToMainMenu(menu_items)
assertTrue(menu_items.status_bar_disabler ~= nil, "plugin should add a main menu entry")
assertEquals(menu_items.status_bar_disabler.text, "Status bar disabler", "main menu entry text should be stable")
assertTrue(type(menu_items.status_bar_disabler.sub_item_table) == "table", "main menu should expose submenu items")

local transition_plugin = newPlugin({
    enabled = true,
    path_fragments = { "Manga" },
}, {
    file = "/books/Manga/A.cbz",
    footer_visible = true,
})

transition_plugin:onReaderReady()
transition_plugin.ui.document.file = "/books/Novel/B.epub"
transition_plugin.ui.view.footer_visible = false
transition_plugin:onReaderReady()

assertEquals(transition_plugin.ui.view.footer.toggle_calls, 2, "moving from matching to non-matching books should restore footer once")

local dialog_plugin = newPlugin({
    enabled = true,
    path_fragments = {},
}, {
    file = "/books/Novel/book.epub",
    footer_visible = true,
})

dialog_plugin:showAddPathDialog()
local add_dialog = shown_widgets[#shown_widgets]
assertTrue(add_dialog ~= nil, "showAddPathDialog should show an input dialog")
add_dialog.getInputText = function()
    return "Manga"
end
add_dialog.buttons[1][2].callback()
add_dialog.buttons[1][2].callback()

assertEquals(#dialog_plugin.settings.path_fragments, 1, "save button should only add one fragment even if callback fires multiple times")
assertEquals(dialog_plugin.settings.path_fragments[1], "Manga", "save button should add the entered path fragment")
assertEquals(closed_widgets[#closed_widgets], add_dialog, "save button should close the input dialog through UIManager")

dialog_plugin:showAddPathDialog()
local cancel_dialog = shown_widgets[#shown_widgets]
assertTrue(cancel_dialog ~= nil, "cancel dialog should be shown")
cancel_dialog.buttons[1][1].callback()
cancel_dialog.buttons[1][1].callback()

assertEquals(closed_widgets[#closed_widgets], cancel_dialog, "cancel button should close the input dialog through UIManager")

local dedupe_plugin = newPlugin({
    enabled = true,
    path_fragments = { "Manga", "Manga", "Comics", "Manga", "Comics" },
}, {
    file = "/books/Novel/book.epub",
    footer_visible = true,
})

assertEquals(#dedupe_plugin.settings.path_fragments, 2, "plugin should normalize duplicate saved fragments on init")
assertEquals(dedupe_plugin.settings.path_fragments[1], "Manga", "dedupe should preserve the first fragment")
assertEquals(dedupe_plugin.settings.path_fragments[2], "Comics", "dedupe should preserve order for unique fragments")

print("statusbardisabler smoke tests passed")
