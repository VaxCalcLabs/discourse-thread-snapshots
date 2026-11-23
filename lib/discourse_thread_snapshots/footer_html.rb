# frozen_string_literal: true

require "sanitize"

module DiscourseThreadSnapshots
  module FooterHtml
    # Same Sanitize gem Discourse uses for oneboxes and other HTML, with a
    # smaller allowlist for the public page footer.
    CONFIG =
      Sanitize::Config.freeze_config(
        elements: %w[p small a strong em br],
        attributes: {
          "a" => ["href"],
        },
        protocols: {
          "a" => {
            "href" => ["http", "https", "mailto", :relative],
          },
        },
      )

    def self.sanitize(html)
      Sanitize.fragment(html.to_s, CONFIG).strip
    end
  end
end
