describe "viewing an NCR work order" do
  around(:each) do |example|
    with_env_var('DISABLE_SANDBOX_WARNING', 'true') do
      example.run
    end
  end

  let!(:approver) { FactoryGirl.create(:user) }
  let (:work_order) { FactoryGirl.create(:ncr_work_order) }
  let(:ncr_proposal) { work_order.proposal }

  before do
    work_order.setup_approvals_and_observers('approver@example.com')
    login_as(work_order.requester)
  end

  it "shows a edit link from a pending proposal" do
    visit "/proposals/#{ncr_proposal.id}"
    expect(page).to have_content('Modify Request')
    click_on('Modify Request')
    expect(current_path).to eq("/ncr/work_orders/#{work_order.id}/edit")
  end

  it "shows a edit link for an approved proposal" do
    ncr_proposal.update_attribute(:status, 'approved') # avoid state machine

    visit "/proposals/#{ncr_proposal.id}"
    expect(page).to have_content('Modify Request')
  end

  it "does not show a edit link for another client" do
    ncr_proposal.client_data = nil
    ncr_proposal.save()
    visit "/proposals/#{ncr_proposal.id}"
    expect(page).not_to have_content('Modify Request')
  end

  it "does not show a edit link for non requester" do
    ncr_proposal.set_requester(FactoryGirl.create(:user))
    visit "/proposals/#{ncr_proposal.id}"
    expect(page).not_to have_content('Modify Request')
  end

  it "doesn't show a edit/cancel/add observer link from a cancelled proposal" do
    visit "/proposals/#{ncr_proposal.id}"
    expect(page).to have_content('Cancel my request')
    ncr_proposal.update_attribute(:status, 'cancelled')
    visit "/proposals/#{ncr_proposal.id}"
    expect(page).not_to have_content('Modify Request')
  end
end
