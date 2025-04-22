title 'HTTP Service Check'

control 'http-01' do
  impact 1.0
  title 'Ensure HTTP services are running'
  desc 'Checks if the HTTP services are listening and are accessible'

  services = [
    { protocol: 'http', host: 'talos-cp.fritz.box', port: '30000' }, # Grafana
  ]

  services.each do |srv|
    url = "#{srv[:protocol]}://#{srv[:host]}:#{srv[:port]}"

    describe host(srv[:host], port: srv[:port], protocol: srv[:protocol]) do
      it { should be_resolvable }
      its('protocol') { should eq srv[:protocol] }
    end

    describe http(url) do
      its('status') { should be_in [200, 302, 307] }
      its('headers.Content-Type') { should match(/text\/html|application\/json/) }
    end
  end
end
