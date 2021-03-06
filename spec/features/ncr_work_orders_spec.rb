describe "National Capital Region proposals" do
  around(:each) do |example|
    with_env_var('DISABLE_SANDBOX_WARNING', 'true') do
      example.run
    end
  end

  let!(:approver) { FactoryGirl.create(:user) }

  describe "creating a work order" do
    it "requires sign-in" do
      visit '/ncr/work_orders/new'
      expect(current_path).to eq('/')
      expect(page).to have_content("You need to sign in")
    end

    with_feature 'RESTRICT_ACCESS' do
      it "requires a GSA email address" do
        user = FactoryGirl.create(:user, email_address: 'intruder@some.com', client_slug: 'ncr')
        login_as(user)

        visit '/ncr/work_orders/new'

        expect(page.status_code).to eq(403)
        expect(page).to have_content("You must be logged in with a GSA email address")
      end
    end

    context "when signed in as the requester" do
      let(:requester) { FactoryGirl.create(:user, client_slug: 'ncr') }
      let(:ncr_helper_class) { Class.new { extend Ncr::WorkOrdersHelper } }

      before do
        login_as(requester)
      end

      describe "tiered approval uses Role-based Users" do
        it "saves a Proposal with the attributes" do
          expect(Dispatcher).to receive(:deliver_new_proposal_emails)

          visit '/ncr/work_orders/new'
          fill_in 'Project title', with: "buying stuff"
          fill_in 'Description', with: "desc content"
          choose 'BA80'
          fill_in 'RWA Number', with: 'F1234567'
          fill_in 'Vendor', with: 'ACME'
          fill_in 'Amount', with: 123.45
          check "I am going to be using direct pay for this transaction"
          select approver.email_address, from: 'approver_email'
          fill_in 'Building number', with: Ncr::BUILDING_NUMBERS[0]
          select Ncr::Organization.all[0], from: 'ncr_work_order_org_code'
          expect {
            click_on 'Submit for approval'
          }.to change { Proposal.count }.from(0).to(1)

          proposal = Proposal.last
          expect(proposal.public_id).to have_content("FY")
          expect(page).to have_content("Proposal submitted")
          expect(current_path).to eq("/proposals/#{proposal.id}")

          expect(proposal.name).to eq("buying stuff")
          expect(proposal.flow).to eq('linear')
          work_order = proposal.client_data
          expect(work_order.client).to eq('ncr')
          expect(work_order.expense_type).to eq('BA80')
          expect(work_order.vendor).to eq('ACME')
          expect(work_order.amount).to eq(123.45)
          expect(work_order.direct_pay).to eq(true)
          expect(work_order.building_number).to eq(Ncr::BUILDING_NUMBERS[0])
          expect(work_order.org_code).to eq(Ncr::Organization.all[0].to_s)
          expect(work_order.description).to eq('desc content')
          expect(proposal.requester).to eq(requester)
          expect(proposal.approvers.map(&:email_address)).to eq(
            [approver.email_address, Ncr::WorkOrder.ba61_tier1_budget_mailbox])
        end

        it "saves a BA60 Proposal with the attributes" do
          expect(Dispatcher).to receive(:deliver_new_proposal_emails)

          visit '/ncr/work_orders/new'
          fill_in 'Project title', with: "blue shells"
          fill_in 'Description', with: "desc content"
          choose 'BA60'
          fill_in 'Vendor', with: 'Yoshi'
          fill_in 'Amount', with: 123.45
          select approver.email_address, from: "Approving official's email address"
          fill_in 'Building number', with: Ncr::BUILDING_NUMBERS[0]
          select Ncr::Organization.all[0], :from => 'ncr_work_order_org_code'
          expect {
            click_on 'Submit for approval'
          }.to change { Proposal.count }.from(0).to(1)

          proposal = Proposal.last
          work_order = proposal.client_data
          expect(work_order.expense_type).to eq('BA60')
          expect(proposal.approvers.map(&:email_address)).to eq [
            approver.email_address,
            Ncr::WorkOrder.ba61_tier1_budget_mailbox,
            Ncr::WorkOrder.ba61_tier2_budget_mailbox
          ]
        end

        it "shows the radio button" do
          visit '/ncr/work_orders/new'
          expect(page).to have_content('BA60')
          expect(page).to have_content('BA61')
          expect(page).to have_content('BA80')
        end
      end

      it "defaults to no approver if there was no previous request" do
        visit '/ncr/work_orders/new'
        expect(find_field("Approving official's email address").value).to eq('')
      end

      it "defaults to the approver from the last request" do
        proposal = FactoryGirl.create(:proposal, :with_serial_approvers, requester: requester)
        visit '/ncr/work_orders/new'
        expect(find_field("Approving official's email address").value).to eq(
          proposal.approvers.first.email_address)
      end

      it "requires a project_title" do
        visit '/ncr/work_orders/new'
        expect {
          click_on 'Submit for approval'
        }.to_not change { Proposal.count }
        expect(page).to have_content("Project title can't be blank")
      end

      it "doesn't show the budget fields" do
        visit '/ncr/work_orders/new'
        expect(page).to_not have_field('CL number')
        expect(page).to_not have_field('Function code')
        expect(page).to_not have_field('SOC code')
      end

      it "doesn't save when the amount is too high" do
        visit '/ncr/work_orders/new'
        fill_in 'Project title', with: "buying stuff"
        choose 'BA80'
        fill_in 'Vendor', with: 'ACME'
        fill_in 'Amount', with: 10_000

        expect {
          click_on 'Submit for approval'
        }.to_not change { Proposal.count }

        expect(current_path).to eq('/ncr/work_orders')
        expect(page).to have_content("Amount must be less than or equal to $")
        # keeps the form values
        expect(find_field('Amount').value).to eq('10000')
      end

      it "preserve form values on submission error" do
        # make sure we have an existing work order so vendor dropdown is populated.
        work_order = FactoryGirl.create(:ncr_work_order, :with_approvers)

        expect(Proposal.count).to eq(1)
        expect(ncr_helper_class.vendor_options).to eq([work_order.vendor])

        visit '/ncr/work_orders/new'
        fill_in 'Project title', with: "buying stuff"
        choose 'BA80'
        fill_in 'Vendor', with: 'ACME'
        fill_in 'Amount', with: 10_000

        expect {
          click_on 'Submit for approval'
        }.to_not change { Proposal.count }

        # options do not change unless we pass in new explicitly, which the form should.
        expect(ncr_helper_class.vendor_options('zzbar')).to eq([work_order.vendor, 'zzbar'])

        # keeps the form values
        expect(find_field('Amount').value).to eq('10000')
        expect(find_field('Vendor').value).to eq('ACME')
        # since vendor is populated from local json array, make sure the array contains the submitted string,
        # even though db does not yet contain it.
        expect(JSON.parse(find_field('Vendor')['data-initial'])).to eq(['ACME', work_order.vendor])
      end

      it "includes has overwritten field names" do
        tier1_approver = Ncr::WorkOrder.ba80_budget_mailbox
        visit '/ncr/work_orders/new'
        fill_in 'Project title', with: "buying stuff"
        choose 'BA80'
        fill_in 'RWA Number', with: 'B9876543'
        fill_in 'Vendor', with: 'ACME'
        fill_in 'Amount', with: 123.45
        select approver.email_address, from: 'approver_email'
        fill_in 'Building number', with: Ncr::BUILDING_NUMBERS[0]
        select Ncr::Organization.all[0], from: 'ncr_work_order_org_code'
        click_on 'Submit for approval'
        expect(current_path).to eq("/proposals/#{Proposal.last.id}")
        expect(page).to have_content("RWA Number")
      end

      it "hides fields based on expense", js: true do
        visit '/ncr/work_orders/new'
        expect(page).to have_no_field("RWA Number")
        expect(page).to have_no_field("Work Order")
        expect(page).to have_no_field("emergency")
        choose 'BA61'
        expect(page).to have_no_field("RWA Number")
        expect(page).to have_no_field("Work Order")
        expect(page).to have_field("emergency")
        expect(find_field("emergency", visible: false)).to be_visible
        choose 'BA80'
        expect(page).to have_field("RWA Number")
        expect(page).to have_field("Work Order")
        expect(page).to have_no_field("emergency")
        expect(find_field("RWA Number")).to be_visible
      end

      it "allows attachments to be added during intake without JS" do
        visit '/ncr/work_orders/new'
        expect(page).to have_content("Attachments")
        expect(page).not_to have_selector(".js-am-minus")
        expect(page).not_to have_selector(".js-am-plus")
        expect(page).to have_selector("input[type=file]", count: 10)
      end

      it "allows attachments to be added during intake with JS", :js => true do
        visit '/ncr/work_orders/new'
        expect(page).to have_content("Attachments")
        first_minus = find(".js-am-minus")
        first_plus = find(".js-am-plus")
        expect(first_minus).to be_visible
        expect(first_plus).to be_visible
        expect(first_minus).to be_disabled
        expect(find("input[type=file]")[:name]).to eq("attachments[]")
        first_plus.click    # Adds one row
        expect(page).to have_selector(".js-am-minus", count: 2)
        expect(page).to have_selector(".js-am-plus", count: 2)
        expect(page).to have_selector("input[type=file]", count: 2)
      end

      it "includes an initial list of buildings", :js => true do
        visit '/ncr/work_orders/new'
        option = Ncr::BUILDING_NUMBERS.shuffle[0]

        expect(page).not_to have_selector(".option[data-value='#{option}']")

        find("input[aria-label='Building number']").native.send_keys(option)
        expect(page).to have_selector("div.option[data-value='#{option}']")
      end

      it "does not include custom buildings initially", :js => true do
        visit '/ncr/work_orders/new'
        find("input[aria-label='Building number']").native.send_keys("BillDing")
        expect(page).not_to have_selector("div.option[data-value='BillDing']")
      end

      it "includes previously entered buildings, too", :js => true do
        FactoryGirl.create(:ncr_work_order, building_number: "BillDing")
        visit '/ncr/work_orders/new'
        find("input[aria-label='Building number']").native.send_keys("BillDing")
        expect(page).to have_selector("div.option[data-value='BillDing']")
      end

      context "selected common values on proposal page" do
        before do
          visit '/ncr/work_orders/new'

          fill_in 'Project title', with: "buying stuff"
          fill_in 'Vendor', with: 'ACME'
          fill_in 'Amount', with: 123.45
          select approver.email_address, from: 'approver_email'
          fill_in 'Building number', with: Ncr::BUILDING_NUMBERS[0]
          select Ncr::Organization.all[0], from: 'ncr_work_order_org_code'
        end

        it "approves emergencies" do
          choose 'BA61'
          check "This request was an emergency and I received a verbal Notice to Proceed (NTP)"
          expect {
            click_on 'Submit for approval'
          }.to change { Proposal.count }.from(0).to(1)

          proposal = Proposal.last
          expect(page).to have_content("Proposal submitted")
          expect(current_path).to eq("/proposals/#{proposal.id}")
          expect(page).to have_content("0 of 0 approved")

          expect(proposal.client_data.emergency).to eq(true)
          expect(proposal.approved?).to eq(true)
        end

        it "does not set emergencies if form type changes" do
          choose 'BA61'
          check "This request was an emergency and I received a verbal Notice to Proceed (NTP)"
          choose 'BA80'
          fill_in 'RWA Number', with: 'R9876543'
          expect {
            click_on 'Submit for approval'
          }.to change { Proposal.count }.from(0).to(1)

          proposal = Proposal.last
          expect(page).to have_content("Proposal submitted")
          expect(current_path).to eq("/proposals/#{proposal.id}")

          expect(proposal.client_data.emergency).to eq(false)
          expect(proposal.approved?).to eq(false)
        end
      end

      it "does not disable the emergency field" do
        visit '/ncr/work_orders/new'
        expect(find_field('emergency')).not_to be_disabled
      end
    end
  end

  describe "approving a work order" do
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

  describe "viewing a work order" do
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
      ncr_proposal.set_requester(FactoryGirl.create(:user, client_slug: 'ncr'))
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

  describe "editing a work order" do
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
        select approver.email_address, from: "Approving official's email address"
        click_on 'Update'
        proposal = Proposal.last
        
        expect(proposal.approvers.first.email_address).to eq (approver.email_address)
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

      describe "tiered approval uses Role-based Users" do
        it "allows you to change the expense type" do
          visit "/ncr/work_orders/#{work_order.id}/edit"
          choose 'BA80'
          fill_in 'RWA Number', with:'a1234567'
          click_on 'Update'
          proposal = Proposal.last
          expect(proposal.approvers.length).to eq(2)
          expect(proposal.approvers.second.email_address).to eq(Ncr::WorkOrder.ba61_tier1_budget_mailbox)
        end
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
      stranger = FactoryGirl.create(:user, client_slug: 'ncr')
      login_as(stranger)

      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(current_path).to eq("/ncr/work_orders/new")
      expect(page).to have_content("You must be the requester, approver, or observer")
    end
  end

  describe "delegate on a work order" do
    let(:work_order) { FactoryGirl.create(:ncr_work_order, description: 'test') }
    let(:proposal) { work_order.proposal }
    let(:delegate) { FactoryGirl.create(:user, client_slug: 'ncr') }

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
