require 'droplet_kit'
require 'yaml'
require 'net/http'
require 'uri'

@new_discovery_url = Net::HTTP.get_response(URI.parse('https://discovery.etcd.io/new')).body
puts "new discovery url: #{@new_discovery_url}"

@client = DropletKit::Client.new(access_token: ENV["DO_ACCESS_TOKEN"])

def parse_files(should_include_master_services)
  services = [
    {
      "path" => "/home/core/startup.sh",
      "permissions" => "0755",
      "owner" => "core",
      "content" => File.read("startup.sh")
    },
    {
      "path" => "/etc/systemd/system/docker.service",
      "permissions" => "0644",
      "owner" => "root",
      "content" => File.read("services/docker.service")
    },
    {
      "path" => "/etc/systemd/system/kubelet.service",
      "permissions" => "0644",
      "owner" => "root",
      "content" => File.read("services/kubelet.service")
    },
    {
      "path" => "/etc/systemd/system/proxy.service",
      "permissions" => "0644",
      "owner" => "root",
      "content" => File.read("services/proxy.service")
    },
    {
      "path" => "/etc/systemd/system/scheduler.service",
      "permissions" => "0644",
      "owner" => "root",
      "content" => File.read("services/scheduler.service")
    },
    {
      "path" => "/etc/systemd/system/flannel.service",
      "permissions" => "0644",
      "owner" => "root",
      "content" => File.read("services/flannel.service")
    },
    {
      "path" => "/home/core/apache.json",
      "permissions" => "0644",
      "owner" => "root",
      "content" => File.read("apache.json")
    },
  ]
  if should_include_master_services
    services.push({
        "path" => "/etc/systemd/system/apiserver.service",
        "permissions" => "0644",
        "owner" => "root",
        "content" => File.read("services/master/apiserver.service")
      },
      {
        "path" => "/etc/systemd/system/controller-manager.service",
        "permissions" => "0644",
        "owner" => "root",
        "content" => File.read("services/master/controller-manager.service")
      })
  end

  services
end

def build_droplet(name, is_master)
  cloud_config = {
    "coreos"=> {
      "etcd2"=>{
        "discovery" => @new_discovery_url,
        "advertise-client-urls" => "http://$private_ipv4:2379,http://$private_ipv4:4001",
        "initial-advertise-peer-urls" => "http://$private_ipv4:2380",
        "listen-client-urls" => "http://0.0.0.0:2379,http://0.0.0.0:4001",
        "listen-peer-urls" => "http://$private_ipv4:2380"
      },
      "fleet"=>{
        "public-ip" => "$private_ipv4",
      },
      "units" => [
        {
          "name" => "etcd2.service",
          "command" => "start"
        },
        {
          "name" => "fleet.service",
          "command" => "start"
        }
      ]
    },
    "write_files" => parse_files(is_master),
  }

  cloud_config_string = "#cloud-config\n#{cloud_config.to_yaml}"

  puts cloud_config_string

  DropletKit::Droplet.new(
    name: name,
    image: 'coreos-stable',
    region: 'fra1',
    size: '1gb',
    private_networking: true,
    ssh_keys: @client.ssh_keys.all.collect {|key| key.fingerprint},
    user_data: cloud_config_string)
end


@client.droplets.all.map do |droplet|
  puts "deleting droplet: #{droplet.name}"
  droplet.networks.v4.each do |v4_config|
     puts v4_config.ip_address if v4_config.type == "public"
  end
  @client.droplets.delete(id: droplet.id)
end

@client.droplets.create(build_droplet("coreos-k8s-master", true))
@client.droplets.create(build_droplet("coreos-k8s-minion-1", false))
@client.droplets.create(build_droplet("coreos-k8s-minion-2", false))

puts "droplet created"
puts "waiting 20 sec for the nodes to come up"

sleep(20)

created_droplets = []
@client.droplets.all.map do |droplet|
  created_droplet = {:name => droplet.name}
  droplet.networks.v4.each do |v4_config|
    created_droplet[:ip_public] = v4_config.ip_address if v4_config.type == "public"
    created_droplet[:ip_private] = v4_config.ip_address if v4_config.type == "private"
  end
  created_droplets.push created_droplet
end

puts created_droplets.inspect

private_ip_string = created_droplets.map do |droplet|
  droplet[:ip_private]
end.join ","

puts
puts private_ip_string
puts

created_droplets.each do |droplet|
  puts droplet.inspect
  system("ssh -A -o 'StrictHostKeyChecking no' core@#{droplet[:ip_public]} 'sudo /bin/bash ~/startup.sh #{private_ip_string}'" )
end
