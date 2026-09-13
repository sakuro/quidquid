local TemporaryRequestEditorLogic = require("lib.temporary_request_editor_logic")

describe("TemporaryRequestEditorLogic", function()
  describe(".next_stack_multiple", function()
    it("rounds up to the next multiple when below a multiple", function()
      assert.are.equal(50, TemporaryRequestEditorLogic.next_stack_multiple(30, 50))
    end)

    it("advances to the next multiple when already at an exact multiple", function()
      assert.are.equal(100, TemporaryRequestEditorLogic.next_stack_multiple(50, 50))
    end)

    it("rounds up from a value between two multiples", function()
      assert.are.equal(100, TemporaryRequestEditorLogic.next_stack_multiple(80, 50))
    end)

    it("advances from zero to the first stack", function()
      assert.are.equal(50, TemporaryRequestEditorLogic.next_stack_multiple(0, 50))
    end)
  end)

  describe(".decide_confirm_action", function()
    it("returns remove_zero when the entered quantity is 0", function()
      assert.are.equal("remove_zero", TemporaryRequestEditorLogic.decide_confirm_action(0, 0))
    end)

    it("returns remove_zero when quantity is 0 even if already_have is positive", function()
      assert.are.equal("remove_zero", TemporaryRequestEditorLogic.decide_confirm_action(0, 80))
    end)

    it("returns remove_satisfied when already holding exactly the entered quantity", function()
      assert.are.equal("remove_satisfied", TemporaryRequestEditorLogic.decide_confirm_action(50, 50))
    end)

    it("returns remove_satisfied when already holding more than the entered quantity", function()
      assert.are.equal("remove_satisfied", TemporaryRequestEditorLogic.decide_confirm_action(50, 80))
    end)

    it("returns set when holding less than the entered quantity", function()
      assert.are.equal("set", TemporaryRequestEditorLogic.decide_confirm_action(50, 10))
    end)
  end)
end)
