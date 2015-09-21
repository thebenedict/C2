describe "editing NCR work orders" do
  around(:each) do |example|
    with_env_var('DISABLE_SANDBOX_WARNING', 'true') do
      example.run
    end
  end

  let!(:approver) { FactoryGirl.create(:user) }
  let(:work_order) { FactoryGirl.create(:ncr_work_order, description: 'test') }
  let(:ncr_proposal) { work_order.proposal }

  describe "when logged in as the requester" do
    before do
      work_order.setup_approvals_and_observers('approver@example.com')
      login_as(work_order.requester)
    end

    it "can be edited if pending" do
      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(find_field("ncr_work_order_building_number").value).to eq(
        Ncr::BUILDING_NUMBERS[0])
      fill_in 'Vendor', with: 'New ACME'
      click_on 'Update'
      expect(current_path).to eq("/proposals/#{ncr_proposal.id}")
      expect(page).to have_content("New ACME")
      expect(page).to have_content("modified")
      # Verify it is actually saved
      work_order.reload
      expect(work_order.vendor).to eq("New ACME")
    end

    it "creates a special comment when editing" do
      visit "/ncr/work_orders/#{work_order.id}/edit"
      fill_in 'Vendor', with: "New Test Vendor"
      fill_in 'Description', with: "New Description"
      click_on 'Update'

      expect(page).to have_content("Request modified by")
      expect(page).to have_content("Description was changed from test to New Description")
      expect(page).to have_content("Vendor was changed from Some Vend to New Test Vendor")
    end

    it "notifies observers of changes" do
      work_order.add_observer("observer@observers.com")
      visit "/ncr/work_orders/#{work_order.id}/edit"
      fill_in 'Description', with: "Observer changes"
      click_on 'Update'

      expect(deliveries.length).to eq(2)
      expect(deliveries.last).to have_content('observer@observers.com')
    end

    it "does not resave unchanged requests" do
      visit "/ncr/work_orders/#{work_order.id}/edit"
      click_on 'Update'

      expect(current_path).to eq("/proposals/#{work_order.proposal.id}")
      expect(page).to have_content("No changes were made to the request")
      expect(deliveries.length).to eq(0)
    end

    it "allows you to change the approving official" do
      old_approver = ncr_proposal.approvers.first
      expect(Dispatcher).to receive(:on_approver_removal).with(ncr_proposal, [old_approver])
      visit "/ncr/work_orders/#{work_order.id}/edit"
      select "liono0@some-cartoon-show.com", from: "Approving official's email address"
      click_on 'Update'
      proposal = Proposal.last

      expect(proposal.approvers.first.email_address).to eq ("liono0@some-cartoon-show.com")
      expect(proposal.individual_approvals.first.actionable?).to eq (true)
    end

    describe "switching to WHSC" do
      before do
        work_order.individual_approvals.first.approve!
      end

      context "as a BA61" do
        it "reassigns the approvers properly" do
          expect(work_order.organization).to_not be_whsc
          approving_official = work_order.approving_official

          visit "/ncr/work_orders/#{work_order.id}/edit"
          select Ncr::Organization::WHSC_CODE, from: "Org code"
          click_on 'Update'

          ncr_proposal.reload
          work_order.reload

          expect(ncr_proposal.approvers.map(&:email_address)).to eq([
            approving_official.email_address,
            Ncr::WorkOrder.ba61_tier2_budget_mailbox
          ])
          expect(work_order.individual_approvals.first).to be_approved
          expect(work_order.individual_approvals.second).to be_actionable
        end

        it "notifies the removed approver" do
          expect(work_order.organization).to_not be_whsc
          deliveries.clear

          visit "/ncr/work_orders/#{work_order.id}/edit"
          select Ncr::Organization::WHSC_CODE, from: "Org code"
          click_on 'Update'

          expect(deliveries.length).to be 3
          removed, approver1, approver2 = deliveries
          expect(removed.to).to eq([Ncr::WorkOrder.ba61_tier1_budget_mailbox])
          expect(removed.html_part.body).to include "removed"

          expect(approver1.to).to eq([work_order.approvers.first.email_address])
          expect(approver1.html_part.body).not_to include "removed"
          expect(approver2.to).to eq([Ncr::WorkOrder.ba61_tier2_budget_mailbox])
          expect(approver2.html_part.body).not_to include "removed"
        end
      end

      context "as a BA80" do
        let(:work_order) { FactoryGirl.create(:ncr_work_order, expense_type: 'BA80') }

        it "reassigns the approvers properly" do
          expect(work_order.organization).to_not be_whsc
          approving_official = work_order.approving_official

          visit "/ncr/work_orders/#{work_order.id}/edit"
          choose 'BA61'
          select Ncr::Organization::WHSC_CODE, from: "Org code"
          click_on 'Update'

          ncr_proposal.reload
          work_order.reload

          expect(ncr_proposal.approvers.map(&:email_address)).to eq([
            approving_official.email_address,
            Ncr::WorkOrder.ba61_tier2_budget_mailbox
          ])
          expect(work_order.individual_approvals.first).to be_approved
        end
      end
    end

    with_env_var('NCR_BA80_BUDGET_MAILBOX', 'ba80@example.gov') do
      it "allows you to change the expense type" do
        visit "/ncr/work_orders/#{work_order.id}/edit"
        choose 'BA80'
        fill_in 'RWA Number', with:'a1234567'
        click_on 'Update'
        proposal = Proposal.last
        expect(proposal.approvers.length).to eq(2)
        expect(proposal.approvers.second.email_address).to eq('ba80@example.gov')
      end
    end

    with_env_vars(NCR_BA61_TIER1_BUDGET_MAILBOX: 'foo@example.gov', NCR_BA61_TIER2_BUDGET_MAILBOX: 'bar@example.gov') do
      it "doesn't change approving list when delegated" do
        proposal = Proposal.last
        approval = proposal.individual_approvals.first
        approval.approve!
        approval = proposal.individual_approvals.second
        user = approval.user
        delegate = User.new(email_address:'delegate@example.com')
        delegate.save
        user.add_delegate(delegate)
        approval.update_attributes!(user: delegate)
        visit "/ncr/work_orders/#{work_order.id}/edit"
        fill_in 'Description', with:"New Description that shouldn't change the approver list"
        click_on 'Update'

        proposal.reload
        second_approver = proposal.approvers.second.email_address
        expect(second_approver).to eq('delegate@example.com')
        expect(proposal.individual_approvals.length).to eq(3)
      end
    end

    it "has 'Discard Changes' link" do
      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(page).to have_content("Discard Changes")
      click_on "Discard Changes"
      expect(current_path).to eq("/proposals/#{work_order.proposal.id}")
    end

    it "has a disabled field if first approval is done" do
      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(find("[name=approver_email]")["disabled"]).to be_nil
      work_order.individual_approvals.first.approve!
      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(find("[name=approver_email]")["disabled"]).to eq("disabled")
      # And we can still submit
      fill_in 'Vendor', with: 'New ACME'
      click_on 'Update'
      expect(current_path).to eq("/proposals/#{ncr_proposal.id}")
      # Verify it is actually saved
      work_order.reload
      expect(work_order.vendor).to eq("New ACME")
    end

    it "can be edited if approved" do
      ncr_proposal.update_attributes(status: 'approved')  # avoid workflow

      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(current_path).to eq("/ncr/work_orders/#{work_order.id}/edit")
    end

    it "provides the previous building when editing", :js => true do
      work_order.update(building_number: "BillDing, street")
      visit "/ncr/work_orders/#{work_order.id}/edit"
      click_on "Update"
      expect(current_path).to eq("/proposals/#{ncr_proposal.id}")
      expect(work_order.reload.building_number).to eq("BillDing, street")
    end

    it "allows the user to edit the budget-related fields" do
      visit "/ncr/work_orders/#{work_order.id}/edit"

      fill_in 'CL number', with: 'CL1234567'
      fill_in 'Function code', with: 'PG123'
      fill_in 'Object field / SOC code', with: '789'
      click_on 'Update'

      work_order.reload
      expect(work_order.cl_number).to eq('CL1234567')
      expect(work_order.function_code).to eq('PG123')
      expect(work_order.soc_code).to eq('789')
    end

    it "disables the emergency field" do
      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(find_field('emergency', disabled: true)).to be_disabled
    end
  end

  it "keeps track of the modification when edited by an approver" do
    work_order.setup_approvals_and_observers('approver@example.com')
    approver = ncr_proposal.approvers.last
    login_as(approver)

    visit "/ncr/work_orders/#{work_order.id}/edit"
    fill_in 'CL number', with: 'CL1234567'
    click_on 'Update'

    ncr_proposal.reload
    update_comments = ncr_proposal.comments.update_comments
    expect(update_comments.count).to eq(1)
    # properly attributed
    update_comment = update_comments.first
    expect(update_comment.user).to eq(approver)
    # properly tracked
    expect(update_comment.comment_text).to include("CL number")
  end

  it "cannot be edited by someone other than the requester" do
    stranger = FactoryGirl.create(:user)
    login_as(stranger)

    visit "/ncr/work_orders/#{work_order.id}/edit"
    expect(current_path).to eq("/ncr/work_orders/new")
    expect(page).to have_content("You must be the requester, approver, or observer")
  end
end
