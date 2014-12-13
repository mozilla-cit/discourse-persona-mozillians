# name: discourse-persona-mozillians
# about: persona login provider with some mozillians magic sprinkled on top
# version: 0.1
# author: Vikhyat Korrapati, Leo McArdle

gem 'omniauth-browserid-discourse', '0.0.2', require_name: 'omniauth-browserid'

class PersonaAuthenticator < ::Auth::Authenticator

  def name
    "persona"
  end

  def add_to_group(user, group_name)
    group = Group.where(name: group_name).first
    if not group.nil?
      if group.group_users.where(user_id: user.id).first.nil?
        group.group_users.create(user_id: user.id, group_id: group.id)
      end
    end
  end

  def remove_from_group(user, group_name)
    group = Group.where(name: group_name).first
    if not group.nil?
      if not group.group_users.where(user_id: user.id).first.nil?
        group.group_users.where(user_id: user.id).destroy_all
      end
    end
  end

  def purge_from_groups(user)
    group_prefix = SiteSetting.mozillians_group_prefix
    remove_from_group(user, group_prefix)

    groups = Group.where("name LIKE '#{group_prefix}*_%' ESCAPE '*'")
    groups.each do |group|
      remove_from_group(user, group.name)
    end
  end

  def mozillians_magic(user)
    if SiteSetting.mozillians_enabled
      mozillians_url = SiteSetting.mozillians_url
      app_name = SiteSetting.mozillians_app_name
      app_key = SiteSetting.mozillians_app_key
      email = user.email

      begin
        uri = URI.parse("#{mozillians_url}/api/v1/users/?app_name=#{app_name}&app_key=#{app_key}&email=#{email}")

        http = Net::HTTP.new(uri.host, uri.port)
        if SiteSetting.mozillians_enable_ssl
          http.use_ssl = true
        end
        request = Net::HTTP::Get.new(uri.request_uri)

        response = http.request(request) 

        if response.code == "200"
          res = JSON.parse(response.body)
          total_count = res["meta"]["total_count"]

          if total_count == 1 
            is_vouched = res["objects"].first["is_vouched"]

            group_prefix = SiteSetting.mozillians_group_prefix

            case is_vouched
            when false
              remove_from_group(user, "#{group_prefix}_vouched")
              add_to_group(user, group_prefix)
              add_to_group(user, "#{group_prefix}_unvouched")
            when true
              remove_from_group(user, "#{group_prefix}_unvouched")
              add_to_group(user, group_prefix)
              add_to_group(user, "#{group_prefix}_vouched")
            end

          else
            purge_from_groups(user)
          end

        else
          purge_from_groups(user)
        end

      rescue SocketError => details
        puts "Failed to query API: #{details}"
        purge_from_groups(user)
      end

    end
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    result.email = email = auth_token[:info][:email]
    result.email_valid = true

    result.user = user = User.find_by_email(email) 

    if not (defined?(user.id)).nil?
      mozillians_magic(user)
    end

    result
  end

  def after_create_account(user, auth)
    mozillians_magic(user)
  end

  def register_middleware(omniauth)
    omniauth.provider :browser_id, name: "persona"
  end
end

auth_provider authenticator: PersonaAuthenticator.new

register_asset "javascripts/persona.js"

register_css <<CSS

.btn-social.persona {
  background: #606060 !important;
}

.btn-social.persona:before {
  content: "]";
}

CSS
