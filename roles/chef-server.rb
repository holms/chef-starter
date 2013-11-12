name "chef-server"
description "Chef-server"

run_list(
  "recipe[chef-server]"
)

override_attributes(

 # "chef-server" => {
 #      :api_fqdn => "10.49.118.164"
 # },

  :authorization => {
    :sudo => {
      :users => ["ubuntu"],
      :passwordless => true
    }
  }
)
