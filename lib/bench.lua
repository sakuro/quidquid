-- TEMPORARY measurement harness for the per-candidate annotation experiment
-- (docs/superpowers/plans/2026-09-23-per-candidate-annotation.md). This file and
-- every Bench call site are deleted once the before/after comparison is recorded.
local Bench = {}

-- Probes are inert outside a bench run, so leaving the call sites in during
-- ordinary play costs one boolean test each.
Bench.enabled = false

-- Three widths of query: `a` matches nearly every prototype (largest N), `iron`
-- is typical, `logistic-science-pack` is already narrowed down.
local BENCH_QUERIES = { "a", "iron", "logistic-science-pack" }
local BENCH_REPS = 20

local sums = {}
local counts = {}

-- Returns a running profiler while benching and nil otherwise. Bench.record
-- tolerates the nil, so no call site has to branch on Bench.enabled itself.
function Bench.probe()
  if not Bench.enabled then
    return nil
  end
  return helpers.create_profiler()
end

function Bench.record(label, profiler)
  if profiler == nil then
    return
  end
  profiler.stop()
  local sum = sums[label]
  if sum == nil then
    sums[label] = profiler
  else
    sum.add(profiler)
  end
end

-- Overwritten rather than accumulated: every repetition runs the same query and
-- therefore sees the same candidate count, so a sum would just read BENCH_REPS
-- times too large.
function Bench.count(label, value)
  if not Bench.enabled then
    return
  end
  counts[label] = value
end

-- pairs() order is unspecified; sorting keeps the log lines comparable between
-- the before and after runs without diffing tools reordering them.
local function sorted_labels(map)
  local labels = {}
  for label in pairs(map) do
    table.insert(labels, label)
  end
  table.sort(labels)
  return labels
end

local function report(query)
  for _, label in ipairs(sorted_labels(sums)) do
    local profiler = sums[label]
    profiler.divide(BENCH_REPS)
    log({ "", ("quidquid-bench q=%q %s "):format(query, label), profiler })
  end
  for _, label in ipairs(sorted_labels(counts)) do
    log(("quidquid-bench q=%q %s %d"):format(query, label, counts[label]))
  end
end

-- query_fn is Palette.bench_query, injected rather than required: palette.lua
-- requires this module, so requiring palette.lua back would be circular.
function Bench.run(query_fn, player_index)
  for _, query in ipairs(BENCH_QUERIES) do
    sums = {}
    counts = {}
    Bench.enabled = true
    for _ = 1, BENCH_REPS do
      query_fn(query, player_index)
    end
    Bench.enabled = false
    report(query)
  end
end

return Bench
