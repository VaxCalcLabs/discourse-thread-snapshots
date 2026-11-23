# frozen_string_literal: true

# name: discourse-thread-snapshots
# about: Share a frozen copy of a personal message thread at an unguessable public link.
# version: 0.1.0
# authors: Contributors
# required_version: 3.3.0

enabled_site_setting :thread_snapshots_enabled

register_svg_icon "link"

module ::DiscourseThreadSnapshots
  PLUGIN_NAME = "discourse-thread-snapshots"
end

require_relative "lib/discourse_thread_snapshots/engine"

after_initialize do
  require_relative "jobs/scheduled/delete_expired_thread_snapshots"

  Discourse::Application.routes.prepend { mount ::DiscourseThreadSnapshots::Engine, at: "/" }
end
