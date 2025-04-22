title 'HTTP Service Check'

control 'http-01' do
  impact 1.0
  title 'Ensure HTTP services are running'
  desc 'Checks if the HTTP services are listening and are accessible'

  services = [
    'http://talos-cp.fritz.box:30000', # Grafana
  ]

  services.each do |service|
    describe http(service) do
      its('status') { should be_in [200, 302, 307] }
      its('headers.Content-Type') { should match(/text\/html|application\/json/) }
    end
  end
end
