# name: discourse-persona-mozillians
# about: persona login provider with some mozillians magic sprinkled on top
# version: 0.1
# author: Vikhyat Korrapati, Leo McArdle

gem 'omniauth-browserid-discourse', '0.0.2', require_name: 'omniauth-browserid'

class PersonaAuthenticator < ::Auth::Authenticator

  SETTINGS = YAML.load_file("#{Rails.root}/config/mozillians.yml")

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

  def mozillians_magic(user)
    mozillians_url = SETTINGS["mozillians_url"]
    app_name = SETTINGS["app_name"]
    app_key = SETTINGS["app_key"]
    email = user.email

    uri = URI.parse("#{mozillians_url}/api/v1/users/?app_name=#{app_name}&app_key=#{app_key}&email=#{email}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)

    response = http.request(request) 

    if response.code == "200"
      res = JSON.parse(response.body)
      is_vouched = res["objects"].first["is_vouched"]

      case is_vouched
      when false
        remove_from_group(user, "mozillians_vouched")
        add_to_group(user, "mozillians")
        add_to_group(user, "mozillians_unvouched")
      when true
        remove_from_group(user, "mozillians_unvouched")
        add_to_group(user, "mozillians")
        add_to_group(user, "mozillians_vouched")
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
