describe "Add attachments" do
  let (:proposal) { FactoryGirl.create(:proposal, :with_parallel_approvers) }
  let! (:attachment) {
    FactoryGirl.create(:attachment, proposal: proposal,
                       user: proposal.requester) }

  before do
    login_as(proposal.requester)
  end

  it "is visible on a proposal" do
    visit proposal_path(proposal)
    expect(page).to have_content(attachment.file_file_name)
  end

  it "disables attachments if none is selected", js: true do
    skip 'this is failing in some test environments when all tests are run' #FIXME
    visit proposal_path(proposal)
    expect(find("#add_a_file").disabled?).to be(true)
    page.attach_file('attachment[file]', "#{Rails.root}/app/assets/images/bg_approved_status.gif")
    expect(find("#add_a_file").disabled?).to be(false)
  end

  it "uploader can delete" do
    visit proposal_path(proposal)
    expect(page).to have_button("Delete")
    click_on("Delete")
    expect(current_path).to eq("/proposals/#{proposal.id}")
    expect(page).to have_content("Deleted attachment")
    expect(Attachment.count).to be(0)
  end

  it "does not have a delete link for another" do
    login_as(proposal.approvers.first)
    visit proposal_path(proposal)
    expect(page).not_to have_button("Delete")
  end

  it "saves attachments submitted via the webform" do
    visit proposal_path(proposal)
    page.attach_file('attachment[file]', "#{Rails.root}/app/assets/images/bg_approved_status.gif")
    click_on "Attach a File"
    expect(proposal.attachments.length).to eq 2
    expect(proposal.attachments.last.file_file_name).to eq "bg_approved_status.gif"
  end

  it "emails everyone involved in the proposal" do
    expect(Dispatcher).to receive(:deliver_attachment_emails)
    proposal.add_observer("wiley-cat@some-cartoon-show.com")
    visit proposal_path(proposal)
    page.attach_file('attachment[file]', "#{Rails.root}/app/assets/images/bg_approved_status.gif")
    click_on "Attach a File"
  end
end
