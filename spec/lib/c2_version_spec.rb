describe C2Version do
  describe "#diff" do
    it "compares this version (before) with the next (after)" do
      test_client_request = create(:test_client_request)
      test_client_request.project_title = "something different"
      test_client_request.save!
      versions = test_client_request.versions
      expect(versions.count).to eq(2)
      expect(versions.last.diff).to include(["~", "project_title", "I am a test request", "something different"])
    end

    it "converts all TimeWithZone objects to Time via .utc" do
      step = create(:approval_step, completed_at: Time.current)
      step.status = "actionable"
      step.save!

      updated_at_diff = step.versions.last.diff.select { |diff| diff[1] == "updated_at" }.first
      expect(updated_at_diff[2].zone).to eq("UTC")
      expect(updated_at_diff[3].zone).to eq("UTC")
      expect(step.versions.last.diff).to include(["~", "status", "pending", "actionable"])
    end
  end
end
