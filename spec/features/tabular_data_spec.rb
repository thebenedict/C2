describe "Tabular data sorting" do
  let(:user) { FactoryGirl.create(:user) }
  let!(:proposals) { 4.times.map { FactoryGirl.create(:proposal) } }
  let!(:cancelled) { 2.times.map { FactoryGirl.create(:proposal, status: 'cancelled') } }
  before :each do
    Proposal.all().each { |p| p.add_observer(user.email_address) }
    login_as(user)
  end

  def expect_order(element, proposals)
    content = element.text
    last_idx = content.index(proposals[0].public_identifier)
    proposals[1..-1].each do |proposal|
      idx = content.index(proposal.public_identifier)
      expect(idx).to be > last_idx
      last_idx = idx
    end
  end

  def tables
    page.all('.tabular-data')
  end

  context 'home page' do
    it 'begins sorted by -created_at' do
      visit '/proposals'

      within(tables[0]) do
        expect(find("th.desc")).to have_content "Submitted"
      end
      expect_order(tables[0], proposals.reverse)

      within(tables[1]) do
        expect(find("th.desc")).to have_content "Submitted"
      end
      expect_order(tables[1], cancelled.reverse)
    end

    it 'allows other titles to be clicked to resort' do
      proposals[0].requester.update(email_address: "bbb@bbb.gov")
      proposals[1].requester.update(email_address: "ccc@ccc.gov")
      proposals[2].requester.update(email_address: "aaa@aaa.gov")

      visit '/proposals'
      expect_order(tables[0], proposals.reverse)

      within(tables[0]) do
        click_on "Requester"
      end

      expect_order(tables[0], [proposals[2], proposals[0], proposals[1]])
    end

    it 'allows the user to click on a title again to change order' do
      visit '/proposals'
      expect_order(tables[0], proposals.reverse)

      within(tables[0]) do
        click_on 'Submitted'
      end

      expect_order(tables[0], proposals)
    end

    it 'does not allow clicks in one table to affect the order of the other' do
      visit '/proposals'
      expect_order(tables[1], cancelled.reverse)

      within(tables[0]) do
        click_on 'Submitted'
      end

      expect_order(tables[1], cancelled.reverse)
    end
  end

  context 'search' do
    it 'does not allows titles to be clicked to re-sort' do
      visit '/proposals/query?text=1'
      within(tables[0]) do
        expect(page).not_to have_selector("th a")
      end
    end
  end
end
