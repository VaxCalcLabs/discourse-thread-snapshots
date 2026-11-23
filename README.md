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
3. Copy the link. It looks like `/thread-snapshots/<token>`.
4. Anyone with the link can read that frozen copy, including visitors who are not logged in, even when the forum requires login everywhere else.
5. Revoke it from the dialog that shows the link. Staff can also list and delete snapshots over HTTP:

```
GET    /thread-snapshots.json
POST   /thread-snapshots.json          { "topic_id": 123 }
DELETE /thread-snapshots/:id.json
```

`POST` and `DELETE` require a staff user who can see the personal message. `GET /thread-snapshots/<token>` is the public page. Unknown tokens and expired tokens respond with 404.

A daily job deletes expired rows. The public page checks the expiry time itself, so a snapshot stops working as soon as it expires, even if the job has not run yet.

Only regular posts are copied: cooked HTML, username, display name, avatar URL, and the post time, plus the topic title. Whispers, small action posts, and moderator action posts are left out. Avatar images use the forum's normal avatar routes, which stay available when login is required.

## Tests

From a development checkout, with this plugin in `plugins/discourse-thread-snapshots`:

```
bin/rspec plugins/discourse-thread-snapshots/spec
```

## Compatibility

Built against the plugin APIs in current core: an isolated engine, `addTopicAdminMenuButton`, and skipping the login redirect on the public action. `required_version` is 3.3.0, which is when the topic admin menu button API was added. The share dialog passes already translated text to the dialog service used by current core.

## License

MIT. See `LICENSE`.
