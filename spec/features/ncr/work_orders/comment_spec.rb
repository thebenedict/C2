describe "commenting on an NCR work order" do
  around(:each) do |example|
    with_env_var('DISABLE_SANDBOX_WARNING', 'true') do
      example.run
    end
  end

  let!(:approver) { FactoryGirl.create(:user) }
  let(:work_order) { FactoryGirl.create(:ncr_work_order, description: 'test') }
  let(:proposal) { work_order.proposal }

  context "delegate on a work order" do
    let(:delegate) { FactoryGirl.create(:user) }

    before do
      work_order.setup_approvals_and_observers('approver@example.com')
      approver = proposal.approvers.first
      approver.add_delegate(delegate)
      login_as(delegate)
    end

    it "adds current user to the observers list when commenting" do
      visit "/proposals/#{proposal.id}"
      fill_in "comment_comment_text", with: "comment text"
      click_on "Send a Comment"

      expect(page).to have_content("comment text")
      expect(proposal.observers).to include(delegate)
    end
  end
end
