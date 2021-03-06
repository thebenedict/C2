class RolesConversion
  def self.exists_with_role_slug?(role, slug)
    the_role = role.is_a?(Role) ? role : Role.find_by_name(role)
    return false unless the_role
    the_role.users.exists?(client_slug: slug)
  end

  # find_or_create a User with particular email, role and slug
  # NOTE the triple is considered unique, so if a user with the role+slug
  # is found with another email address, no change is made and nil is returned.
  def self.with_email_role_slug!(email, role, slug)
    user = User.for_email(email)
    # if no change necessary, return early (idempotent)
    if user.client_slug == slug && user.has_role?(role)
      return user
    end

    # unique triple -- check if any other user with role+slug already exists
    return if self.exists_with_role_slug?(role, slug)

    user.client_slug = slug
    user.add_role(role)
    user.save!
    user
  end

  def self.ncr_budget_approvers
    self.ba61_tier1_budget_approver
    self.ba61_tier2_budget_approver
    self.ba80_budget_approver
    self.ool_ba80_budget_approver
  end

  def self.ba61_tier1_budget_approver
    self.with_email_role_slug!(
      ENV['NCR_BA61_TIER1_BUDGET_MAILBOX'] || 'communicart.budget.approver@gmail.com',
      'BA61_tier1_budget_approver',
      'ncr'
    )
  end

  def self.ba61_tier2_budget_approver
    self.with_email_role_slug!(
      ENV['NCR_BA61_TIER2_BUDGET_MAILBOX'] || 'communicart.ofm.approver@gmail.com',
      'BA61_tier2_budget_approver',
      'ncr'
    )
  end

  def self.ba80_budget_approver
    self.with_email_role_slug!(
      ENV['NCR_BA80_BUDGET_MAILBOX'] || 'communicart.budget.approver@gmail.com',
      'BA80_budget_approver',
      'ncr'
    )
  end

  def self.ool_ba80_budget_approver
    self.with_email_role_slug!(
      ENV['NCR_OOL_BA80_BUDGET_MAILBOX'] || 'communicart.budget.approver@gmail.com',
      'OOL_BA80_budget_approver',
      'ncr'
    )
  end
end
