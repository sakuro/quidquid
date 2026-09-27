local Declarations = require("lib.declarations")

local function source_data(overrides)
  local data = {
    contract_version = Declarations.CONTRACT_VERSION,
    type = "widget",
    label = { "my-mod.source-widgets" },
    prefixes = { "w" },
    interface = "my-mod.widget-source",
  }
  for key, value in pairs(overrides or {}) do
    data[key] = value
  end
  return data
end

local function action_data(overrides)
  local data = {
    contract_version = Declarations.CONTRACT_VERSION,
    types = { "widget" },
    label = { "my-mod.action-do-thing" },
    hint = { "my-mod.action-do-thing-hint" },
    input_name = "my-mod-do-thing",
    interface = "my-mod.do-thing-action",
  }
  for key, value in pairs(overrides or {}) do
    data[key] = value
  end
  return data
end

-- A value of false in changes removes that key, so a case can describe a missing field.
local function changed(data, changes)
  for key, value in pairs(changes) do
    if value == false then
      data[key] = nil
    else
      data[key] = value
    end
  end
  return data
end

local function mod_data(name, data_type, data, order)
  return { type = "mod-data", name = name, data_type = data_type, data = data, order = order }
end

local function raw_with(entries, custom_inputs)
  local raw = { ["mod-data"] = {}, ["custom-input"] = {} }
  for _, entry in ipairs(entries) do
    raw["mod-data"][entry.name] = entry
  end
  for _, name in ipairs(custom_inputs or {}) do
    raw["custom-input"][name] = { type = "custom-input", name = name }
  end
  return raw
end

describe("Declarations", function()
  describe(".collect", function()
    it("returns only the declarations of the requested data_type", function()
      local collected = Declarations.collect({
        ["my-mod-widgets"] = mod_data("my-mod-widgets", Declarations.SOURCE_DATA_TYPE, source_data()),
        ["my-mod-do-thing"] = mod_data("my-mod-do-thing", Declarations.ACTION_DATA_TYPE, action_data()),
        ["unrelated"] = mod_data("unrelated", "other-mod.thing", {}),
      }, Declarations.SOURCE_DATA_TYPE)

      assert.are.equal(1, #collected)
      assert.are.equal("my-mod-widgets", collected[1].id)
    end)

    it("uses the prototype name as the id, overriding any id in the data", function()
      local collected = Declarations.collect({
        ["my-mod-widgets"] = mod_data("my-mod-widgets", Declarations.SOURCE_DATA_TYPE, source_data({ id = "other" })),
      }, Declarations.SOURCE_DATA_TYPE)

      assert.are.equal("my-mod-widgets", collected[1].id)
      assert.are.equal("widget", collected[1].type)
    end)

    it("orders by order, then by name", function()
      local collected = Declarations.collect({
        ["c"] = mod_data("c", Declarations.SOURCE_DATA_TYPE, source_data(), "a"),
        ["b"] = mod_data("b", Declarations.SOURCE_DATA_TYPE, source_data(), "b"),
        ["a"] = mod_data("a", Declarations.SOURCE_DATA_TYPE, source_data(), "b"),
        ["d"] = mod_data("d", Declarations.SOURCE_DATA_TYPE, source_data()),
      }, Declarations.SOURCE_DATA_TYPE)

      local ids = {}
      for _, definition in ipairs(collected) do
        table.insert(ids, definition.id)
      end
      assert.are.same({ "d", "c", "a", "b" }, ids)
    end)

    it("does not modify the declaration's data", function()
      local data = source_data()
      Declarations.collect({
        ["my-mod-widgets"] = mod_data("my-mod-widgets", Declarations.SOURCE_DATA_TYPE, data),
      }, Declarations.SOURCE_DATA_TYPE)

      assert.is_nil(data.id)
    end)
  end)

  describe(".validate", function()
    it("accepts well-formed source and action declarations", function()
      local raw = raw_with({
        mod_data("my-mod-widgets", Declarations.SOURCE_DATA_TYPE, source_data()),
        mod_data("my-mod-do-thing", Declarations.ACTION_DATA_TYPE, action_data()),
      }, { "my-mod-do-thing" })

      assert.has_no.errors(function()
        Declarations.validate(raw)
      end)
    end)

    it("accepts a source reachable only through the default search", function()
      local raw = raw_with({
        mod_data(
          "my-mod-widgets",
          Declarations.SOURCE_DATA_TYPE,
          source_data({ prefixes = {}, in_default_search = true })
        ),
      })

      assert.has_no.errors(function()
        Declarations.validate(raw)
      end)
    end)

    it("ignores mod-data of other data types", function()
      local raw = raw_with({ mod_data("unrelated", "other-mod.thing", { anything = true }) })

      assert.has_no.errors(function()
        Declarations.validate(raw)
      end)
    end)

    it("skips a declaration written for another contract version", function()
      local raw = raw_with({
        mod_data("my-mod-widgets", Declarations.SOURCE_DATA_TYPE, { contract_version = 1 }),
      })

      assert.has_no.errors(function()
        Declarations.validate(raw)
      end)
    end)

    it("accepts a raw table without any mod-data", function()
      assert.has_no.errors(function()
        Declarations.validate({})
      end)
    end)

    local source_cases = {
      { "a missing type", { type = false }, "type" },
      { "an empty type", { type = "" }, "type" },
      { "a missing label", { label = false }, "label" },
      { "a missing interface", { interface = false }, "interface" },
      { "prefixes that are not an array", { prefixes = "w" }, "prefixes" },
      { "an empty-string prefix", { prefixes = { "w", "" } }, "prefixes" },
      { "a non-boolean in_default_search", { in_default_search = "yes" }, "in_default_search" },
      { "neither prefixes nor in_default_search", { prefixes = {} }, "unreachable" },
    }
    for _, case in ipairs(source_cases) do
      it("rejects a source with " .. case[1], function()
        local raw =
          raw_with({ mod_data("my-mod-widgets", Declarations.SOURCE_DATA_TYPE, changed(source_data(), case[2])) })

        local ok, message = pcall(Declarations.validate, raw)
        assert.is_false(ok)
        assert.matches("my%-mod%-widgets", message)
        assert.matches(case[3], message, 1, true)
      end)
    end

    local action_cases = {
      { "missing types", { types = false }, "types" },
      { "empty types", { types = {} }, "types" },
      { "a non-string type", { types = { 1 } }, "types" },
      { "a missing label", { label = false }, "label" },
      { "a missing hint", { hint = false }, "hint" },
      { "a missing input_name", { input_name = false }, "input_name" },
      { "an input_name with no custom-input", { input_name = "no-such-input" }, "no-such-input" },
      { "a missing interface", { interface = false }, "interface" },
    }
    for _, case in ipairs(action_cases) do
      it("rejects an action with " .. case[1], function()
        local raw = raw_with(
          { mod_data("my-mod-do-thing", Declarations.ACTION_DATA_TYPE, changed(action_data(), case[2])) },
          { "my-mod-do-thing" }
        )

        local ok, message = pcall(Declarations.validate, raw)
        assert.is_false(ok)
        assert.matches("my%-mod%-do%-thing", message)
        assert.matches(case[3], message, 1, true)
      end)
    end
  end)
end)
