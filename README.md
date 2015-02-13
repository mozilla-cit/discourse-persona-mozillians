# Persona Login & Mozillians.org
*Persona login for Discourse (with some Mozillians magic sprinkled on top)*

**Mentor**: [Leo McArdle](https://mozillians.org/u/leo/)

**Good first bugs**: https://github.com/Mozilla-cIT/discourse-persona-mozillians/labels/good%20first%20bug

**Description**: The Persona login plugin allows a user to log in to Discourse with Mozilla Persona and pulls information about them from Mozillians.org into Discourse.

# Installation

Add the plugin's repo url to your container's `app.yml` file:

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - mkdir -p plugins
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/Mozilla-cIT/discourse-persona-mozillians.git
```

Rebuild the container:

```
cd /var/docker
git pull
./launcher rebuild app
```

For a standard installation, once Discourse has launched, add groups for users to be placed in (these are all optional - if you don't add the group, users simply won't be placed in them):
- `mozillians` (for everybody on mozillians.org)
- `mozillians_unvouched` (for unvouched users of mozillians.org)
- `mozillians_vouched` (for vouched users of mozillians.org)

Then, navigate to `/admin/site_settings/category/plugins`, setting:
- `mozillians_app_name` to the name of the app associated with your API key, and
- `mozillians_app_key` to your API key,
- before finally checking the `mozillians_enabled` checkbox.

You're all set! Now when users log in using Persona, they should be assigned to the groups you created based on their status on mozillians.org.