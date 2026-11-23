# frozen_string_literal: true

module DiscourseThreadSnapshots
  class ThreadSnapshotsController < ::ApplicationController
    requires_plugin DiscourseThreadSnapshots::PLUGIN_NAME

    # The public page is a full document for anonymous visitors, including
    # when the rest of the forum requires a login.
    skip_before_action :redirect_to_login_if_required,
                       :check_xhr,
                       :preload_json,
                       :redirect_to_profile_if_required,
                       only: [:show],
                       raise: false

    before_action :ensure_logged_in, except: [:show]
    before_action :ensure_staff, except: [:show]

    def create
      topic = Topic.find_by(id: params[:topic_id])
      # Same response for a missing topic and a topic this staff user cannot see.
      raise Discourse::NotFound if topic.nil? || !guardian.can_see?(topic)

      unless topic.private_message?
        raise Discourse::InvalidAccess.new(I18n.t("thread_snapshots.not_personal_message"))
      end

      snapshot = ThreadSnapshot.capture!(topic: topic, user: current_user)
      render json: snapshot.as_staff_json
    end

    def index
      snapshots = ThreadSnapshot.order(created_at: :desc).limit(100)
      render json: { thread_snapshots: snapshots.map(&:as_staff_json) }
    end

    def destroy
      snapshot = ThreadSnapshot.find_by(id: params[:id])
      raise Discourse::NotFound if snapshot.nil?

      snapshot.destroy!
      render json: success_json
    end

    def show
      response.headers["Cache-Control"] = "private, no-store"

      snapshot = ThreadSnapshot.find_by(token: params[:token])
      if snapshot.nil? || snapshot.expired?
        render plain: I18n.t("thread_snapshots.not_found"), status: :not_found
        return
      end

      @snapshot = snapshot
      render :show, layout: false
    end
  end
end
