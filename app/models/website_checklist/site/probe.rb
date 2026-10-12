require "resolv"
require "ipaddr"
require "net/http"

module WebsiteChecklist
  # What can be found out about a domain from outside, without logging in anywhere: its DNS
  # records (who hosts DNS and email, SPF, DMARC, verifications), the registry's RDAP record (the
  # registrar, when it was registered and expires), how its addresses answer (HTTPS, www, where
  # they redirect), its home page (title, platform, Analytics and Tag Manager IDs, forms), and
  # robots.txt and the sitemap. Every part fails on its own, as an `error` in its facts. Files
  # worth keeping (the sitemap) are in `files`. Only public addresses are fetched.
  class Site::Probe
    TIMEOUT = 8
    MAX_BODY = 5.megabytes
    MAX_REDIRECTS = 5
    USER_AGENT = "Runwell website audit"

    class Refused < StandardError; end

    attr_reader :domain, :files

    # "https://www.Example.com/about" → "example.com"
    def self.normalize(input)
      text = input.to_s.strip.downcase
      host = URI.parse(text.include?("://") ? text : "https://#{text}").host.to_s
      host.delete_prefix("www.").presence || text
    rescue URI::InvalidURIError
      text
    end

    def initialize(domain)
      @domain = self.class.normalize(domain)
      @files = {}
    end

    def facts
      @facts ||= {
        "domain" => domain,
        "dns" => part { dns },
        "registration" => part { registration },
        "addresses" => part { addresses },
        "home_page" => part { home_page },
        "robots_txt" => part { robots },
        "sitemap" => part { sitemap }
      }
    end

    private
      def part
        yield
      rescue => error
        { "error" => "#{error.class.name.demodulize}: #{error.message}".truncate(200) }
      end

      # DNS --------------------------------------------------------------------------------------
      def dns
        Resolv::DNS.open do |resolver|
          resolver.timeouts = 4
          txt = records(resolver, domain, :TXT).map { it.strings.join }
          {
            "nameservers" => records(resolver, domain, :NS).map { it.name.to_s }.sort,
            "a" => records(resolver, domain, :A).map { it.address.to_s },
            "aaaa" => records(resolver, domain, :AAAA).map { it.address.to_s },
            "www_cname" => records(resolver, "www.#{domain}", :CNAME).map { it.name.to_s },
            "www_a" => records(resolver, "www.#{domain}", :A).map { it.address.to_s },
            "mx" => records(resolver, domain, :MX).sort_by(&:preference).map { "#{it.preference} #{it.exchange}" },
            "spf" => txt.grep(/\Av=spf1/i),
            "dmarc" => records(resolver, "_dmarc.#{domain}", :TXT).map { it.strings.join }.grep(/\Av=DMARC1/i),
            "verifications" => txt.grep(/verification|verify|site-verification|MS=|facebook-domain/i),
            "other_txt" => txt.grep_v(/\Av=spf1|verification|verify|MS=|facebook-domain/i).map { it.truncate(120) }
          }
        end
      end

      def records(resolver, name, type)
        resolver.getresources(name, Resolv::DNS::Resource::IN.const_get(type))
      end

      # The registry (RDAP, through rdap.org's redirect to the domain's registry) ------------------
      def registration
        response = follow("https://rdap.org/domain/#{domain}", accept: "application/rdap+json")
        raise "the registry answered #{response[:status] || response[:error]}" unless response[:status] == 200

        data = JSON.parse(response[:body])
        registrar = Array(data["entities"]).find { Array(it["roles"]).include?("registrar") }
        events = Array(data["events"]).to_h { [ it["eventAction"], it["eventDate"] ] }
        {
          "registrar" => vcard_name(registrar),
          "registrar_url" => Array(registrar&.dig("links")).map { it["href"] }.first,
          "registered" => events["registration"],
          "expires" => events["expiration"],
          "last_changed" => events["last changed"],
          "status" => data["status"],
          "nameservers" => Array(data["nameservers"]).map { it["ldhName"].to_s.downcase }.sort
        }
      end

      def vcard_name(entity)
        Array(entity&.dig("vcardArray", 1)).find { it.first == "fn" }&.last
      end

      # How https://, http:// and www answer, and where they end up ------------------------------
      def addresses
        %W[https://#{domain}/ https://www.#{domain}/ http://#{domain}/].to_h do |url|
          response = follow(url)
          [ url, { "status" => response[:status], "ends_at" => response[:url], "redirects" => response[:hops], "error" => response[:error] }.compact ]
        end
      end

      # The home page ----------------------------------------------------------------------------
      def home_page
        response = follow("https://#{domain}/")
        raise response[:error] || "answered #{response[:status]}" unless response[:status] == 200

        html = response[:body].to_s
        {
          "url" => response[:url],
          "title" => html[%r{<title[^>]*>(.*?)</title>}mi, 1]&.strip&.gsub(/\s+/, " ")&.truncate(150),
          "description" => meta(html, "description")&.truncate(200),
          "generator" => meta(html, "generator"),
          "platform_hints" => platform_hints(html, response[:headers]),
          "analytics_ids" => html.scan(/\b(G-[A-Z0-9]{6,12})\b/).flatten.uniq,
          "universal_analytics_ids" => html.scan(/\b(UA-\d{4,10}-\d{1,4})\b/).flatten.uniq,
          "tag_manager_ids" => html.scan(/\b(GTM-[A-Z0-9]{4,10})\b/).flatten.uniq,
          "google_site_verification" => meta(html, "google-site-verification"),
          "bing_verification" => meta(html, "msvalidate.01"),
          "forms" => html.scan(/<form\b[^>]*>/i).size,
          "form_posts_to" => html.scan(/<form\b[^>]*action=["']([^"']+)["']/i).flatten.map { URI.join(response[:url], it).host rescue it }.uniq.first(5),
          "email_addresses" => html.scan(/mailto:([^"'?\s>]+)/i).flatten.map(&:downcase).uniq.first(5),
          "server" => response[:headers]&.[]("server")
        }.compact
      end

      def meta(html, name)
        html[/<meta[^>]+name=["']#{Regexp.escape(name)}["'][^>]*content=["']([^"']*)["']/i, 1] ||
          html[/<meta[^>]+content=["']([^"']*)["'][^>]*name=["']#{Regexp.escape(name)}["']/i, 1]
      end

      def platform_hints(html, headers)
        hints = []
        hints << "WordPress" if html.include?("wp-content")
        hints << "Shopify" if html.include?("cdn.shopify.com")
        hints << "Wix" if html.include?("wixstatic.com")
        hints << "Squarespace" if html.include?("squarespace")
        hints << "Webflow" if html.include?("webflow")
        hints << "Astro" if html.include?("astro-island") || html.include?("/_astro/")
        hints << "Cloudflare" if headers&.[]("server").to_s.include?("cloudflare")
        hints << "Vercel" if headers&.[]("server").to_s.downcase.include?("vercel")
        hints << "Netlify" if headers&.[]("server").to_s.downcase.include?("netlify")
        hints
      end

      # robots.txt and the sitemap ------------------------------------------------------------------
      def robots
        @robots ||= begin
          response = follow("https://#{domain}/robots.txt")
          raise "answered #{response[:status] || response[:error]}" unless response[:status] == 200

          body = response[:body].to_s
          { "sitemaps" => body.scan(/^\s*sitemap:\s*(\S+)/i).flatten.uniq, "disallows_everything" => body.match?(%r{^\s*disallow:\s*/\s*$}i) }
        end
      end

      def sitemap
        candidates = (Array(facts_robots["sitemaps"]) + %W[https://#{domain}/sitemap.xml https://#{domain}/sitemap_index.xml]).uniq
        candidates.each do |url|
          response = follow(url)
          next unless response[:status] == 200 && response[:body].to_s.include?("<")

          body = response[:body].to_s
          @files["sitemap.xml"] = [ body, "application/xml" ]
          return { "url" => response[:url], "kind" => body.include?("<sitemapindex") ? "index" : "urlset",
                   "entries" => body.scan(/<loc>/i).size, "first_entries" => body.scan(%r{<loc>\s*(.*?)\s*</loc>}mi).flatten.first(10),
                   "kept_as_file" => "sitemap.xml" }
        end
        raise "none found at #{candidates.join(", ")}"
      end

      def facts_robots = (robots rescue {})

      # HTTP -------------------------------------------------------------------------------------
      def follow(url, accept: "*/*")
        hops = []
        MAX_REDIRECTS.times do
          response = fetch(url, accept: accept)
          return response.merge(url: url, hops: hops) unless response[:status].to_i.between?(300, 399) && response[:location]

          hops << "#{response[:status]} → #{response[:location]}"
          url = URI.join(url, response[:location]).to_s
        end
        { status: nil, url: url, hops: hops, error: "too many redirects" }
      rescue Refused, StandardError => error
        { status: nil, url: url, hops: hops, error: "#{error.class.name.demodulize}: #{error.message}".truncate(160) }
      end

      def fetch(url, accept: "*/*")
        uri = URI.parse(url)
        raise Refused, "only http and https" unless uri.is_a?(URI::HTTP)
        refuse_private!(uri.host)

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT, ssl_timeout: TIMEOUT) do |http|
          request = Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => accept)
          http.request(request) do |response|
            body = +""
            response.read_body { |chunk| body << chunk if body.bytesize < MAX_BODY }
            return { status: response.code.to_i, location: response["location"], body: body.byteslice(0, MAX_BODY).force_encoding(Encoding::UTF_8).scrub,
                     headers: response.each_header.to_h }
          end
        end
      end

      def refuse_private!(host)
        addresses = Resolv.getaddresses(host)
        raise Refused, "#{host} doesn't resolve" if addresses.empty?
        if addresses.any? { |address| ip = IPAddr.new(address); ip.private? || ip.loopback? || ip.link_local? || address.start_with?("0.") }
          raise Refused, "#{host} is a private address"
        end
      end
  end
end
