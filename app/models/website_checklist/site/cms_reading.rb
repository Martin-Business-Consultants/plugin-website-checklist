module WebsiteChecklist
  # What a site's CMS can tell about its checklist, read from the CMS's own API with the site's
  # token. Each part reads one endpoint; one that fails (a capability the token lacks, the Forms
  # plugin switched off) is noted in `errors` and the rest still count.
  #
  #   GET /api/settings/general        (settings:read)  site_base_url
  #   GET /api/settings/forms_settings (settings:read)  from_name, from_email
  #   GET /api/sitemap                                  site_base_url, count
  #   GET /api/forms?status=published  (forms:read)     each published form
  #   GET /api/forms/:slug/emails      (forms:read)     its notification and confirmation
  #   GET /api/webhooks                (webhooks:read)  the CMS's webhooks
  class Site::CmsReading
    # One item's facts. detected: false only makes sure the item exists (a form's test, which a
    # person records).
    Detection = Data.define(:key, :group, :subject, :title, :detail, :value, :problem, :href, :detected, :position)

    attr_reader :detections, :errors, :form_slugs

    def initialize(cms)
      @cms = cms
      @detections = []
      @errors = []
      @form_slugs = nil
      read
    end

    # Whether the forms were read, so per-form items stand in for the standard ones.
    def forms_read? = !form_slugs.nil?

    private
      attr_reader :cms

      def read
        general = part("General settings", missing: {}) { setting("general") }
        sender = part("Form email settings", missing: {}) { setting("forms_settings") }
        base_url = general&.dig("site_base_url").to_s.strip.chomp("/")

        detect_domain(base_url) if general
        detect_sender(sender, base_url) if sender
        part("Sitemap") { detect_sitemap(cms.get("/api/sitemap")) }
        part("Forms", missing: "the CMS has no forms (is its Forms plugin on?)") { detect_forms(cms.get("/api/forms?status=published")["forms"]) }
        part("Webhooks") { detect_webhooks(cms.get("/api/webhooks")["webhooks"]) }
      end

      # Runs a part; its failure becomes a line in `errors`. `missing:` is what a 404 means
      # instead: a setting nobody has saved yet reads as empty, a missing endpoint as a sentence.
      def part(name, missing: nil)
        yield
      rescue Cms::Error => error
        if error.status == 404 && missing.is_a?(Hash)
          missing
        else
          @errors << "#{name}: #{error.status == 404 && missing ? missing : error.message}"
          nil
        end
      end

      def setting(key) = cms.get("/api/settings/#{key}").dig("setting", "data") || {}

      def add(key:, group:, title:, value: nil, problem: nil, href: nil, subject: nil, detail: nil, detected: true, position: nil)
        @detections << Detection.new(key: key, group: group, subject: subject, title: title, detail: detail, value: value,
          problem: problem, href: href, detected: detected, position: position)
      end

      def detect_domain(base_url)
        problem = if base_url.blank? then "The CMS has no site base URL (Settings › General)."
        elsif !base_url.start_with?("https://") then "Not served over HTTPS."
        end
        add key: "launch:domain", group: "Launch", title: "Domain and HTTPS", value: base_url.presence || "Not set",
          problem: problem, href: cms.admin_url("/settings/general")
      end

      def detect_sender(settings, base_url)
        from_name = settings["from_name"].to_s.strip
        from_email = settings["from_email"].to_s.strip
        domain = URI.parse(base_url).host.to_s.delete_prefix("www.") rescue ""
        href = cms.admin_url("/settings/forms")

        add key: "sender:from_name", group: "Email sender", title: "From name", href: href,
          value: from_name.presence || "Not set (the CMS sends as “Forms”)",
          problem: ("Not set: form emails come from “Forms”." if from_name.blank?)
        add key: "sender:from_email", group: "Email sender", title: "From email", href: href,
          value: from_email.presence || "Not set (the CMS's own sender)",
          problem: if from_email.blank? then "Not set: form emails come from the CMS's own address."
                   elsif domain.present? && !from_email.downcase.end_with?("@#{domain}", ".#{domain}") then "Not on the site's domain (#{domain}): it may land in spam."
                   end
      end

      def detect_sitemap(sitemap)
        base_url = sitemap["site_base_url"].to_s.strip.chomp("/")
        count = sitemap["count"].to_i
        problem = if base_url.blank? then "The CMS has no site base URL, so the sitemap has no addresses."
        elsif count.zero? then "The sitemap lists nothing."
        end
        add key: "search:sitemap_url", group: "Search", title: "Sitemap URL", href: cms.admin_url("/sitemap"),
          value: base_url.present? ? "#{base_url}/sitemap.xml (#{count} #{"address".pluralize(count)})" : "Not set", problem: problem
      end

      def detect_forms(forms)
        forms = Array(forms)
        @form_slugs = forms.map { it["slug"] }
        forms.each_with_index do |form, index|
          emails = cms.get("/api/forms/#{form["slug"]}/emails")["emails"].to_a.index_by { it["kind"] }
          detect_form(form, emails, 1000 + index * 10)
        end
      end

      def detect_form(form, emails, position)
        slug, subject = form["slug"], form["title"]
        notification, confirmation = emails["notification"], emails["confirmation"]
        edit = ->(kind) { cms.admin_url("/forms/#{slug}/emails/#{kind}/edit") }
        recipients = notification.to_h["recipients"].to_s.split(/[,\n]/).map(&:strip).compact_blank

        add key: "forms:#{slug}:notification", group: "Forms", subject: subject, title: "Admin notification goes to (to and CCs)",
          detail: "Everyone who gets an email when someone sends this form. The CMS sends one email addressed to each of them.",
          value: notification&.dig("enabled") ? recipients.join(", ").presence || "Nobody" : "Off",
          problem: if !notification&.dig("enabled") then "Off: nobody is told when this form is sent."
                   elsif recipients.empty? then "On, with no recipients."
                   end,
          href: edit.("notification"), position: position
        add key: "forms:#{slug}:notification_wording", group: "Forms", subject: subject, title: "Admin notification wording",
          detail: "Its subject, and its content's fingerprint: a new fingerprint means the wording changed.",
          value: email_summary(notification), href: edit.("notification"), position: position + 1
        add key: "forms:#{slug}:confirmation", group: "Forms", subject: subject, title: "Confirmation email wording approved by client",
          detail: "What the person who wrote in gets back. Confirm it once the client has approved it.",
          value: email_summary(confirmation), href: edit.("confirmation"), position: position + 2
        add key: "forms:#{slug}:test", group: "Forms", subject: subject, title: "Test submission received",
          detail: "A test sent through the live form arrived: the notification at every address, and the confirmation.",
          detected: false, position: position + 3
        add key: "forms:#{slug}:webhook", group: "Webhooks", subject: subject, title: "Where the form posts",
          detail: "The address this form's submissions are posted to besides email, if any.",
          value: form["notify_webhook_url"].presence || "Nowhere (email only)", href: cms.admin_url("/forms/#{slug}/edit"), position: position
      end

      def email_summary(email)
        return "Not set up" if email.nil?
        return "Off" unless email["enabled"]

        "On: “#{email["subject"]}” (content #{email["content_digest"]})"
      end

      def detect_webhooks(webhooks)
        active = Array(webhooks).select { it["active"] }
        failing = active.select { it["last_status"].present? && it["last_status"] != "success" }
        add key: "webhooks:cms", group: "Webhooks", title: "CMS webhooks", href: cms.admin_url("/webhooks"),
          detail: "What the CMS calls when something happens, with the events each one hears.",
          value: active.map { "#{it["name"]} → #{it["url"]} (#{Array(it["events"]).join(", ")})" }.sort.join("\n").presence || "None",
          problem: ("Failing: #{failing.map { it["name"] }.to_sentence}." if failing.any?), position: 1
      end
  end
end
