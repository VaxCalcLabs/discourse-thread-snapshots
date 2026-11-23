# frozen_string_literal: true

RSpec.describe Jobs::DeleteExpiredThreadSnapshots do
  fab!(:staff) { Fabricate(:moderator) }
  fab!(:topic) { Fabricate(:private_message_topic, user: staff) }

  it "deletes expired snapshots and keeps live ones" do
    expired = DiscourseThreadSnapshots::ThreadSnapshot.capture!(topic: topic, user: staff)
    live = DiscourseThreadSnapshots::ThreadSnapshot.capture!(topic: topic, user: staff)
    expired.update!(expires_at: 1.minute.ago)

    described_class.new.execute({})

    expect(DiscourseThreadSnapshots::ThreadSnapshot.exists?(expired.id)).to eq(false)
    expect(DiscourseThreadSnapshots::ThreadSnapshot.exists?(live.id)).to eq(true)
  end
end
