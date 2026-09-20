local Palette = require("lib.palette")

describe("Palette", function()
  after_each(function()
    _G.remote = nil
    _G.log = nil
  end)

  describe(".row_caption", function()
    it("builds a rich-text caption for the candidate's label", function()
      local candidate = { icon = "item/iron-plate", label = { "item-name.iron-plate" } }

      local caption = Palette.row_caption(candidate)

      assert.are.same({ "item-name.iron-plate" }, caption)
      assert.are.same({ "", "[img=", "item/iron-plate", "]" }, Palette.icon_caption(candidate))
    end)

    it("bolds matching display and internal-name ranges", function()
      local candidate = {
        icon = "item/iron-plate",
        search_display_name = "Iron plate",
        search_display_ranges = { { start_byte = 6, end_byte = 10 } },
        search_internal_name = "iron-plate",
        search_internal_ranges = { { start_byte = 6, end_byte = 8 } },
      }

      local caption = Palette.row_caption(candidate)

      assert.are.equal("[font=default-large]Iron [/font][font=default-large-bold]plate[/font]", caption)

      assert.are.equal(
        "[font=default]iron-[/font][font=default-bold]pla[/font][font=default]te[/font]",
        Palette.internal_caption(candidate)
      )
    end)

    it("preserves rich-text tags in a display name while highlighting the visible match", function()
      local candidate = {
        icon = "surface/space-platform",
        search_display_name = "[item=iron-plate] Cargo Express",
        search_display_ranges = {
          { start_byte = 25, end_byte = 25 },
          { start_byte = 26, end_byte = 26 },
          { start_byte = 27, end_byte = 27 },
          { start_byte = 28, end_byte = 28 },
          { start_byte = 29, end_byte = 29 },
          { start_byte = 30, end_byte = 30 },
          { start_byte = 31, end_byte = 31 },
        },
      }

      local caption = Palette.row_caption(candidate)

      assert.are.equal(
        "[font=default-large][item=iron-plate] Cargo [/font][font=default-large-bold]Express[/font]",
        caption
      )
    end)
  end)

  describe(".is_palette_input", function()
    it("returns true for a valid element named after the palette input", function()
      assert.is_true(Palette.is_palette_input({ valid = true, name = "quidquid-palette-input" }))
    end)

    it("returns false for a valid element with a different name", function()
      assert.is_false(Palette.is_palette_input({ valid = true, name = "some-other-element" }))
    end)

    it("returns false for an invalid element", function()
      assert.is_false(Palette.is_palette_input({ valid = false, name = "quidquid-palette-input" }))
    end)

    it("returns false for nil", function()
      assert.is_false(Palette.is_palette_input(nil))
    end)
  end)

  describe(".trigger_prefix", function()
    it("returns the text with its trailing space stripped", function()
      assert.are.equal("item", Palette.trigger_prefix("item "))
    end)

    it("returns nil when the text does not end in a space", function()
      assert.is_nil(Palette.trigger_prefix("item"))
    end)

    it("returns nil for an empty string", function()
      assert.is_nil(Palette.trigger_prefix(""))
    end)
  end)

  describe(".search_all_sources", function()
    local function fake_registry(sources)
      return {
        default_active_sources = function()
          return sources
        end,
      }
    end

    it("wraps each source's candidates with that source's label", function()
      Palette.init(fake_registry({
        { id = "items", interface = "quidquid.item-source", label = { "quidquid.source-items" } },
      }))
      _G.remote = {
        call = function(_interface, _fn, _query, _player_index)
          return {
            {
              type = "item",
              id = "iron-plate",
              label = { "item-name.iron-plate" },
              icon = "item/iron-plate",
              search_score = 1,
            },
          }
        end,
      }

      local results = Palette.search_all_sources("iron", 1)

      assert.are.equal(1, #results)
      assert.are.equal("iron-plate", results[1].candidate.id)
      assert.are.same({ "quidquid.source-items" }, results[1].source_label)
    end)

    it("logs and skips a source whose search call fails, still returning the others", function()
      local logged = {}
      _G.log = function(message)
        table.insert(logged, message)
      end
      Palette.init(fake_registry({
        { id = "items", interface = "quidquid.item-source", label = { "quidquid.source-items" } },
        { id = "technologies", interface = "quidquid.technology-source", label = { "quidquid.source-technologies" } },
      }))
      _G.remote = {
        call = function(interface, _fn, _query, _player_index)
          if interface == "quidquid.item-source" then
            error("boom")
          end
          return {
            {
              type = "technology",
              id = "automation",
              label = { "technology-name.automation" },
              icon = "technology/automation",
              search_score = 1,
            },
          }
        end,
      }

      local results = Palette.search_all_sources("a", 1)

      assert.are.equal(1, #results)
      assert.are.equal("automation", results[1].candidate.id)
      assert.are.equal(1, #logged)
    end)

    it("searches only the locked source, ignoring default_active_sources", function()
      local default_active_called = false
      Palette.init({
        default_active_sources = function()
          default_active_called = true
          return {}
        end,
      })
      _G.remote = {
        call = function(_interface, _fn, _query, _player_index)
          return {
            {
              type = "technology",
              id = "automation",
              label = { "technology-name.automation" },
              icon = "technology/automation",
              search_score = 1,
            },
          }
        end,
      }
      local locked_source =
        { id = "technologies", interface = "quidquid.technology-source", label = { "quidquid.source-technologies" } }

      local results = Palette.search_all_sources("auto", 1, locked_source)

      assert.is_false(default_active_called)
      assert.are.equal(1, #results)
      assert.are.equal("automation", results[1].candidate.id)
    end)

    it("trims leading and trailing whitespace from the query before searching sources", function()
      local received_query
      Palette.init(fake_registry({
        { id = "items", interface = "quidquid.item-source", label = { "quidquid.source-items" } },
      }))
      _G.remote = {
        call = function(_interface, _fn, query, _player_index)
          received_query = query
          return {}
        end,
      }

      Palette.search_all_sources("  iron  ", 1)

      assert.are.equal("iron", received_query)
    end)
  end)

  describe(".is_query_valid", function()
    it("returns true when no consulted source implements is_query_valid", function()
      Palette.init({
        default_active_sources = function()
          return { { id = "items", interface = "quidquid.item-source", label = { "quidquid.source-items" } } }
        end,
      })
      _G.remote = {
        interfaces = { ["quidquid.item-source"] = { search = true } },
      }

      assert.is_true(Palette.is_query_valid("iron", 1))
    end)

    it("returns true when the implementing source reports the query valid", function()
      Palette.init({
        default_active_sources = function()
          return {
            { id = "calculator", interface = "quidquid.calculator-source", label = { "quidquid.source-calculator" } },
          }
        end,
      })
      _G.remote = {
        interfaces = { ["quidquid.calculator-source"] = { is_query_valid = true } },
        call = function(_interface, _fn, _query, _player_index)
          return true
        end,
      }

      assert.is_true(Palette.is_query_valid("1 + 2", 1))
    end)

    it("returns false when the implementing source reports the query invalid", function()
      Palette.init({
        default_active_sources = function()
          return {
            { id = "calculator", interface = "quidquid.calculator-source", label = { "quidquid.source-calculator" } },
          }
        end,
      })
      _G.remote = {
        interfaces = { ["quidquid.calculator-source"] = { is_query_valid = true } },
        call = function(_interface, _fn, _query, _player_index)
          return false
        end,
      }

      assert.is_false(Palette.is_query_valid("1 + ", 1))
    end)

    it("consults only the locked source when one is locked", function()
      local default_active_called = false
      Palette.init({
        default_active_sources = function()
          default_active_called = true
          return {}
        end,
      })
      _G.remote = {
        interfaces = { ["quidquid.calculator-source"] = { is_query_valid = true } },
        call = function(_interface, _fn, _query, _player_index)
          return false
        end,
      }
      local locked_source =
        { id = "calculator", interface = "quidquid.calculator-source", label = { "quidquid.source-calculator" } }

      local result = Palette.is_query_valid("1 + ", 1, locked_source)

      assert.is_false(default_active_called)
      assert.is_false(result)
    end)

    it("treats a failed remote call as valid and logs it", function()
      local logged = {}
      _G.log = function(message)
        table.insert(logged, message)
      end
      Palette.init({
        default_active_sources = function()
          return {
            { id = "calculator", interface = "quidquid.calculator-source", label = { "quidquid.source-calculator" } },
          }
        end,
      })
      _G.remote = {
        interfaces = { ["quidquid.calculator-source"] = { is_query_valid = true } },
        call = function(_interface, _fn, _query, _player_index)
          error("boom")
        end,
      }

      local result = Palette.is_query_valid("1 + ", 1)

      assert.is_true(result)
      assert.are.equal(1, #logged)
    end)
  end)

  describe(".build_tooltip", function()
    local function action(id)
      return { id = id, label = { "quidquid.action-" .. id } }
    end

    it("returns nil when there are no applicable actions", function()
      assert.is_nil(Palette.build_tooltip({}))
    end)

    it("builds one hint per action, sorted by key and joined with newlines", function()
      local tooltip = Palette.build_tooltip({
        b = action("craft-all"),
        a = action("craft-1"),
      })

      assert.are.same({
        "",
        { "", { "quidquid.action-craft-1" }, " (", { "quidquid.action-craft-1-hint" }, ")" },
        "\n",
        { "", { "quidquid.action-craft-all" }, " (", { "quidquid.action-craft-all-hint" }, ")" },
      }, tooltip)
    end)

    it("shows every action untruncated at exactly the 10-action budget", function()
      local resolved = {}
      for i = 1, 10 do
        resolved[("k%02d"):format(i)] = action("action-" .. i)
      end

      local tooltip = Palette.build_tooltip(resolved)

      -- 1 leading "" + 10 hints + 9 separators = 20 top-level entries, no truncation marker.
      assert.are.equal(20, #tooltip)
    end)

    it("truncates to 9 actions plus a trailing '...N more' entry past the 10-action budget", function()
      local resolved = {}
      for i = 1, 11 do
        resolved[("k%02d"):format(i)] = action("action-" .. i)
      end

      local tooltip = Palette.build_tooltip(resolved)

      -- First 9 actions only.
      for i = 1, 9 do
        assert.are.same(
          { "", { "quidquid.action-action-" .. i }, " (", { "quidquid.action-action-" .. i .. "-hint" }, ")" },
          tooltip[2 * i]
        )
      end
      assert.are.same({ "quidquid.candidate-tooltip-more-actions", 2 }, tooltip[#tooltip])
      -- 1 leading "" + 9 hints + 9 separators (one before each hint after the first, plus
      -- one before the trailing marker) + 1 marker = 20 top-level entries, within budget.
      assert.are.equal(20, #tooltip)
    end)
  end)
end)
