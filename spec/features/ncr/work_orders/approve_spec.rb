describe "approving NCR work orders" do
  around(:each) do |example|
    with_env_var('DISABLE_SANDBOX_WARNING', 'true') do
      example.run
    end
  end

  let!(:approver) { FactoryGirl.create(:user) }
  let(:work_order){FactoryGirl.create(:ncr_work_order)}
  let(:ncr_proposal){work_order.proposal}

  before do
    Timecop.freeze(10.hours.ago) do
      work_order.setup_approvals_and_observers('approver@example.com')
    end
    login_as(work_order.approvers.first)
  end

  it "allows an approver to approve work order" do
    Timecop.freeze() do
      visit "/proposals/#{ncr_proposal.id}"
      click_on("Approve")
      expect(current_path).to eq("/proposals/#{ncr_proposal.id}")
      expect(page).to have_content("You have approved #{work_order.public_identifier}")
      approval = Proposal.last.individual_approvals.first
      expect(approval.status).to eq('approved')
      expect(approval.approved_at.utc.to_s).to eq(Time.now.utc.to_s)
    end
  end

  it "doesn't send multiple emails to approvers who are also observers" do
    work_order.add_observer(work_order.approvers.first.email_address)
    visit "/proposals/#{ncr_proposal.id}"
    click_on("Approve")
    expect(work_order.proposal.observers.length).to eq(1)
    expect(deliveries.length).to eq(1)
  end
end
