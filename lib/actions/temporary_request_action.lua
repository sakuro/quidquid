-- lib/actions/temporary_request_action.lua
local TemporaryRequestAction = {}

-- pure, testable: `existing_groups` is a plain array of group-name strings already
-- extracted from real sections by the caller
function TemporaryRequestAction.find_section_index_by_group(existing_groups, group)
  for i, g in ipairs(existing_groups) do
    if g == group then
      return i
    end
  end
  return nil
end

-- pure, testable: `existing` is a plain array already extracted from real slots by the caller
function TemporaryRequestAction.find_slot_index(existing, item_name, quality)
  for i, slot in ipairs(existing) do
    if slot.value ~= nil and slot.value.name == item_name and slot.value.quality == quality then
      return i
    end
  end
  return #existing + 1
end

-- pure, testable: `filters` is shaped like `LuaLogisticPoint.filters` (a plain array of
-- {name=.., quality=.., count=..} tables), already extracted by the caller. `filters`
-- already reflects Factorio's own per-item pooled total across every section on the
-- point, so a single matching entry's `count` IS the combined target -- no manual
-- summation across sections is needed here.
function TemporaryRequestAction.combined_target(filters, item_name, quality)
  for _, filter in ipairs(filters) do
    if filter.name == item_name and filter.quality == quality then
      return filter.count
    end
  end
  return 0
end

return TemporaryRequestAction
