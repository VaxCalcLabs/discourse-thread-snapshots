# frozen_string_literal: true

module ::Jobs
  class DeleteExpiredThreadSnapshots < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      DiscourseThreadSnapshots::ThreadSnapshot.expired.delete_all
    end
  end
end
