# frozen_string_literal: true

DiscourseThreadSnapshots::Engine.routes.draw do
  post "/thread-snapshots" => "thread_snapshots#create"
  get "/thread-snapshots" => "thread_snapshots#index"
  delete "/thread-snapshots/:id" => "thread_snapshots#destroy", :constraints => { id: /\d+/ }
  get "/thread-snapshots/:token" => "thread_snapshots#show",
      :constraints => {
        token: /[a-f0-9]{32}([a-f0-9]{32})?/,
      }
end
