-- Простий manual test для summarization
-- Запускати в Neovim: :luafile tests/manual_test_summarization.lua

print("🧪 Testing Summarization Logic...")

-- Симуляція estimate_tokens
local function estimate_tokens(text)
    if type(text) ~= "string" then return 0 end
    return math.ceil(#text / 4)
end

-- Тест 1: Оцінка токенів
print("\n✅ Test 1: estimate_tokens")
assert(estimate_tokens("Hello") == 2, "Should be ~2 tokens")
assert(estimate_tokens(string.rep("A", 100)) == 25, "100 chars = 25 tokens")
assert(estimate_tokens(nil) == 0, "nil should return 0")
print("   PASSED")

-- Тест 2: Розрахунок розміру історії
print("\n✅ Test 2: calculate_history_size")
local function calculate_history_size(history)
    local total_tokens = 0
    for _, msg in ipairs(history) do
        total_tokens = total_tokens + estimate_tokens(msg.content)
        if msg.context and msg.context.code then
            total_tokens = total_tokens + estimate_tokens(msg.context.code)
        end
        if msg.tool_results then
            for _, result in ipairs(msg.tool_results) do
                if result.content then
                    total_tokens = total_tokens + estimate_tokens(result.content)
                end
            end
        end
    end
    return total_tokens
end

local test_history = {
    {role = "user", content = string.rep("A", 100)}, -- 25 tokens
    {role = "assistant", content = string.rep("B", 100)}, -- 25 tokens
    {role = "user", content = "Hi", context = {code = string.rep("C", 400)}}, -- 1 + 100 = 101 tokens
}
local size = calculate_history_size(test_history)
assert(size == 151, "Should be 151 tokens, got: " .. size)
print("   PASSED")

-- Тест 3: Перевірка тригерів
print("\n✅ Test 3: Summarization triggers")
local SUMMARIZATION_CONFIG = {
    max_messages = 30,
    max_tokens_estimate = 8000,
    keep_recent = 10,
    summary_marker = "[SUMMARY]"
}

-- Симуляція малої історії
local small_history = {}
for i = 1, 5 do
    table.insert(small_history, {role = "user", content = "Msg " .. i})
end

local should_summarize = #small_history >= SUMMARIZATION_CONFIG.max_messages or 
                        calculate_history_size(small_history) >= SUMMARIZATION_CONFIG.max_tokens_estimate

assert(not should_summarize, "Small history should NOT trigger summarization")
print("   PASSED (small history)")

-- Симуляція великої історії (багато повідомлень)
local large_history = {}
for i = 1, 35 do
    table.insert(large_history, {role = "user", content = "Message " .. i})
end

should_summarize = #large_history >= SUMMARIZATION_CONFIG.max_messages or 
                   calculate_history_size(large_history) >= SUMMARIZATION_CONFIG.max_tokens_estimate

assert(should_summarize, "Large history should trigger summarization")
print("   PASSED (many messages)")

-- Симуляція великого контенту
local content_heavy_history = {}
for i = 1, 15 do
    table.insert(content_heavy_history, {
        role = "user", 
        content = string.rep("A", 2000), -- ~500 tokens
        context = {
            code = string.rep("B", 2000), -- ~500 tokens
        }
    })
end

should_summarize = #content_heavy_history >= SUMMARIZATION_CONFIG.max_messages or 
                   calculate_history_size(content_heavy_history) >= SUMMARIZATION_CONFIG.max_tokens_estimate

assert(should_summarize, "Content-heavy history should trigger summarization")
print("   PASSED (large content)")

-- Тест 4: Summary структура
print("\n✅ Test 4: Summary structure")
local mock_summary = {
    content = "This is a summary of previous conversation",
    timestamp = os.time(),
    covers_messages = 20,
}

assert(type(mock_summary.content) == "string", "content should be string")
assert(type(mock_summary.timestamp) == "number", "timestamp should be number")
assert(type(mock_summary.covers_messages) == "number", "covers_messages should be number")
assert(mock_summary.timestamp > 0, "timestamp should be positive")
assert(mock_summary.covers_messages > 0, "covers_messages should be positive")
print("   PASSED")

-- Тест 5: Summary marker format
print("\n✅ Test 5: Summary marker format")
local formatted_summary = string.format(
    "%s (summary of %d messages until %s)\n\n%s",
    SUMMARIZATION_CONFIG.summary_marker,
    mock_summary.covers_messages,
    os.date("%Y-%m-%d %H:%M", mock_summary.timestamp),
    mock_summary.content
)

assert(formatted_summary:find("%[SUMMARY%]"), "Should contain [SUMMARY] marker")
assert(formatted_summary:find("summary of %d+ messages"), "Should contain message count")
assert(formatted_summary:find("%d%d%d%d%-%d%d%-%d%d"), "Should contain date")
assert(formatted_summary:find(mock_summary.content, 1, true), "Should contain summary text")
print("   PASSED")

print("\n" .. string.rep("=", 50))
print("✅ All tests PASSED!")
print(string.rep("=", 50))
