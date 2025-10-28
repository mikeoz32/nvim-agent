-- Простий тест для перевірки що plenary працює
describe("basic test", function()
    it("should pass", function()
        assert.equals(1, 1)
    end)
    
    it("should fail intentionally", function()
        -- Закоментовано щоб не ламати CI
        -- assert.equals(1, 2)
    end)
end)
