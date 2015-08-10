describe "searching" do
  let(:user){ FactoryGirl.create(:user) }
  let!(:approver){ FactoryGirl.create(:user) }

  before do
    login_as(user)
  end

  it "displays relevant results" do
    proposals = 2.times.map do |i|
      wo = FactoryGirl.create(:ncr_work_order, project_title: "Work Order #{i}")
      wo.proposal.update(requester: user)
      wo.proposal
    end
    visit '/proposals'
    fill_in 'text', with: proposals.first.name
    click_button 'Search'

    expect(current_path).to eq('/proposals/query')
    expect(page).to have_content(proposals.first.public_identifier)
    expect(page).not_to have_content(proposals.last.name)
  end

  it "populates the search box on the results page" do
    visit '/proposals'
    fill_in 'text', with: 'foo'
    click_button 'Search'

    expect(current_path).to eq('/proposals/query')
    field = find_field('text')
    expect(field.value).to eq('foo')
  end

  it "links to the correct proposals" do
    proposals = (1..4).each do |i|
      wo = FactoryGirl.create(:ncr_work_order, project_title: "Project Number #{i}")
      wo.proposal.update_attributes(requester: user, id: i+1, public_id: i+1)
      wo.proposal
    end
    visit '/proposals'
    fill_in 'text', with: proposals.last.name
    click_button 'Search'
    click_on '4'  
    expect(current_path).to have_content('/proposals/4')
  end
end
