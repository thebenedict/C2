class ReportMailer < ApplicationMailer
  add_template_helper ReportHelper

  def budget_status
    to_email = ENV.fetch('BUDGET_REPORT_RECIPIENT')
    date = Time.now.utc.strftime("%a %m/%d/%y (%Z)")

    build_attachments

    mail(
      to: to_email,
      subject: "C2: Daily Budget report for #{date}",
      from: self.sender_email
    )
  end

  private

  def csv_reports
    { 'approved-ba60-week' => Ncr::Reporter.ba60_proposals,
      'approved-ba61-week' => Ncr::Reporter.ba61_proposals,
      'approved-ba80-week' => Ncr::Reporter.ba80_proposals,
      'pending-at-approving-official' => Ncr::Reporter.proposals_pending_approving_official,
      'pending-at-budget' => Ncr::Reporter.proposals_pending_budget,
      'pending-at-tier-one-approval' => Ncr::Reporter.proposals_tier_one_pending,
    }
  end

  def build_attachments
    date = Time.now.utc.strftime('%Y-%m-%d')
    csv_reports.each do |name, records|
      attachments[name + '-' + date + '.csv'] = Ncr::Reporter.as_csv(records)
    end
  end
end
