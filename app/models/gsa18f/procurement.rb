module Gsa18f
  # Make sure all table names use 'gsa18f_XXX'
  def self.table_name_prefix
    'gsa18f_'
  end

  DATA = YAML.load_file("#{Rails.root}/config/data/18f.yaml")

  class Procurement < ActiveRecord::Base
    URGENCY = DATA['URGENCY']
    OFFICES = DATA['OFFICES']
    RECURRENCE = DATA['RECURRENCE']

    # must define before include PurchaseCardMixin
    def self.purchase_amount_column_name
      :cost_per_unit
    end

    include ProposalDelegate
    include PurchaseCardMixin

    validates :quantity, numericality: {
      greater_than_or_equal_to: 1
    }
    validates :product_name_and_description, presence: true

    after_create :add_approvals, :add_observers

    def add_approvals
      self.proposal.approver = User.for_email(Gsa18f::Procurement.approver_email)
    end

    def add_observers
      self.add_observer(Gsa18f::Procurement.purchaser_email)
    end

    # Ignore values in certain fields if they aren't relevant. May want to
    # split these into different models
    def self.relevant_fields(recurring)
      fields = [:office, :justification, :link_to_product, :quantity,
        :date_requested, :urgency, :additional_info, :cost_per_unit,
        :product_name_and_description, :recurring]
      if recurring
        fields += [:recurring_interval, :recurring_length]
      end
      fields
    end

    def relevant_fields
      Gsa18f::Procurement.relevant_fields(self.recurring)
    end

    def fields_for_display
      attributes = self.relevant_fields
      attributes.map! {|key| [Procurement.human_attribute_name(key), self[key]]}
      attributes.push(["Total Price", total_price])
    end

    def total_price
      (self.cost_per_unit * self.quantity) || 0.0
    end

    # may be replaced with paper-trail or similar at some point
    def version
      self.updated_at.to_i
    end

    def name
      self.product_name_and_description
    end

    def self.approver_email
      ENV.fetch('GSA18F_APPROVER_EMAIL')
    end

    def self.purchaser_email
      ENV.fetch('GSA18F_PURCHASER_EMAIL')
    end
  end
end
