module WebsiteChecklist
  # The AI audit sheet on a site's page: the domain to audit, the latest audit, and its
  # recommendations beside the one picked (rec=), each to approve, change or reject.
  class ScansController < ApplicationController
    allow_staff only: :index
    require_permission :manage_websites, only: :create
    agent_tool :show_website_ai_audit, on: :index, title: "Show a website's AI audit",
      description: "The latest AI audit of a website: whether it's still running, what was found about the domain (DNS, registrar, pages, sitemap), and each recommendation for a checklist step (value, note, evidence, confidence) with whether it's pending, approved or rejected.",
      next_tools: %i[approve_website_recommendation reject_website_recommendation]
    agent_tool :audit_website_with_ai, on: :create, title: "Run an AI audit of a website",
      description: "Finds out what it can about the domain from outside (DNS, the registry, the pages, robots.txt, the sitemap) and has the install's AI recommend values for the checklist's steps, in the background (a minute or so). Needs the AI plugin on. Nothing is recorded until a person approves each recommendation.",
      params: { scan: { domain: "string!" } }, next_tools: %i[show_website_ai_audit]

    before_action :set_site

    def index
      @ai = Scan.ai_available_for?(@site)
      @scan = @site.scans.latest_first.includes(recommendations: :item).first
      @recommendation = @scan&.recommendations&.find { it.id.to_s == params[:rec].to_s } || @scan&.pending&.first || @scan&.recommendations&.first
    end

    def create
      return redirect_to(website_checklist_site_scans_path(@site), alert: "AI audits need the AI plugin on, set up and within its budget.") unless Scan.ai_available_for?(@site)

      scan = @site.scans.new(user: Current.user, domain: params.expect(scan: [ :domain ])[:domain])
      if scan.save
        scan.run_later
        redirect_to website_checklist_site_scans_path(@site), notice: "Auditing #{scan.domain}: it takes a minute or so."
      else
        redirect_to website_checklist_site_scans_path(@site), alert: scan.errors.full_messages.to_sentence
      end
    end
  end
end
