# discourse-thread-snapshots

A plugin that lets staff publish a frozen copy of a personal message thread. The copy is available at an unguessable link. Later replies and edits stay on the original thread and do not change the copy.

The public page is a separate HTML document. It does not load the forum application, header, menus, or sidebar. Links that were already inside posts are left unchanged.

## Install

Copy this directory into the forum's `plugins` directory as `discourse-thread-snapshots`.

From a development checkout:

```
cd plugins
git clone <repository-url> discourse-thread-snapshots
bin/rake db:migrate
```

Restart the application so the plugin and its routes load. In a container install, clone the repository into `plugins/discourse-thread-snapshots` and rebuild. Migrations run as part of that rebuild.

## Settings

Both settings are under Plugins.

| Setting | Default | Purpose |
| --- | --- | --- |
| `thread_snapshots_enabled` | on | Turns the plugin on or off. |
| `thread_snapshots_expiry_days` | 7 | How many days a new snapshot remains available. |

The expiry time is stored on the snapshot when it is created. Changing the setting does not extend snapshots that already exist.

## Usage

1. Open a personal message while signed in as a staff user who can see that message. Moderators need to be part of the conversation. Admins can open any personal message unless the forum is configured to hide secured content from admins.
2. Open the topic wrench menu and choose **Share snapshot**.
3. A window opens with the full link in a text field, the expiry in your local time, and buttons to copy the link, revoke it, or close the window. Earlier links for this message that have not expired are listed in the same window.
4. Anyone with the link can read that frozen copy, including visitors who are not logged in, even when the forum requires login everywhere else.
5. Staff can also list and delete snapshots over HTTP:

```
GET    /thread-snapshots.json
GET    /thread-snapshots.json?topic_id=123
POST   /thread-snapshots.json          { "topic_id": 123 }
DELETE /thread-snapshots/:id.json
```

`POST`, `GET` (the JSON list), and `DELETE` require a staff user. The list only includes unexpired snapshots for personal messages that the staff user can see. `topic_id` limits the list to one topic; a missing topic, or a topic the user cannot see, responds with 404. `GET /thread-snapshots/<token>` is the public page. New tokens are 32 hex characters. Tokens created earlier are 64 hex characters and still open. Unknown tokens and expired tokens respond with 404.

A daily job deletes expired rows. The public page checks the expiry time itself, so a snapshot stops working as soon as it expires, even if the job has not run yet.

Only regular posts are copied: cooked HTML, username, display name, avatar URL, and the post time, plus the topic title. Whispers, small action posts, and moderator action posts are left out. Avatar images use the forum's normal avatar routes, which stay available when login is required.

## Tests

From a development checkout, with this plugin in `plugins/discourse-thread-snapshots`:

```
bin/rspec plugins/discourse-thread-snapshots/spec
```

## Compatibility

Built against the plugin APIs in current core: an isolated engine, `addTopicAdminMenuButton`, the modal service, and skipping the login redirect on the public action. The share window is a Glimmer modal imported from `discourse/components/d-modal`, which current core resolves to the UI kit modal. `required_version` is 3.3.0, which is when the topic admin menu button API was added.

## License

MIT. See `LICENSE`.
