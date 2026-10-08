module WebsiteChecklist
  # The checklist every website starts with. Keys are fixed once used: the CMS fills the ones it
  # can tell by key (Site::Syncable), and a site run by it gets a set of Forms items per form.
  module Site::Defaults
    ITEMS = [
      { key: "sender:from_name", group: "Email sender", title: "From name",
        detail: "The name form emails come from, as people see it in their inbox." },
      { key: "sender:from_email", group: "Email sender", title: "From email",
        detail: "The address form emails come from: one on the site's own domain gets delivered." },
      { key: "sender:dns", group: "Email sender", title: "SPF, DKIM and DMARC set for the sender's domain",
        detail: "Without them, form emails land in spam. Record what was set, and where the DNS lives." },
      { key: "forms:any:notification", group: "Forms", title: "Admin notification goes to (to and CCs)",
        detail: "Everyone who gets an email when someone sends a form, as the client asked." },
      { key: "forms:any:notification_wording", group: "Forms", title: "Admin notification wording",
        detail: "The subject and what the notification says." },
      { key: "forms:any:confirmation", group: "Forms", title: "Confirmation email wording approved by client",
        detail: "What the person who wrote in gets back. Record when the client approved it." },
      { key: "forms:any:test", group: "Forms", title: "Test submission received",
        detail: "A test sent through the live form arrived: the notification at every address, and the confirmation." },
      { key: "webhooks:integrations", group: "Webhooks", title: "Webhooks and integrations the forms post to",
        detail: "Where submissions go besides email (a CRM, Zapier, a spreadsheet), and that they arrive." },
      { key: "search:sitemap_url", group: "Search", title: "Sitemap URL",
        detail: "The address of the site's sitemap.xml." },
      { key: "search:google", group: "Search", title: "Sitemap submitted to Google Search Console",
        detail: "Record the Search Console property and the date it was submitted." },
      { key: "search:bing", group: "Search", title: "Sitemap submitted to Bing Webmaster Tools",
        detail: "Bing also feeds DuckDuckGo, Yahoo and ChatGPT search." },
      { key: "search:analytics", group: "Search", title: "Analytics receiving data",
        detail: "Which analytics, which property, and that visits show up." },
      { key: "launch:domain", group: "Launch", title: "Domain and HTTPS",
        detail: "The live address, served over HTTPS, with www and the bare domain going to one of them." },
      { key: "launch:signoff", group: "Launch", title: "Client signed off",
        detail: "Who approved the site, and when." }
    ].freeze
  end
end
