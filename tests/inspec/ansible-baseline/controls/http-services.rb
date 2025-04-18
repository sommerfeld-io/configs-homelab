title "HTTP Service Check"

control 'http-01' do
  impact 1.0
  title 'Ensure HTTP services are running'
  desc 'Checks if the HTTP services are listening and are accessible'

  ports = [
    '9990', # portainer
    '9100', # node exporter
    '9110', # cAdvisor, 307 redirect to /containers
  ]

  ports.each do |port|
    describe port(port) do
      it { should be_listening }
      its('protocols') { should include 'tcp' }
    end

    describe http("http://localhost:#{port}") do
      its('status') { should be_in [200, 307] }
    end
  end
end
