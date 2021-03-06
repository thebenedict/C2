describe Approvals::Parallel do
  let (:proposal) { FactoryGirl.create(:proposal) }

  it 'allows approvals in any order' do
    first = FactoryGirl.build(:approval, proposal: nil)
    second = FactoryGirl.build(:approval, proposal: nil)
    third = FactoryGirl.build(:approval, proposal: nil)
    proposal.root_approval = Approvals::Parallel.new(child_approvals: [first, second, third])

    expect(proposal.root_approval.reload.status).to eq('actionable')
    expect(first.reload.status).to eq('actionable')
    expect(second.reload.status).to eq('actionable')
    expect(third.reload.status).to eq('actionable')

    first.approve!
    expect(proposal.root_approval.reload.status).to eq('actionable')
    expect(first.reload.status).to eq('approved')
    expect(second.reload.status).to eq('actionable')
    expect(third.reload.status).to eq('actionable')

    third.approve!
    expect(proposal.root_approval.reload.status).to eq('actionable')
    expect(first.reload.status).to eq('approved')
    expect(second.reload.status).to eq('actionable')
    expect(third.reload.status).to eq('approved')

    second.approve!
    expect(proposal.root_approval.reload.status).to eq('approved')
    expect(first.reload.status).to eq('approved')
    expect(second.reload.status).to eq('approved')
    expect(third.reload.status).to eq('approved')
  end

  it 'can be used for disjunctions (ORs)' do
    first = FactoryGirl.build(:approval, proposal: nil)
    second = FactoryGirl.build(:approval, proposal: nil)
    third = FactoryGirl.build(:approval, proposal: nil)
    proposal.root_approval = Approvals::Parallel.new(min_children_needed: 2, child_approvals: [first, second, third])

    first.reload.approve!
    expect(proposal.root_approval.reload.status).to eq('actionable')
    expect(first.reload.status).to eq('approved')
    expect(second.reload.status).to eq('actionable')
    expect(third.reload.status).to eq('actionable')

    third.approve!
    expect(proposal.root_approval.reload.status).to eq('approved')
    expect(first.reload.status).to eq('approved')
    expect(second.reload.status).to eq('actionable')
    expect(third.reload.status).to eq('approved')

    second.approve!
    expect(proposal.root_approval.reload.status).to eq('approved')
    expect(first.reload.status).to eq('approved')
    expect(second.reload.status).to eq('approved')
    expect(third.reload.status).to eq('approved')
  end
end
