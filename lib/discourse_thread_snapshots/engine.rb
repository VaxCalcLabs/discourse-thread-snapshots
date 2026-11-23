# frozen_string_literal: true

module ::DiscourseThreadSnapshots
  class Engine < ::Rails::Engine
    engine_name "discourse_thread_snapshots"
    isolate_namespace DiscourseThreadSnapshots
  end
end
